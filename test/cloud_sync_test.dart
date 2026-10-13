import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vocab_flash_test/data/sqlite/sqlite_progress_repository.dart';
import 'package:vocab_flash_test/data/word_repository.dart';
import 'package:vocab_flash_test/features/memory/application/recall_commit_service.dart';
import 'package:vocab_flash_test/features/sync/application/cloud_sync_service.dart';
import 'package:vocab_flash_test/features/sync/data/cloudflare_sync.dart';
import 'package:vocab_flash_test/models/attempt.dart';
import 'package:vocab_flash_test/models/test_run.dart';

class _Words implements WordRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 内存版云端：按 (表, id) 存行，updated_at 单调递增，模拟 ignoreDuplicates。
class _FakeCloud implements SyncRemote {
  final tables = <String, Map<String, Map<String, dynamic>>>{};
  var _clock = DateTime.utc(2026, 10, 1);
  int upserts = 0;

  @override
  Future<void> upsert(
    String table,
    List<Map<String, dynamic>> rows, {
    required bool updateExisting,
  }) async {
    upserts++;
    final t = tables.putIfAbsent(table, () => {});
    for (final row in rows) {
      final id = row['id'] as String;
      if (t.containsKey(id) && !updateExisting) continue;
      _clock = _clock.add(const Duration(seconds: 1));
      t[id] = {...row, 'updated_at': _clock.toIso8601String()};
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSince(
    String table,
    DateTime? since, {
    required int offset,
    required int limit,
  }) async {
    final rows =
        (tables[table]?.values ?? const <Map<String, dynamic>>[])
            .where(
              (r) =>
                  since == null ||
                  DateTime.parse(r['updated_at'] as String).isAfter(since),
            )
            .toList()
          ..sort(
            (a, b) => (a['updated_at'] as String).compareTo(
              b['updated_at'] as String,
            ),
          );
    return rows.skip(offset).take(limit).toList();
  }
}

Attempt _attempt(int wordId, DateTime at, AttemptResult result) => Attempt(
  wordId: wordId,
  result: result,
  rtMs: 900,
  chosenIndex: result == AttemptResult.correct ? 0 : 1,
  correctIndex: 0,
  timestamp: at,
);

void main() {
  late Directory dir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sync_test_');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  Future<SqliteProgressRepository> device(String name) async {
    final repo = SqliteProgressRepository(
      _Words(),
      databasePath: '${dir.path}/$name.db',
    );
    await repo.init();
    return repo;
  }

  Future<void> answer(
    SqliteProgressRepository repo,
    String session,
    Attempt attempt,
  ) async {
    await RecallCommitService(progressRepository: repo).commitAttempt(
      sessionId: session,
      attempt: attempt,
      timeLimitMs: 2000,
      slowThreshold: 1.5,
    );
  }

  test('two devices converge on the same history and card states', () async {
    final phone = await device('phone');
    final tablet = await device('tablet');
    final cloud = _FakeCloud();
    CloudSyncService sync(SqliteProgressRepository repo) => CloudSyncService(
      repository: repo,
      remote: cloud,
      accountKey: 'https://sync.example',
    );

    final d1 = DateTime(2026, 10, 10, 7);
    // 手机：词 1 连续两天答对，并完成一轮。
    await answer(phone, 'p1', _attempt(1, d1, AttemptResult.correct));
    await answer(
      phone,
      'p2',
      _attempt(1, d1.add(const Duration(days: 1)), AttemptResult.correct),
    );
    await phone.saveTestRun(
      TestRun(
        id: 'p2',
        startedAt: d1.add(const Duration(days: 1)),
        finishedAt: d1.add(const Duration(days: 1, minutes: 4)),
        size: 1,
        levels: const ['A2'],
        timeLimitMs: 2000,
        attempts: const [],
        orderPolicy: 'by_level',
        onlyLeeches: false,
      ),
    );
    // 平板：同一天另学了词 2。
    await answer(
      tablet,
      't1',
      _attempt(
        2,
        d1.add(const Duration(days: 1, hours: 12)),
        AttemptResult.wrong,
      ),
    );

    final first = await sync(phone).syncNow();
    expect(first.pushedEvents, 2);
    expect(first.pushedRuns, 1);

    final second = await sync(tablet).syncNow();
    expect(second.pushedEvents, 1);
    expect(second.merged.newEvents, 2); // 收到手机的两次作答
    expect(second.merged.newRuns, 1);

    final third = await sync(phone).syncNow();
    expect(third.merged.newEvents, 1); // 收到平板的词 2

    for (final repo in [phone, tablet]) {
      expect((await repo.getReviewEvents()).length, 3);
      expect((await repo.getTestRunHistory(limit: 10)).single.id, 'p2');
    }
    for (final wordId in [1, 2]) {
      final a = (await phone.getCardState(wordId))!;
      final b = (await tablet.getCardState(wordId))!;
      expect(a.due, b.due, reason: 'word $wordId due');
      expect(a.stability, closeTo(b.stability, 1e-9));
      expect(a.lapses, b.lapses);
      expect(a.longTermReviews, b.longTermReviews);
    }
    expect((await tablet.getCardState(1))!.longTermReviews, 1);

    // 刚合并进来的那条会回传一次（写入顺序在推送游标之后），云端按 id
    // 忽略重复；之后再同步既不上传也没有新数据。
    final echo = await sync(phone).syncNow();
    expect(echo.pushedEvents, 1);
    expect(echo.merged.changed, isFalse);
    expect(cloud.tables[CloudSyncService.eventsTable]!.length, 3);
    final again = await sync(phone).syncNow();
    expect(again.pushedEvents, 0);
    expect(again.merged.changed, isFalse);

    // 合并后的卡片还能继续正常提交（revision 单调，不冲突）。
    await answer(
      tablet,
      't2',
      _attempt(1, d1.add(const Duration(days: 3)), AttemptResult.correct),
    );
    expect((await tablet.getCardState(1))!.longTermReviews, 2);

    await phone.close();
    await tablet.close();
  });

  test(
    'an unreadable remote row is skipped instead of blocking sync',
    () async {
      final tablet = await device('tablet');
      final cloud = _FakeCloud();
      await cloud.upsert(CloudSyncService.eventsTable, [
        {
          'id': 'broken',
          'payload': {'not': 'an event'},
        },
      ], updateExisting: false);
      final service = CloudSyncService(
        repository: tablet,
        remote: cloud,
        accountKey: 'https://sync.example',
      );
      final report = await service.syncNow();
      expect(service.skippedRows, 1);
      expect(report.merged.newEvents, 0);
      await tablet.close();
    },
  );

  test('cursors are per sync target', () async {
    final phone = await device('phone');
    final cloud = _FakeCloud();
    await answer(
      phone,
      'p1',
      _attempt(1, DateTime(2026, 10, 10, 7), AttemptResult.correct),
    );
    final a = await CloudSyncService(
      repository: phone,
      remote: cloud,
      accountKey: 'https://a.example',
    ).syncNow();
    final b = await CloudSyncService(
      repository: phone,
      remote: cloud,
      accountKey: 'https://b.example',
    ).syncNow();
    expect(a.pushedEvents, 1);
    expect(b.pushedEvents, 1); // 换同步地址会重新上传，不会被当成已同步
    await phone.close();
  });

  // 端到端：SYNC_E2E_URL / SYNC_E2E_TOKEN 指向本地 `wrangler dev` 启动的 Worker。
  final e2eUrl = Platform.environment['SYNC_E2E_URL'];
  final e2eToken = Platform.environment['SYNC_E2E_TOKEN'];
  test(
    'two devices sync through the real worker over HTTP',
    () async {
      final phone = await device('phone');
      final tablet = await device('tablet');
      // 每次运行用独立的游标命名空间，避免受上次本地数据库残留影响。
      final key = 'e2e-${DateTime.now().microsecondsSinceEpoch}';
      final remote = CloudflareSyncRemote(
        baseUri: Uri.parse(e2eUrl!),
        token: e2eToken!,
      );
      await remote.checkHealth();
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final d1 = DateTime(2026, 10, 10, 7);
      await answer(phone, 'p$stamp', _attempt(1, d1, AttemptResult.correct));
      await answer(
        tablet,
        't$stamp',
        _attempt(2, d1.add(const Duration(hours: 5)), AttemptResult.wrong),
      );
      CloudSyncService sync(SqliteProgressRepository repo) =>
          CloudSyncService(repository: repo, remote: remote, accountKey: key);
      expect((await sync(phone).syncNow()).pushedEvents, 1);
      expect((await sync(tablet).syncNow()).merged.newEvents, greaterThan(0));
      await sync(phone).syncNow();
      final phoneIds = (await phone.getReviewEvents()).map((e) => e.id).toSet();
      final tabletIds = (await tablet.getReviewEvents())
          .map((e) => e.id)
          .toSet();
      expect(phoneIds.containsAll(tabletIds), isTrue);
      expect(tabletIds.containsAll(phoneIds), isTrue);
      expect(
        (await phone.getCardState(2))!.due,
        (await tablet.getCardState(2))!.due,
      );
      remote.close();
      await phone.close();
      await tablet.close();
    },
    skip: e2eUrl == null || e2eToken == null
        ? 'set SYNC_E2E_URL and SYNC_E2E_TOKEN to run'
        : false,
  );
}
