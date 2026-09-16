import '../../../domain/srs.dart';
import '../../../models/card_state.dart';
import 'recall_models.dart';

/// 记忆状态的唯一调度入口。
///
/// 旧算法仍由 `SrsAlgorithm` 实现，但页面和会话不再直接调用它；
/// 未来可在这里替换成版本化 FSRS 适配器，而不改动学习流程。
class MemoryScheduler {
  static const version = 'legacy-srs-v1';
  final SrsConfig config;

  const MemoryScheduler({this.config = const SrsConfig()});

  CardState schedule(
    CardState current,
    RecallEvidence evidence, {
    DateTime? reviewedAt,
  }) {
    final evaluation = RecallEvaluator.evaluate(evidence);
    final shortTermReview = !evaluation.countsAsLongTermReview;
    final scheduled = SrsAlgorithm.updateCardState(
      current,
      evaluation.quality,
      reviewedAt: reviewedAt ?? evidence.occurredAt,
      shortTermReview: shortTermReview,
      countFailureAsLongTerm: !evidence.isInSessionRetry,
      config: config,
    );
    // 只用客观题的有效作答更新个人速度基线；自评回忆的停留时间不能
    // 与限时选择题混在一起，否则后续“慢答”阈值会失真。
    if (evidence.source == EvaluationSource.objective &&
        evidence.activeDurationMs > 0 &&
        evidence.rating != RecallRating.forgot) {
      final nextRtP50 = current.rtP50 <= 0
          ? evidence.activeDurationMs
          : ((current.rtP50 * 0.7) + (evidence.activeDurationMs * 0.3)).round();
      return scheduled.copyWith(rtP50: nextRtP50);
    }
    return scheduled;
  }
}
