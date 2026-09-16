import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/domain/srs.dart';
import 'package:vocab_flash_test/models/models.dart';
import 'package:vocab_flash_test/session/delayed_replay_manager.dart';
import 'package:vocab_flash_test/session/session_models.dart';

void main() {
  group('SRS timing and rating', () {
    final config = SessionConfig.defaultConfig.copyWith(
      timeLimitMs: 2000,
      slowThreshold: 1.5,
    );

    test('slow rating and delayed replay use the same reachable boundary', () {
      const manager = DelayedReplayManager();
      final slow = Attempt.correct(
        wordId: 1,
        rtMs: 1600,
        chosenIndex: 0,
        correctIndex: 0,
      );
      final ordinary = Attempt.correct(
        wordId: 2,
        rtMs: 1599,
        chosenIndex: 0,
        correctIndex: 0,
      );

      expect(
        SrsAlgorithm.calculateQuality(
          result: slow.result,
          reactionTime: slow.rtMs,
          timeLimit: config.timeLimitMs,
          slowThresholdMultiplier: config.slowThreshold,
        ),
        3,
      );
      expect(manager.shouldDelayWord(slow, config), isTrue);
      expect(manager.shouldDelayWord(ordinary, config), isFalse);
    });

    test('a first review can be fast without a historical baseline', () {
      expect(
        SrsAlgorithm.calculateQuality(
          result: AttemptResult.correct,
          reactionTime: 1000,
          timeLimit: 2000,
        ),
        5,
      );
      expect(
        SrsAlgorithm.calculateQuality(
          result: AttemptResult.correct,
          reactionTime: 1800,
          timeLimit: 2000,
        ),
        3,
      );
    });

    test(
      'a scheduled one-day interval is about 24 hours, without an extra hour',
      () {
        final now = DateTime.now();
        final card = CardState.newCard(1).copyWith(lastReview: now);
        final updated = SrsAlgorithm.updateCardState(card, 1, reviewedAt: now);
        final minutes = updated.due.difference(now).inMinutes;
        expect(minutes, inInclusiveRange(24 * 60 - 1, 24 * 60 + 1));
        expect(minutes, lessThan(25 * 60));
      },
    );

    test('immediate repetitions only strengthen short-term memory', () {
      final start = DateTime.now().subtract(const Duration(minutes: 1));
      var card = CardState.newCard(1).copyWith(lastReview: start);
      final attempts = [
        for (var i = 0; i < 12; i++)
          Attempt(
            wordId: 1,
            result: AttemptResult.correct,
            rtMs: 300,
            chosenIndex: 0,
            correctIndex: 0,
            timestamp: start.add(Duration(minutes: i + 1)),
          ),
      ];

      card = SrsAlgorithm.batchUpdateCardStates({1: card}, attempts, 2000)[1]!;

      expect(card.longTermReviews, 0);
      expect(card.stability, lessThan(7));
      expect(card.isMastered, isFalse);
    });

    test('early same-day reviews do not postpone an existing due date', () {
      final now = DateTime.now();
      final due = now.add(const Duration(days: 5));
      final card = CardState.newCard(1).copyWith(
        lastReview: now.subtract(const Duration(minutes: 30)),
        due: due,
      );

      final updated = SrsAlgorithm.updateCardState(
        card,
        5,
        reviewedAt: now,
        shortTermReview: true,
      );

      expect(updated.due, due);
    });

    test(
      'a successful review after a long gap counts as long-term evidence',
      () {
        final now = DateTime.now();
        final card = CardState.newCard(
          1,
        ).copyWith(lastReview: now.subtract(const Duration(days: 2)));
        final updated = SrsAlgorithm.batchUpdateCardStates(
          {1: card},
          [
            Attempt(
              wordId: 1,
              result: AttemptResult.correct,
              rtMs: 500,
              chosenIndex: 0,
              correctIndex: 0,
              timestamp: now,
            ),
          ],
          2000,
        )[1]!;

        expect(updated.longTermReviews, 1);
      },
    );
  });

  test('reaction time is derived from active countdown time', () {
    final data = SessionData.initial(
      initialQueue: const [],
      config: SessionConfig.defaultConfig.copyWith(timeLimitMs: 2000),
      sessionId: 'timing',
    ).copyWith(millisLeft: 1250);

    expect(data.activeReactionTimeMs, 750);
  });
}
