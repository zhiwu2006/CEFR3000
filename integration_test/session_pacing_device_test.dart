import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:vocab_flash_test/data/repositories.dart';
import 'package:vocab_flash_test/domain/distractor.dart';
import 'package:vocab_flash_test/models/models.dart';
import 'package:vocab_flash_test/session/session_controller.dart';
import 'package:vocab_flash_test/session/session_models.dart';

class _Words implements WordRepository {
  final words = List.generate(
    4,
    (i) => Word(
      id: i + 1,
      headword: 'probe$i',
      lemma: 'probe$i',
      level: 'A1',
      pos: 'n.',
      cnDefs: ['含义$i'],
    ),
  );
  @override
  Future<List<Word>> loadByLevels(Set<String> levels) async => words;
  @override
  Future<List<Word>> loadAll() async => words;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Tts implements TtsService {
  @override
  Future<void> stop() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'USB device: uniform feedback, repeated pause, SQLite only after completion',
    (tester) async {
      final root = await getDatabasesPath();
      // 独立数据库，不读取或改写手机上的真实学习记录。
      final path = '$root/vocab_pacing_device_probe.sqlite';
      await deleteDatabase(path);
      final words = _Words();
      final repo = SqliteProgressRepository(words, databasePath: path);
      await repo.init();
      await repo.indexLegacyLexicon(words.words);
      final c = SessionController(
        wordRepository: words,
        progressRepository: repo,
        ttsService: _Tts(),
        distractorService: DistractorService(seed: 1),
        getDailyNewRemaining: () => 30,
        consumeDailyNew: (_) async {},
      );
      addTearDown(() async {
        c.dispose();
        await repo.close();
        await deleteDatabase(path);
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('配对节奏 USB 验证（独立测试数据）'))),
        ),
      );
      final presented = <DateTime>[];
      final resolved = <DateTime>[];
      SessionState? previous;
      c.addListener((data) {
        if (data.state != previous) {
          if (data.state == SessionState.waiting) presented.add(DateTime.now());
          if (data.state == SessionState.resolved) resolved.add(DateTime.now());
          previous = data.state;
        }
      });
      await c.startSession(
        SessionConfig.defaultConfig.copyWith(
          plannedWordIds: [1, 2, 3, 4],
          wordsPerSession: 4,
          timeLimitMs: 2000,
          ttsAutoPlay: false,
          ttsOnWrong: false,
        ),
      );
      for (var index = 0; index < 3; index++) {
        final question = c.state.currentQuestion!;
        if (index == 2) {
          await Future<void>.delayed(const Duration(milliseconds: 2100));
        } else {
          await c.selectOption(
            index == 0
                ? question.correctIndex
                : (question.correctIndex + 1) % 4,
          );
        }
        // 反馈进行期间真实数据库中仍没有任何本轮结果。
        expect(await repo.getReviewEvents(), isEmpty);
        expect(await repo.getTestRunHistory(), isEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 900));
        expect(c.state.state, SessionState.waiting);
        final gap = presented[index + 1]
            .difference(resolved[index])
            .inMilliseconds;
        debugPrint('USB pacing result $index: feedback gap=${gap}ms');
        expect(gap, inInclusiveRange(780, 1050));
      }
      // 答完后连续暂停，恢复后必须继续切题。
      await c.selectOption(c.state.currentQuestion!.correctIndex);
      c.pauseSession();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      c.pauseSession();
      c.resumeSession();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(c.state.state, SessionState.waiting);
      expect(await repo.getReviewEvents(), isEmpty);
      // 主队列清空后仍须等错题/超时重放完成才能保存。
      var guard = 0;
      while (c.state.state == SessionState.waiting && guard++ < 12) {
        await c.selectOption(c.state.currentQuestion!.correctIndex);
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (c.state.state == SessionState.saving &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(c.state.state, SessionState.finished);
      final events = await repo.getReviewEvents();
      expect(events.length, c.state.attempts.length);
      final runs = await repo.getTestRunHistory();
      expect(runs.single.isFinished, isTrue);
      debugPrint(
        'USB completion verified: ${events.length} review events, one finished run',
      );
    },
  );
}
