import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/models/models.dart';
import 'package:vocab_flash_test/session/session_models.dart';

Word word(int id) => Word(
  id: id,
  headword: 'word$id',
  lemma: 'word$id',
  level: 'A1',
  pos: 'n.',
  cnDefs: ['词$id'],
);
Attempt answer(int id, {bool wrong = false}) => Attempt(
  wordId: id,
  result: wrong ? AttemptResult.wrong : AttemptResult.correct,
  rtMs: 500,
  chosenIndex: wrong ? 1 : 0,
  correctIndex: 0,
  timestamp: DateTime(2026, 9, 16),
);
void main() {
  final config = SessionConfig.defaultConfig.copyWith(wordsPerSession: 100);
  test(
    'consolidation counts active unique work without inflating coverage',
    () {
      final data =
          SessionData.initial(
            initialQueue: [word(1), word(2)],
            config: config,
            sessionId: 's',
          ).copyWith(
            state: SessionState.waiting,
            mainQueue: [],
            attempts: [answer(1, wrong: true), answer(2)],
            currentQuestion: Question(
              word: word(1),
              options: ['a', 'b', 'c', 'd'],
              correctIndex: 0,
            ),
            delayedQueue: [DelayedItem(wordId: 1), DelayedItem(wordId: 2)],
            unresolvedWordIds: {3},
          );
      expect(data.testProgressLabel, '已测 2 / 2');
      expect(data.testedProgressRatio, 1);
      expect(data.testGroupLabel, '巩固中 · 剩余 2 词');
      expect(data.copyWith(totalWords: 100).testGroupLabel, '重测');
      final feedback = data.copyWith(
        state: SessionState.resolved,
        delayedQueue: [DelayedItem(wordId: 2)],
      );
      expect(feedback.testGroupLabel, '巩固中 · 剩余 1 词');
      final done = feedback.copyWith(delayedQueue: []);
      expect(done.isConsolidating, isFalse);
      expect(
        data.copyWith(state: SessionState.finished).isConsolidating,
        isFalse,
      );
    },
  );
  test('configured group size remains distinct from eligible plan size', () {
    final data = SessionData.initial(
      initialQueue: [word(1), word(2)],
      config: config,
      sessionId: 's',
    );
    expect(data.testGroupLabel, '');
    expect(data.testProgressLabel, '已测 0 / 2');
    expect(data.testedProgressRatio, 0);
  });
  test(
    'wrong answers count once, replay never inflates or reduces coverage',
    () {
      var data = SessionData.initial(
        initialQueue: List.generate(100, (i) => word(i + 1)),
        config: config,
        sessionId: 's',
      );
      data = data.copyWith(
        attempts: [answer(1, wrong: true), answer(2), answer(1)],
      );
      expect(data.testProgressLabel, '已测 2 / 100');
      expect(data.testedProgressRatio, .02);
      data = data.copyWith(
        delayedQueue: [DelayedItem(wordId: 1)],
        attempts: [...data.attempts, answer(1, wrong: true)],
      );
      expect(data.testProgressLabel, '已测 2 / 100');
      expect(data.testedProgressRatio, .02);
    },
  );
  test(
    'resuming counts union of answered and remaining words, with overlaps deduplicated',
    () {
      final data = SessionData.initial(
        initialQueue: [word(2), word(3)],
        initialAttempts: [answer(1), answer(2, wrong: true), answer(1)],
        config: config,
        sessionId: 's',
      );
      expect(data.totalWords, 3);
      expect(data.testProgressLabel, '已测 2 / 3');
      expect(data.testedProgressRatio, closeTo(2 / 3, .0001));
    },
  );
  test('feedback for first answer is not labelled as replay', () {
    final data =
        SessionData.initial(
          initialQueue: [word(1)],
          config: config,
          sessionId: 's',
        ).copyWith(
          state: SessionState.resolved,
          currentQuestion: Question(
            word: word(1),
            options: ['a', 'b', 'c', 'd'],
            correctIndex: 0,
          ),
          attempts: [answer(1)],
        );
    expect(data.testGroupLabel, '');
    final replay = data.copyWith(state: SessionState.waiting);
    expect(replay.testGroupLabel, '巩固中 · 剩余 1 词');
    expect(replay.testedProgressRatio, 1);
  });
}
