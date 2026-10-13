import '../models/models.dart';
import '../domain/srs.dart';
import 'session_models.dart';

/// 会话内纠错调度器。
///
/// 延迟项使用“允许出现的已结算题号”，而不是每道题都修改的倒计数器。
/// 这样主队列耗尽时仍能确定性地选择下一项，也不会因尾部没有占位题而死锁。
class DelayedReplayManager {
  /// 重测至少间隔的题数。与 `SessionData.correctionStreak` 要求的
  /// 「至少三道其他题」一致，延迟预设不得低于它，否则设置会被静默改写。
  static const int minRetryGap = 3;

  const DelayedReplayManager();

  bool shouldDelayWord(Attempt attempt, SessionConfig config) {
    if (attempt.isWrong || attempt.isTimeout) return true;
    if (!attempt.isCorrect) return false;

    return SrsAlgorithm.calculateQuality(
          result: attempt.result,
          reactionTime: attempt.rtMs,
          timeLimit: config.timeLimitMs,
          slowThresholdMultiplier: config.slowThreshold,
        ) ==
        3;
  }

  /// 为一次失败或慢答安排下一次会话内重测。
  ///
  /// [completedQuestionCount] 包含刚刚结算的这道题。比如当前是第 1
  /// 道题、错题间隔为 3，则该项的 [DelayedItem.eligibleAfterQuestion]
  /// 为 4，表示先完成第 2、3、4 题后才可参与下一题选择。
  List<DelayedItem> scheduleDelayedReplay({
    required List<DelayedItem> delayedQueue,
    required Attempt attempt,
    required SessionConfig config,
    int sessionRetryCount = 0,
    int completedQuestionCount = 0,
  }) {
    final retryLimit = config.maxRetriesPerWord;
    final existingIndex = delayedQueue.indexWhere(
      (item) => item.wordId == attempt.wordId,
    );
    final existingRetryCount = existingIndex >= 0
        ? delayedQueue[existingIndex].retryCount
        : 0;
    final nextRetryCount =
        (sessionRetryCount > existingRetryCount
            ? sessionRetryCount
            : existingRetryCount) +
        1;

    if (nextRetryCount > retryLimit || retryLimit == 0) {
      final withoutWord = List<DelayedItem>.from(delayedQueue)
        ..removeWhere((item) => item.wordId == attempt.wordId);
      return withoutWord;
    }

    final delay = attempt.isWrong || attempt.isTimeout
        ? config.wrongDelay
        : config.slowDelay;
    final eligibleAfter =
        completedQuestionCount + delay.clamp(minRetryGap, 1000);
    final replacement = DelayedItem(
      wordId: attempt.wordId,
      eligibleAfterQuestion: eligibleAfter,
      retryCount: nextRetryCount,
    );
    final updated = List<DelayedItem>.from(delayedQueue)
      ..removeWhere((item) => item.wordId == attempt.wordId);
    updated.add(replacement);
    return updated;
  }

  /// 兼容旧调用方：返回已成熟项插入主队列后的结果。
  ///
  /// 新 SessionController 直接按题号选择成熟项，因此不会调用这个方法
  /// 递减队列。保留它可以安全读取旧快照和支持外部测试工具。
  ({List<Word> mainQueue, List<DelayedItem> delayedQueue}) processDelayedQueue({
    required List<Word> mainQueue,
    required List<DelayedItem> delayedQueue,
    required List<Word> candidatePool,
    int completedQuestionCount = 0,
  }) {
    final matured = delayedQueue
        .where((item) => item.isEligibleAt(completedQuestionCount))
        .toList();
    if (matured.isEmpty) {
      return (
        mainQueue: List<Word>.from(mainQueue),
        delayedQueue: delayedQueue,
      );
    }

    final maturedIds = matured.map((item) => item.wordId).toSet();
    final remaining = delayedQueue
        .where((item) => !maturedIds.contains(item.wordId))
        .toList();
    final result = List<Word>.from(mainQueue);
    for (final item in matured.reversed) {
      final word = candidatePool.where(
        (candidate) => candidate.id == item.wordId,
      );
      if (word.isNotEmpty) result.insert(0, word.first);
    }
    return (mainQueue: result, delayedQueue: remaining);
  }
}
