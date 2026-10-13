import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_flash_test/core/clock.dart';
import 'package:vocab_flash_test/data/repositories.dart';
import 'package:vocab_flash_test/domain/distractor.dart';
import 'package:vocab_flash_test/models/models.dart';
import 'package:vocab_flash_test/screens/test_screen.dart';
import 'package:vocab_flash_test/session/base_providers.dart';
import 'package:vocab_flash_test/session/session_controller.dart';
import 'package:vocab_flash_test/session/session_models.dart';

class _TestClock implements Clock {
  final WidgetTester tester;
  _TestClock(this.tester);
  @override
  DateTime get now => tester.binding.clock.now();
}

class _Words implements WordRepository {
  _Words([int count = 4])
    : words = List.generate(
        count,
        (i) => Word(
          id: i + 1,
          headword: 'word$i',
          lemma: 'word$i',
          level: 'A1',
          pos: 'n.',
          cnDefs: ['释义$i'],
        ),
      );
  final List<Word> words;
  @override
  Future<List<Word>> loadByLevels(Set<String> levels) async => words;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Progress implements ProgressRepository, ReviewCommitRepository {
  int reads = 0;
  int writes = 0;
  int commitCalls = 0;
  bool failArchive = false;
  Completer<void>? writeGate;
  final events = <String, ReviewEvent>{};
  final cards = <int, CardState>{};
  final runs = <TestRun>[];
  List<Attempt> savedAttempts = [];
  @override
  Future<TestRun?> getLatestTestRun() async {
    reads++;
    return null;
  }

  @override
  Future<List<TestRun>> getTestRunHistory({int limit = 10}) async {
    reads++;
    return runs;
  }

  @override
  Future<List<CardState>> getCardStates(List<int> ids) async {
    reads++;
    return ids.map((id) => cards[id]).whereType<CardState>().toList();
  }

  @override
  Future<CardState?> getCardState(int wordId) async {
    reads++;
    return cards[wordId];
  }

  @override
  Future<ReviewEvent?> getReviewEvent(String id) async {
    reads++;
    return events[id];
  }

  @override
  Future<ReviewCommitResult> commitReview(ReviewEvent event) async {
    writes++;
    commitCalls++;
    if (writeGate != null) await writeGate!.future;
    events[event.id] = event.copyWith(status: 'committed');
    cards[event.attempt.wordId] = event.resultingState;
    return ReviewCommitResult(
      state: event.resultingState,
      alreadyCommitted: false,
    );
  }

  @override
  Future<void> batchSaveAttempts(List<Attempt> attempts) async {
    writes++;
    savedAttempts = List.of(attempts);
  }

  @override
  Future<void> saveTestRun(TestRun run) async {
    writes++;
    if (failArchive) throw StateError('simulated disk failure');
    runs.removeWhere((r) => r.id == run.id);
    runs.add(run);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Tts implements TtsService {
  @override
  Future<void> stop() async {}
  @override
  Future<void> speak(String text) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SessionConfig config([List<int> ids = const [1, 2, 3, 4]]) =>
    SessionConfig.defaultConfig.copyWith(
      plannedWordIds: ids,
      wordsPerSession: ids.length,
      timeLimitMs: 2000,
      ttsAutoPlay: false,
      ttsOnWrong: false,
    );

SessionController _controller(
  WidgetTester tester,
  _Progress repo, {
  Future<void> Function(int)? consume,
}) => SessionController(
  wordRepository: _Words(),
  progressRepository: repo,
  ttsService: _Tts(),
  distractorService: DistractorService(seed: 1),
  getDailyNewRemaining: () => 30,
  consumeDailyNew: consume ?? (_) async {},
  clock: _TestClock(tester),
);

void main() {
  testWidgets(
    '100-word plan stays unique and total cap preserves unseen work',
    (tester) async {
      final repo = _Progress();
      final c = SessionController(
        wordRepository: _Words(120),
        progressRepository: repo,
        ttsService: _Tts(),
        distractorService: DistractorService(seed: 1),
        getDailyNewRemaining: () => 120,
        consumeDailyNew: (_) async {},
        clock: _TestClock(tester),
      );
      try {
        final ids = List.generate(100, (i) => i + 1);
        await c.startSession(
          config(ids).copyWith(orderPolicy: 'by_level', maxTotalAttempts: 1),
        );
        expect(c.state.totalWords, 100);
        expect(c.state.remainingWordIds, ids.toSet());
        await c.selectOption(c.state.currentQuestion!.correctIndex);
        await tester.pump(const Duration(milliseconds: 800));
        expect(c.state.state, SessionState.finished);
        expect(c.state.unresolvedWordIds.length, 99);
        expect(repo.runs.single.unresolvedWordIds.length, 99);
      } finally {
        c.dispose();
      }
    },
  );

  testWidgets(
    'retry cap leaves pending word and restarting retains consolidation',
    (tester) async {
      final repo = _Progress();
      final c = _controller(tester, repo);
      try {
        await c.startSession(
          config().copyWith(
            orderPolicy: 'by_level',
            cooldownWindow: 3,
            maxRetriesPerWord: 1,
          ),
        );
        final id = c.state.currentQuestion!.word.id;
        await c.selectOption((c.state.currentQuestion!.correctIndex + 1) % 4);
        await tester.pump(const Duration(milliseconds: 800));
        for (var i = 0; i < 3; i++) {
          await c.selectOption(c.state.currentQuestion!.correctIndex);
          await tester.pump(const Duration(milliseconds: 800));
        }
        expect(c.state.currentQuestion!.word.id, id);
        await c.selectOption(c.state.currentQuestion!.correctIndex);
        expect(c.state.unresolvedWordIds, contains(id));
        await tester.pump(const Duration(milliseconds: 800));
        expect(c.state.state, SessionState.finished);
        await c.restartWithSameWords(shuffle: false);
        expect(c.state.consolidationWordIds, contains(id));
      } finally {
        c.dispose();
      }
    },
  );
  testWidgets('two spaced successes remove failed word from correction queue', (
    tester,
  ) async {
    final repo = _Progress();
    final c = SessionController(
      wordRepository: _Words(20),
      progressRepository: repo,
      ttsService: _Tts(),
      distractorService: DistractorService(seed: 1),
      getDailyNewRemaining: () => 30,
      consumeDailyNew: (_) async {},
      clock: _TestClock(tester),
    );
    try {
      await c.startSession(
        config(
          List.generate(20, (i) => i + 1),
        ).copyWith(orderPolicy: 'by_level'),
      );
      final failedId = c.state.currentQuestion!.word.id;
      await c.selectOption((c.state.currentQuestion!.correctIndex + 1) % 4);
      await tester.pump(const Duration(milliseconds: 800));
      var successes = 0;
      var previousIndex = 0;
      for (var step = 0; step < 30 && successes < 2; step++) {
        expect(c.state.state, SessionState.waiting);
        final isRetry = c.state.currentQuestion!.word.id == failedId;
        if (isRetry) {
          expect(
            c.state.attempts.length - previousIndex,
            greaterThanOrEqualTo(4),
          );
          previousIndex = c.state.attempts.length;
        }
        await c.selectOption(c.state.currentQuestion!.correctIndex);
        if (isRetry) {
          successes++;
          expect(c.state.correctionStreak(failedId), successes);
          expect(
            c.state.delayedQueue.any((item) => item.wordId == failedId),
            successes < 2,
          );
        }
        await tester.pump(const Duration(milliseconds: 800));
      }
      expect(successes, 2);
      expect(c.state.correctedWordIds, contains(failedId));
      expect(c.state.unresolvedWordIds, isNot(contains(failedId)));
    } finally {
      c.dispose();
    }
  });
  testWidgets('second spaced success exits retest and persists across rounds', (
    tester,
  ) async {
    final repo = _Progress();
    final c = _controller(tester, repo);
    addTearDown(c.dispose);
    await c.startSession(config().copyWith(orderPolicy: 'by_level'));
    final failedId = c.state.currentQuestion!.word.id;
    await c.selectOption((c.state.currentQuestion!.correctIndex + 1) % 4);
    await tester.pump(const Duration(milliseconds: 800));
    // 第一轮：其余 3 词 + 首次重测答对，随后没有足够间隔题，转入待巩固。
    for (
      var step = 0;
      step < 20 && c.state.state != SessionState.finished;
      step++
    ) {
      await c.selectOption(c.state.currentQuestion!.correctIndex);
      await tester.pump(const Duration(milliseconds: 800));
    }
    expect(c.state.state, SessionState.finished);
    expect(repo.runs.single.unresolvedWordIds, contains(failedId));

    // 序列化往返后仍保留待巩固集合。
    final restored = TestRun.fromJson(repo.runs.single.toJson());
    expect(restored.unresolvedWordIds, contains(failedId));

    // 第二轮：待巩固词优先带入，再次通过需要间隔后连续两次答对。
    final c2 = _controller(tester, repo);
    addTearDown(c2.dispose);
    await c2.startSession(config().copyWith(orderPolicy: 'by_level'));
    expect(c2.state.consolidationWordIds, contains(failedId));
    expect(c2.state.currentQuestion!.word.id, failedId);
    await c2.selectOption(c2.state.currentQuestion!.correctIndex);
    await tester.pump(const Duration(milliseconds: 800));
    // 一次成功不退出：仍在待巩固队列。
    expect(
      c2.state.delayedQueue.map((item) => item.wordId),
      contains(failedId),
    );
    c2.stopSession();
  });
  testWidgets('failed word requires two spaced correct recalls', (
    tester,
  ) async {
    final c = _controller(tester, _Progress());
    addTearDown(c.dispose);
    await c.startSession(
      config().copyWith(orderPolicy: 'by_level', cooldownWindow: 3),
    );
    final failedId = c.state.currentQuestion!.word.id;
    await c.selectOption((c.state.currentQuestion!.correctIndex + 1) % 4);
    await tester.pump(const Duration(milliseconds: 800));
    for (var i = 0; i < 3; i++) {
      expect(c.state.currentQuestion!.word.id, isNot(failedId));
      await c.selectOption(c.state.currentQuestion!.correctIndex);
      await tester.pump(const Duration(milliseconds: 800));
    }
    expect(c.state.currentQuestion!.word.id, failedId);
    await c.selectOption(c.state.currentQuestion!.correctIndex);
    expect(c.state.delayedQueue.map((item) => item.wordId), contains(failedId));
    expect(c.state.correctedWordIds, isEmpty);
    await tester.pump(const Duration(milliseconds: 800));
    // No other words remain to provide spacing: carry over, never repeat immediately.
    expect(c.state.state, SessionState.finished);
    expect(c.state.unresolvedWordIds, contains(failedId));
  });
  testWidgets(
    'correct, wrong and timeout share 800ms feedback with zero mid-session IO',
    (tester) async {
      final repo = _Progress()..writeGate = Completer<void>();
      final c = _controller(tester, repo);
      await c.startSession(config());
      final initialReads = repo.reads;
      for (final result in ['correct', 'wrong', 'timeout']) {
        final id = c.state.currentQuestion!.word.id;
        if (result == 'timeout') {
          await tester.pump(const Duration(milliseconds: 2000));
        } else {
          final correct = c.state.currentQuestion!.correctIndex;
          await c.selectOption(
            result == 'correct' ? correct : (correct + 1) % 4,
          );
        }
        expect(c.state.state, SessionState.resolved);
        await tester.pump(const Duration(milliseconds: 799));
        expect(c.state.currentQuestion!.word.id, id);
        await tester.pump(const Duration(milliseconds: 1));
        expect(c.state.state, SessionState.waiting);
        expect(c.state.currentQuestion!.word.id, isNot(id));
        expect(c.state.millisLeft, 2000);
        expect(repo.reads, initialReads);
        expect(repo.writes, 0);
      }
      c.dispose();
    },
  );

  testWidgets(
    'repeated pause preserves feedback and cannot advance stopped or restarted sessions',
    (tester) async {
      final repo = _Progress();
      final c = _controller(tester, repo);
      await c.startSession(config());
      await c.selectOption(c.state.currentQuestion!.correctIndex);
      await tester.pump(const Duration(milliseconds: 300));
      c.pauseSession();
      await tester.pump(const Duration(seconds: 2));
      c.pauseSession();
      c.resumeSession();
      c.resumeSession();
      await tester.pump(const Duration(milliseconds: 499));
      expect(c.state.currentQuestion!.word.id, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(c.state.currentQuestion!.word.id, 2);
      expect(c.state.state, SessionState.waiting);
      await c.selectOption(c.state.currentQuestion!.correctIndex);
      await c.restartWithSameWords(shuffle: false);
      final restartedWord = c.state.currentQuestion!.word.id;
      await tester.pump(const Duration(milliseconds: 800));
      expect(c.state.currentQuestion!.word.id, restartedWord);
      expect(c.state.attempts, isEmpty);
      await c.selectOption(c.state.currentQuestion!.correctIndex);
      c.stopSession();
      await tester.pump(const Duration(seconds: 3));
      expect(c.state.state, SessionState.idle);
      expect(repo.writes, 0);
      c.dispose();
    },
  );

  testWidgets(
    'countdown excludes paused time and retains the full active time budget',
    (tester) async {
      final c = _controller(tester, _Progress());
      await c.startSession(config());
      await tester.pump(const Duration(milliseconds: 725));
      c.pauseSession();
      expect(c.state.millisLeft, 1275);
      await tester.pump(const Duration(seconds: 10));
      c.pauseSession();
      c.resumeSession();
      await tester.pump(const Duration(milliseconds: 275));
      await c.selectOption(c.state.currentQuestion!.correctIndex);
      expect(c.state.attempts.single.rtMs, 1000);
      c.dispose();
    },
  );

  testWidgets('three timeouts in a row pause the round as idle', (
    tester,
  ) async {
    final c = _controller(tester, _Progress());
    await c.startSession(config([1, 2, 3, 4]));
    for (var i = 0; i < SessionController.idlePauseAfterTimeouts; i++) {
      expect(c.state.state, SessionState.waiting);
      await tester.pump(Duration(milliseconds: c.state.millisLeft + 50));
      if (i < SessionController.idlePauseAfterTimeouts - 1) {
        await tester.pump(SessionController.feedbackDuration);
      }
    }
    expect(c.state.isPaused, isTrue);
    expect(c.state.pausedForIdle, isTrue);
    final answered = c.state.attempts.length;
    await tester.pump(const Duration(seconds: 30));
    expect(c.state.attempts.length, answered);
    c.resumeSession();
    expect(c.state.pausedForIdle, isFalse);
    await tester.pump(SessionController.feedbackDuration);
    expect(c.state.state, SessionState.waiting);
    c.dispose();
  });

  testWidgets(
    'only completion saves; slow save and retry do not lose or double-commit answers',
    (tester) async {
      final repo = _Progress()
        ..writeGate = Completer<void>()
        ..failArchive = true;
      var newWords = 0;
      final c = _controller(
        tester,
        repo,
        consume: (count) async {
          newWords += count;
        },
      );
      await c.startSession(config([1, 2]));
      await c.selectOption(c.state.currentQuestion!.correctIndex);
      await tester.pump(const Duration(milliseconds: 800));
      expect(repo.writes, 0);
      expect(newWords, 0);
      await c.selectOption(c.state.currentQuestion!.correctIndex);
      await tester.pump(const Duration(milliseconds: 799));
      expect(repo.writes, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(c.state.state, SessionState.saving);
      expect(repo.runs, isEmpty);
      repo.writeGate!.complete();
      await tester.pump();
      expect(c.state.state, SessionState.saveFailed);
      expect(c.state.attempts.length, 2);
      expect(repo.commitCalls, 2);
      expect(newWords, 2);
      repo.failArchive = false;
      await c.retrySave();
      expect(c.state.state, SessionState.finished);
      expect(repo.runs.single.isFinished, isTrue);
      expect(repo.savedAttempts.length, 2);
      expect(repo.commitCalls, 2);
      expect(newWords, 2);
      c.dispose();
    },
  );

  testWidgets(
    'screen lifecycle pauses and stays paused until the learner resumes',
    (tester) async {
      tester.view.physicalSize = const Size(480, 1040);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = _Progress()..writeGate = Completer<void>();
      final c = _controller(tester, repo);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) async => prefs),
            progressRepositoryProvider.overrideWithValue(repo),
            wordRepositoryProvider.overrideWithValue(_Words()),
            ttsServiceProvider.overrideWithValue(_Tts()),
            sessionControllerProvider.overrideWith((ref) => c),
          ],
          child: MaterialApp(home: TestScreen(config: config())),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(c.state.state, SessionState.waiting);
      await c.selectOption(c.state.currentQuestion!.correctIndex);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 1));
      expect(c.state.isPaused, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      // 回到前台不自动计时：无人作答时自动恢复会把题目记成超时。
      await tester.pump(const Duration(seconds: 10));
      expect(c.state.isPaused, isTrue);
      expect(c.state.attempts, hasLength(1));
      c.resumeSession();
      expect(c.state.isPaused, isFalse);
      expect(c.state.state, SessionState.resolved);
      await tester.pump(const Duration(milliseconds: 800));
      expect(c.state.state, SessionState.waiting);
      expect(c.state.currentQuestion!.word.id, 2);
      expect(repo.writes, 0);
      // This test injects a controller without a checkpoint store; repository
      // writes must still remain zero while lifecycle timing is exercised.
      expect(prefs.containsKey('study_session_checkpoint_v1'), isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'phone shows configured 100 and distinct tested progress through replay',
    (tester) async {
      tester.view.physicalSize = const Size(480, 1040);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = _Progress();
      final c = _controller(tester, repo);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) async => prefs),
            progressRepositoryProvider.overrideWithValue(repo),
            wordRepositoryProvider.overrideWithValue(_Words()),
            ttsServiceProvider.overrideWithValue(_Tts()),
            sessionControllerProvider.overrideWith((ref) => c),
          ],
          child: MaterialApp(
            home: TestScreen(config: config().copyWith(wordsPerSession: 100)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('每组 100 词'), findsNothing);
      expect(find.text('已测 0 / 4'), findsOneWidget);
      await c.selectOption((c.state.currentQuestion!.correctIndex + 1) % 4);
      await tester.pump();
      expect(find.text('已测 1 / 4'), findsOneWidget);
      expect(find.text('每组 100 词'), findsNothing);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('已测 1 / 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'recognition plan keeps 100 eligible new words instead of truncating to 51',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final words = _Words();
      words.words.clear();
      words.words.addAll(
        List.generate(
          100,
          (i) => Word(
            id: i + 1,
            headword: 'word$i',
            lemma: 'word$i',
            level: 'A1',
            pos: 'n.',
            cnDefs: ['词$i'],
          ),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) async => prefs),
          initializationProvider.overrideWith((ref) async {}),
          wordRepositoryProvider.overrideWithValue(words),
          progressRepositoryProvider.overrideWithValue(_Progress()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(sharedPreferencesProvider.future);
      await container
          .read(appSettingsProvider.notifier)
          .updateWordsPerSession(100);
      final plan = await container.read(todayRecognitionPlanProvider.future);
      expect(plan.items.length, 100);
      await tester.pump(const Duration(milliseconds: 300));
    },
  );

  group('new word study mode', () {
    testWidgets('new words show a study card first, then a 5s question', (
      tester,
    ) async {
      final repo = _Progress();
      final c = _controller(tester, repo);
      try {
        await c.startSession(config().copyWith(studyNewWords: true));
        expect(c.state.state, SessionState.studying);
        final first = c.state.currentQuestion!.word.id;
        expect(c.state.attempts, isEmpty);

        // 学完的词插回队列，隔 3 张卡后才考：先轮到其它新词的学习卡。
        final studied = <int>[first];
        for (var i = 0; i < 3; i++) {
          await c.finishStudyCard();
          expect(c.state.state, SessionState.studying);
          studied.add(c.state.currentQuestion!.word.id);
        }
        expect(studied.toSet().length, 4);

        await c.finishStudyCard();
        expect(c.state.state, SessionState.waiting);
        expect(c.state.currentQuestion!.word.id, first);
        expect(
          c.state.currentTimeLimitMs,
          SessionController.newWordTimeLimitMs,
        );
        expect(c.state.millisLeft, SessionController.newWordTimeLimitMs);
      } finally {
        c.dispose();
      }
    });

    testWidgets('known words skip the card and keep the normal limit', (
      tester,
    ) async {
      final repo = _Progress();
      for (final id in [1, 2, 3, 4]) {
        repo.cards[id] = CardState.newCard(id);
      }
      final c = _controller(tester, repo);
      try {
        await c.startSession(config().copyWith(studyNewWords: true));
        expect(c.state.state, SessionState.waiting);
        expect(c.state.currentTimeLimitMs, 2000);
      } finally {
        c.dispose();
      }
    });

    testWidgets('turning the setting off asks new words right away', (
      tester,
    ) async {
      final c = _controller(tester, _Progress());
      try {
        await c.startSession(config());
        expect(c.state.state, SessionState.waiting);
        expect(c.state.currentTimeLimitMs, 2000);
      } finally {
        c.dispose();
      }
    });
  });
}
