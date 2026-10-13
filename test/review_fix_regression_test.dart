// 2026-09-23 审查（docs/review-2026-09-23.md）中 P1/P2 缺陷的回归测试。
//
// 覆盖四项无法靠既有用例推断的行为：
//   4.1 崩溃恢复判据必须取自检查点自身，而不是 settings.hasActiveSession。
//   4.1b 反过来，显式编排的新会话必须让旧检查点失效，否则新选词会被旧会话顶掉。
//   4.3 批量状态查询必须分块，避免旧版 SQLite 的 999 绑定参数上限。
//   4.6 Hive 导入失败必须整体回滚，而不是「已清空且仅部分恢复」。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:vocab_flash_test/data/hive_progress_repository.dart';
import 'package:vocab_flash_test/data/secure_credential_store.dart';
import 'package:vocab_flash_test/data/sqlite/sqlite_progress_repository.dart';
import 'package:vocab_flash_test/data/word_repository.dart';
import 'package:vocab_flash_test/features/study/data/session_checkpoint_store.dart';
import 'package:vocab_flash_test/features/study/domain/session_checkpoint.dart';
import 'package:vocab_flash_test/models/card_state.dart';
import 'package:vocab_flash_test/models/test_run.dart';
import 'package:vocab_flash_test/session/app_settings_notifier.dart';
import 'package:vocab_flash_test/session/session_models.dart';

/// 仅用于构造 AppSettingsNotifier 的空凭据实现（学习核心不需要凭据）。
class _NoCredentials implements CredentialStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}

class _Words implements WordRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 记录每次查询的绑定参数个数，用于断言分块行为。
class _RecordingDatabase implements Database {
  final List<List<Object?>> queries = [];

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    queries.add(List<Object?>.from(whereArgs ?? const []));
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('4.1 isResumable 以检查点自身为准', () {
    SessionCheckpoint make({
      required String status,
      List<int> queue = const [],
      int? currentWordId,
    }) => SessionCheckpoint(
      sessionId: 's',
      revision: 0,
      status: status,
      mainQueueWordIds: queue,
      delayedQueue: const [],
      currentWordId: currentWordId,
      currentOptions: null,
      currentCorrectIndex: null,
      selectedOption: null,
      millisLeft: 0,
      currentProgress: 0,
      attempts: const [],
      config: const {},
      savedAt: DateTime.now(),
    );

    expect(make(status: 'finished', queue: [1]).isResumable, isFalse);
    expect(make(status: 'idle', queue: [1]).isResumable, isFalse);
    expect(make(status: 'waiting', queue: [1]).isResumable, isTrue);
    expect(make(status: 'resolved', currentWordId: 5).isResumable, isTrue);
    expect(make(status: 'waiting').isResumable, isFalse, reason: '空快照不可恢复');
  });

  test('4.3 getCardStates 按 800 分块绑定参数', () async {
    final db = _RecordingDatabase();
    final repo = SqliteProgressRepository.withDatabase(_Words(), db);
    final ids = List<int>.generate(3177, (i) => i + 1); // 全选四个级别的规模

    await repo.getCardStates(ids);

    final sizes = db.queries.map((q) => q.length).toList();
    expect(sizes, [800, 800, 800, 777]);
    expect(
      sizes.every((s) => s < 999),
      isTrue,
      reason: '每片参数必须低于 SQLite < 3.32 的 999 上限（Android 7.0~11）',
    );
    expect(sizes.fold<int>(0, (a, b) => a + b), 3177);
  });

  test('4.6 Hive 导入失败时回滚到导入前状态', () async {
    final dir = await Directory.systemTemp.createTemp('hive_import_rollback_');
    Hive.init(dir.path);
    final repo = HiveProgressRepository(_Words());
    await repo.init();

    for (var i = 1; i <= 3; i++) {
      await repo.saveCardState(CardState.newCard(i));
    }
    await repo.saveTestRun(
      TestRun.create(
        id: 'seed',
        size: 1,
        levels: {'A1'},
        timeLimitMs: 5000,
        orderPolicy: 'by_level',
        onlyLeeches: false,
      ),
    );

    final before = await repo.exportProgress();
    final beforeCards = (before['cardStates'] as List).length;
    final beforeRuns = (before['testRuns'] as List).length;

    // cardStates 合法、testRuns 混入非法元素 —— 在写入中途失败。
    final payload = <String, dynamic>{
      'version': 3,
      'cardStates': [CardState.newCard(9).toJson()],
      'testRuns': ['not-a-map'],
    };

    var threw = false;
    try {
      await repo.importProgress(payload);
    } catch (_) {
      threw = true;
    }

    final after = await repo.exportProgress();
    expect(threw, isTrue);
    expect(
      (after['cardStates'] as List).length,
      beforeCards,
      reason: '导入失败必须回滚，不能只恢复一半',
    );
    expect((after['testRuns'] as List).length, beforeRuns);

    await repo.dispose();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('编排新会话时必须让旧检查点失效，否则新选词会被旧会话顶掉', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SessionCheckpointStore(prefs);

    // 模拟「首页会话被暂停 / 进程被杀」留下的可恢复检查点。
    await store.save(
      SessionCheckpoint(
        sessionId: 'home-session',
        revision: 1,
        status: SessionState.waiting.name,
        mainQueueWordIds: const [1, 2, 3],
        delayedQueue: const [],
        currentWordId: 1,
        currentOptions: const ['a', 'b'],
        currentCorrectIndex: 0,
        selectedOption: null,
        millisLeft: 5000,
        currentProgress: 0,
        attempts: const [],
        config: const {},
        savedAt: DateTime(2026, 9, 23),
      ),
    );
    expect(store.load()?.isResumable, isTrue);

    final notifier = AppSettingsNotifier(
      AsyncData(prefs),
      credentialStore: _NoCredentials(),
    );
    final staged = await notifier.stageCustomSession(const [9, 8, 7]);

    expect(staged, isNotEmpty);
    expect(notifier.state.remainingWordIds, const [9, 8, 7]);
    expect(
      store.load(),
      isNull,
      reason: 'TestScreen 以检查点判据决定恢复，编排新会话后旧检查点必须失效',
    );
  });
}
