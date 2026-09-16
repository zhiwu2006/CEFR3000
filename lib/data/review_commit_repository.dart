import '../models/card_state.dart';
import '../models/exposure_event.dart';
import '../models/review_event.dart';

class ReviewCommitConflict implements Exception {
  final String message;

  const ReviewCommitConflict(this.message);

  @override
  String toString() => 'ReviewCommitConflict: $message';
}

class ReviewCommitResult {
  final CardState state;
  final bool alreadyCommitted;

  const ReviewCommitResult({
    required this.state,
    required this.alreadyCommitted,
  });
}

/// 可选的可靠回忆提交能力。旧的测试替身仍只实现 ProgressRepository，
/// 会话控制器会在没有该能力时回退到兼容路径。
abstract interface class ReviewCommitRepository {
  Future<ReviewCommitResult> commitReview(ReviewEvent event);

  Future<void> recoverPendingReviews();

  Future<ReviewEvent?> getReviewEvent(String eventId);

  Future<List<ReviewEvent>> getReviewEvents({String? sessionId});
}

/// 支持把回忆事件、卡片状态和首次接触额度放入同一事务的仓储能力。
///
/// Hive 适配器继续使用可恢复的 pending 日志；SQLite 适配器实现这个
/// 契约后，核心提交不会在事件、状态与新词接触记录之间留下半提交状态。
abstract interface class TransactionalRecallRepository
    implements ReviewCommitRepository {
  Future<TransactionalRecallResult> commitRecall({
    required ReviewEvent event,
    ExposureEvent? firstExposure,
  });
}

class TransactionalRecallResult {
  final CardState state;
  final bool alreadyCommitted;
  final bool firstExposureToday;

  const TransactionalRecallResult({
    required this.state,
    required this.alreadyCommitted,
    required this.firstExposureToday,
  });
}
