import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/features/memory/domain/memory_scheduler.dart';
import 'package:vocab_flash_test/features/memory/domain/recall_models.dart';
import 'package:vocab_flash_test/models/attempt.dart';
import 'package:vocab_flash_test/models/card_state.dart';

RecallEvidence _evidence({
  int ms = 800,
  bool hint = false,
  bool revealed = false,
  AttemptKind kind = AttemptKind.initial,
  RecallRating rating = RecallRating.recalled,
  EvaluationSource source = EvaluationSource.objective,
}) => RecallEvidence(
  eventId: 'e',
  sessionId: 's',
  itemId: 1,
  lexemeId: 1,
  skill: LearningSkill.meaningRecognition,
  taskType: ReviewTaskType.recognition,
  rating: rating,
  source: source,
  answerRevealed: revealed,
  hintUsed: hint,
  isDueReview: true,
  activeDurationMs: ms,
  occurredAt: DateTime(2026, 10, 13, 7),
  attemptKind: kind,
);

void main() {
  final start = CardState.newCard(
    1,
    now: DateTime(2026, 10, 12, 7),
  ).copyWith(rtP50: 1500);
  const scheduler = MemoryScheduler();

  test('independent objective answers update the speed baseline', () {
    final next = scheduler.schedule(start, _evidence(ms: 900));
    expect(next.rtP50, (1500 * 0.7 + 900 * 0.3).round());
  });

  test('retries, hints, revealed answers and self-reports leave it alone', () {
    for (final e in [
      _evidence(ms: 300, kind: AttemptKind.inSessionRetry),
      _evidence(ms: 300, hint: true),
      _evidence(ms: 300, revealed: true),
      _evidence(ms: 9000, source: EvaluationSource.selfReport),
      _evidence(ms: 300, rating: RecallRating.forgot),
    ]) {
      expect(scheduler.schedule(start, e).rtP50, 1500);
    }
  });
}
