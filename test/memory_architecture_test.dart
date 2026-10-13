import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/features/memory/domain/recall_models.dart';
import 'package:vocab_flash_test/features/memory/domain/memory_scheduler.dart';
import 'package:vocab_flash_test/features/study/domain/study_plan.dart';
import 'package:vocab_flash_test/features/study/domain/session_checkpoint.dart';
import 'package:vocab_flash_test/models/attempt.dart';
import 'package:vocab_flash_test/models/card_state.dart';
import 'package:vocab_flash_test/session/session_models.dart';

void main() {
  group('memory architecture', () {
    test('assisted success does not count as independent long-term recall', () {
      final evidence = RecallEvidence(
        eventId: 'e1',
        sessionId: 's1',
        itemId: 1,
        lexemeId: 1,
        skill: LearningSkill.meaningRecognition,
        taskType: ReviewTaskType.recognition,
        rating: RecallRating.recalled,
        source: EvaluationSource.objective,
        answerRevealed: true,
        hintUsed: false,
        isDueReview: true,
        activeDurationMs: 1000,
        occurredAt: DateTime(2026, 9, 11),
      );

      final evaluation = RecallEvaluator.evaluate(evidence);
      expect(evaluation.quality, 4);
      expect(evaluation.countsAsLongTermReview, isFalse);
      expect(evaluation.countsAsExposure, isTrue);
    });

    test('objective recall updates the card speed baseline', () {
      final state = CardState.newCard(3);
      final evidence = RecallEvidence(
        eventId: 'e2',
        sessionId: 's2',
        itemId: 3,
        lexemeId: 3,
        skill: LearningSkill.meaningRecognition,
        taskType: ReviewTaskType.recognition,
        rating: RecallRating.recalled,
        source: EvaluationSource.objective,
        answerRevealed: false,
        hintUsed: false,
        isDueReview: false,
        activeDurationMs: 800,
        occurredAt: DateTime(2026, 9, 11),
      );

      final next = const MemoryScheduler().schedule(state, evidence);
      expect(next.rtP50, 800);
      expect(next.revision, state.revision + 1);
    });

    test('manual known status stays separate from verified mastery', () {
      final manuallyKnown = CardState.newCard(4).copyWith(
        flags: CardState.manuallyKnownFlag,
        stability: 20,
        due: DateTime(2026, 10, 11),
      );

      expect(manuallyKnown.isMastered, isTrue);
      expect(manuallyKnown.isVerifiedMastered, isFalse);

      final reviewed = manuallyKnown.updateSRS(
        newStability: 18,
        newDifficulty: 2.2,
        newDue: DateTime(2026, 9, 18),
        newRtP50: 700,
        reviewedAt: DateTime(2026, 9, 11),
      );
      expect(reviewed.isManuallyKnown, isFalse);
    });

    test(
      'planner caps new words by remaining daily budget and time budget',
      () {
        final now = DateTime(2026, 9, 11);
        final candidates = [
          StudyCandidate(
            wordId: 1,
            dueAt: now.subtract(const Duration(days: 1)),
            isNew: false,
            isLeech: false,
            isRelearning: false,
            estimatedSeconds: 20,
          ),
          const StudyCandidate(
            wordId: 2,
            dueAt: null,
            isNew: true,
            isLeech: false,
            isRelearning: false,
            estimatedSeconds: 35,
          ),
          const StudyCandidate(
            wordId: 3,
            dueAt: null,
            isNew: true,
            isLeech: false,
            isRelearning: false,
            estimatedSeconds: 35,
          ),
        ];

        final plan = const StudyPlanner().build(
          candidates,
          const StudyPolicy(
            maxItems: 10,
            maxMinutes: 1,
            dailyNewLimit: 1,
            dailyNewUsed: 0,
          ),
          now: now,
        );

        expect(plan.wordIds, containsAll(<int>[1, 2]));
        expect(plan.wordIds, isNot(contains(3)));
        expect(plan.newItemCount, 1);
      },
    );

    test('checkpoint keeps the active question and delayed queue', () {
      final config = SessionConfig.defaultConfig;
      final data =
          SessionData.initial(
            initialQueue: const [],
            config: config,
            sessionId: 'session-1',
            initialAttempts: [
              Attempt(
                wordId: 8,
                result: AttemptResult.correct,
                rtMs: 700,
                chosenIndex: 0,
                correctIndex: 0,
                timestamp: DateTime(2026, 9, 11),
              ),
            ],
          ).copyWith(
            state: SessionState.waiting,
            delayedQueue: [DelayedItem(wordId: 9, afterN: 2, retryCount: 1)],
            millisLeft: 1200,
          );

      final checkpoint = SessionCheckpoint.fromSessionData(data);
      final decoded = SessionCheckpoint.fromJson(checkpoint.toJson());
      expect(decoded.sessionId, 'session-1');
      expect(decoded.delayedQueue.single['wordId'], 9);
      expect(decoded.millisLeft, 1200);
      expect(decoded.decodeAttempts().single.wordId, 8);
    });
  });
}
