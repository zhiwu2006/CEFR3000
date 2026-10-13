import 'word.dart';

/// 重点记忆单词归因原因枚举
enum FocusWordReason {
  /// 本次答错
  wrong,

  /// 答题超时
  timeout,

  /// 迟疑/勉强正确（反应时间超过阈值，提取努力高，记忆脆弱）
  hesitation,

  /// FSRS 历史高失忆/难词
  leech,

  /// 当日跨轮次高频出错
  frequentFail,
}

/// 重点记忆单词实体
class FocusWordItem {
  final Word word;
  final int focusScore;
  final Set<FocusWordReason> reasons;
  final int? reactionTimeMs;
  final int? lapses;
  final double? stability;

  const FocusWordItem({
    required this.word,
    required this.focusScore,
    required this.reasons,
    this.reactionTimeMs,
    this.lapses,
    this.stability,
  });

  /// 获取主要展示标签描述
  String get primaryReasonText {
    if (reasons.contains(FocusWordReason.frequentFail)) {
      return '高频顽固';
    }
    if (reasons.contains(FocusWordReason.wrong)) {
      return '本次答错';
    }
    if (reasons.contains(FocusWordReason.timeout)) {
      return '答题超时';
    }
    if (reasons.contains(FocusWordReason.hesitation)) {
      final sec = ((reactionTimeMs ?? 0) / 1000).toStringAsFixed(1);
      return '迟疑答对 (${sec}s)';
    }
    if (reasons.contains(FocusWordReason.leech)) {
      return '易失忆难词';
    }
    return '重点复习';
  }
}

/// 单次测试会话摘要（用于时间轴呈现）
class SessionRunSummary {
  final String id;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final double accuracy;
  final int avgRtMs;
  final int timeLimitMs;
  final List<String> levels;
  final int focusWordCount;

  const SessionRunSummary({
    required this.id,
    required this.startedAt,
    this.finishedAt,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.accuracy,
    required this.avgRtMs,
    required this.timeLimitMs,
    required this.levels,
    required this.focusWordCount,
  });

  /// 测试耗时
  Duration get duration {
    if (finishedAt == null) return Duration.zero;
    return finishedAt!.difference(startedAt);
  }
}

/// 按自然日聚合的每日学习历史汇总
class DailyHistorySummary {
  final DateTime date;
  final List<SessionRunSummary> sessions;
  final int totalWordsTested;
  final double averageAccuracy;
  final int totalDurationMs;
  final List<FocusWordItem> focusWords;

  const DailyHistorySummary({
    required this.date,
    required this.sessions,
    required this.totalWordsTested,
    required this.averageAccuracy,
    required this.totalDurationMs,
    required this.focusWords,
  });

  int get sessionCount => sessions.length;
}
