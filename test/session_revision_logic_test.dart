import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/domain/srs.dart';
import 'package:vocab_flash_test/models/models.dart';
import 'package:vocab_flash_test/session/delayed_replay_manager.dart';
import 'package:vocab_flash_test/session/session_models.dart';

void main() {
  final config = SessionConfig.defaultConfig.copyWith(
    timeLimitMs: 2000,
    wrongDelay: 3,
    slowDelay: 4,
    maxRetriesPerWord: 2,
    maxTotalAttempts: 20,
    cooldownWindow: 2,
  );

  Word word(int id) => Word(
    id: id,
    headword: 'word$id',
    lemma: 'word$id',
    level: 'A1',
    pos: 'n.',
    cnDefs: ['definition$id'],
  );

  Attempt attempt({
    required int wordId,
    required AttemptResult result,
    required DateTime timestamp,
    AttemptKind kind = AttemptKind.initial,
    int highestHintLevel = 0,
  }) => Attempt(
    wordId: wordId,
    result: result,
    rtMs: result == AttemptResult.timeout ? 2000 : 500,
    chosenIndex: result == AttemptResult.timeout ? -1 : 0,
    correctIndex: 0,
    timestamp: timestamp,
    kind: kind,
    highestHintLevel: highestHintLevel,
  );

  group('session revision invariants', () {
    test('delayed replay uses an absolute eligible question number', () {
      const manager = DelayedReplayManager();
      final failed = attempt(
        wordId: 1,
        result: AttemptResult.wrong,
        timestamp: DateTime(2026, 1, 1),
      );

      final queue = manager.scheduleDelayedReplay(
        delayedQueue: const [],
        attempt: failed,
        config: config,
        completedQuestionCount: 1,
      );

      expect(queue.single.eligibleAfterQuestion, 4);
      expect(queue.single.isEligibleAt(3), isFalse);
      expect(queue.single.isEligibleAt(4), isTrue);

      final beforeMaturity = manager.processDelayedQueue(
        mainQueue: [word(2)],
        delayedQueue: queue,
        candidatePool: [word(1), word(2)],
        completedQuestionCount: 3,
      );
      expect(beforeMaturity.delayedQueue, hasLength(1));
      expect(beforeMaturity.mainQueue.map((item) => item.id), [2]);
    });

    test('retry limit produces a finite unresolved outcome', () {
      const manager = DelayedReplayManager();
      final failed = attempt(
        wordId: 1,
        result: AttemptResult.wrong,
        timestamp: DateTime(2026, 1, 1),
      );
      var queue = <DelayedItem>[];

      queue = manager.scheduleDelayedReplay(
        delayedQueue: queue,
        attempt: failed,
        config: config,
        sessionRetryCount: 0,
        completedQuestionCount: 1,
      );
      queue = manager.scheduleDelayedReplay(
        delayedQueue: queue,
        attempt: failed.copyWith(kind: AttemptKind.inSessionRetry),
        config: config,
        sessionRetryCount: 1,
        completedQuestionCount: 3,
      );
      expect(queue.single.retryCount, 2);

      final exhausted = manager.scheduleDelayedReplay(
        delayedQueue: queue,
        attempt: failed.copyWith(kind: AttemptKind.inSessionRetry),
        config: config,
        sessionRetryCount: 2,
        completedQuestionCount: 5,
      );
      expect(exhausted, isEmpty);
    });

    test('first answer metrics are not diluted by an in-session retry', () {
      final firstTime = DateTime(2026, 1, 1, 9);
      final session = SessionData.initial(
        initialQueue: [word(1)],
        config: config,
        sessionId: 'session',
        initialAttempts: [
          attempt(
            wordId: 1,
            result: AttemptResult.wrong,
            timestamp: firstTime,
          ),
          attempt(
            wordId: 1,
            result: AttemptResult.correct,
            timestamp: firstTime.add(const Duration(minutes: 1)),
            kind: AttemptKind.inSessionRetry,
          ),
        ],
      );

      expect(session.firstAttempts, hasLength(1));
      expect(session.firstAccuracy, 0.0);
      expect(session.firstWrongWordIds, {1});
      expect(session.correctedWordIds, {1});
      expect(session.correctionSuccessRate, 1.0);
    });

    test('in-session retry does not add a second lapse or long-term review', () {
      final start = DateTime(2026, 1, 1, 9);
      final state = CardState.newCard(1, now: start);
      final updated = SrsAlgorithm.batchUpdateCardStates(
        {1: state},
        [
          attempt(
            wordId: 1,
            result: AttemptResult.wrong,
            timestamp: start,
          ),
          attempt(
            wordId: 1,
            result: AttemptResult.correct,
            timestamp: start.add(const Duration(minutes: 1)),
            kind: AttemptKind.inSessionRetry,
          ),
        ],
        2000,
      )[1]!;

      expect(updated.lapses, 1);
      expect(updated.longTermReviews, 0);
      expect(updated.isMastered, isFalse);
    });

    test('assisted and slow responses remain distinct from fast recall', () {
      expect(
        SrsAlgorithm.classifyResponseQuality(
          result: AttemptResult.correct,
          reactionTime: 1700,
          timeLimit: 2000,
          baselineRtMs: 1200,
          slowThresholdMultiplier: 1.5,
        ),
        ResponseQuality.slow,
      );
      expect(
        SrsAlgorithm.classifyResponseQuality(
          result: AttemptResult.correct,
          reactionTime: 300,
          timeLimit: 2000,
          highestHintLevel: 1,
        ),
        ResponseQuality.assisted,
      );
    });
  });
}
