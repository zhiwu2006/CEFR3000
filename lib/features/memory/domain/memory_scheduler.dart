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
    // 注意：这里刻意不传 `recallProb`。`SrsAlgorithm.estimateRecallProbability`
    // 及其 `_adjustStabilityByRecall` 分支因此**在生产路径上不会执行**——
    // 当前实际的稳定度更新是纯对数阻尼模型，不包含 FSRS 幂律回忆概率校正。
    // 这是已知的「实现与设计意图不一致」，属有意保留的现状，不是漏接线；
    // 若要启用，请在此显式传入 `recallProb:` 并同步更新本注释与审查文档。
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
