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
  final words = List.generate(
    4,
    (i) => Word(
      id: i + 1,
      headword: 'word$i',
      lemma: 'word$i',
      level: 'A1',
      pos: 'n.',
      cnDefs: ['释义$i'],
    ),
  );
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
    'screen lifecycle never saves and resumed is not overwritten by an old callback',
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
      await tester.pump(const Duration(milliseconds: 800));
      expect(c.state.isPaused, isFalse);
      expect(c.state.state, SessionState.waiting);
      expect(c.state.currentQuestion!.word.id, 2);
      expect(repo.writes, 0);
      expect(prefs.containsKey('study_session_checkpoint_v1'), isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
