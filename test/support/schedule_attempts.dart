import 'package:vocab_flash_test/features/memory/application/recall_commit_service.dart';
import 'package:vocab_flash_test/features/memory/domain/memory_scheduler.dart';
import 'package:vocab_flash_test/features/memory/domain/recall_models.dart';
import 'package:vocab_flash_test/models/attempt.dart';
import 'package:vocab_flash_test/models/card_state.dart';

/// 按线上同一条路径（作答 → 评分证据 → MemoryScheduler）依次调度作答。
CardState scheduleAttempts(
  CardState card,
  Iterable<Attempt> attempts, {
  int timeLimitMs = 2000,
  double slowThreshold = 1.5,
}) {
  final ordered = attempts.toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  var state = card;
  for (var i = 0; i < ordered.length; i++) {
    final attempt = ordered[i];
    final evidence = RecallCommitService.evidenceFromAttempt(
      sessionId: 'test',
      eventId: 'test-$i',
      attempt: attempt,
      timeLimitMs: timeLimitMs,
      slowThreshold: slowThreshold,
      baselineRtMs: state.rtP50 > 0 ? state.rtP50 : null,
      isDueReview: RecallCommitService.isDueOn(state.due, attempt.timestamp),
      answerRevealed: attempt.highestHintLevel >= 3,
      hintUsed: attempt.usedHint,
      taskType: ReviewTaskType.recognition,
      skill: LearningSkill.meaningRecognition,
      source: EvaluationSource.objective,
      ratingOverride: null,
    );
    state = const MemoryScheduler().schedule(
      state,
      evidence,
      reviewedAt: attempt.timestamp,
    );
  }
  return state;
}
