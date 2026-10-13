import '../../../models/card_state.dart';
import 'recall_models.dart';

/// 新架构使用的能力级记忆状态值对象。
/// 旧版 CardState 仍是持久化兼容模型，通过适配器映射到这里。
class MemoryState {
  final String itemId;
  final MemoryPhase phase;
  final double stability;
  final double difficulty;
  final DateTime dueAt;
  final DateTime? lastReviewedAt;
  final int lapses;
  final int revision;
  final int independentLongTermReviews;
  final String schedulerVersion;

  const MemoryState({
    required this.itemId,
    required this.phase,
    required this.stability,
    required this.difficulty,
    required this.dueAt,
    required this.lastReviewedAt,
    required this.lapses,
    required this.revision,
    required this.independentLongTermReviews,
    required this.schedulerVersion,
  });

  factory MemoryState.fromLegacyCard(CardState state) => MemoryState(
    itemId: 'legacy:${state.wordId}:meaning-recognition',
    phase:
        state.revision == 0 && state.lapses == 0 && state.longTermReviews == 0
        ? MemoryPhase.newCard
        : state.lapses > 0
        ? MemoryPhase.relearning
        : state.longTermReviews > 0
        ? MemoryPhase.review
        : MemoryPhase.learning,
    stability: state.stability,
    difficulty: state.difficulty,
    dueAt: state.due,
    lastReviewedAt: state.lastReview,
    lapses: state.lapses,
    revision: state.revision,
    independentLongTermReviews: state.longTermReviews,
    schedulerVersion: 'legacy-srs-v1',
  );

  bool get isMastered => stability >= 16 && independentLongTermReviews >= 2;
}
