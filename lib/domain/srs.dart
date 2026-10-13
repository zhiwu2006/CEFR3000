import 'dart:math';
import '../models/models.dart';

/// SRS 算法配置（值对象，不可变）
class SrsConfig {
  final double alphaStability; // 稳定度调整系数
  final double betaFailure; // 失败时稳定度下限
  final double gammaInterval; // 间隔计算系数
  final int maxIntervalDays; // 最大间隔天数

  const SrsConfig({
    this.alphaStability = 0.18,
    this.betaFailure = 1.2,
    this.gammaInterval = 1.0,
    this.maxIntervalDays = 90,
  });

  /// 从 SrsSettings 构造
  factory SrsConfig.fromSettings(SrsSettings s) => SrsConfig(
    alphaStability: s.alphaStability.clamp(0.05, 1.0),
    betaFailure: s.betaFailure.clamp(0.5, 5.0),
    gammaInterval: s.gammaInterval.clamp(0.2, 5.0),
    maxIntervalDays: s.maxIntervalDays.clamp(1, 365),
  );

  static const defaultConfig = SrsConfig();
}

/// Leech 判定策略（值对象，不可变）
class LeechPolicy {
  final int lapsesThreshold;
  final bool includeMarked;

  const LeechPolicy({this.lapsesThreshold = 2, this.includeMarked = true});

  static const defaultPolicy = LeechPolicy();

  /// 判断一个卡片是否为 Leech
  ///
  /// 遗忘次数只对「学会过」（至少一次跨日成功回忆）的词有意义；从没学会的
  /// 词答错只是还在学习中，归入重学而不是疑难词。用户手动标记的仍然算。
  bool isLeech(CardState state) =>
      (state.longTermReviews > 0 && state.lapses >= lapsesThreshold) ||
      (includeMarked && state.isMarkedDifficult);
}

/// SRS 算法实现（纯函数，无任何可变状态）
class SrsAlgorithm {
  const SrsAlgorithm._();

  // ============================================================
  // 质量评分
  // ============================================================

  /// 计算质量分数
  ///
  /// [result] 答题结果
  /// [reactionTime] 反应时间（毫秒）
  /// [timeLimit] 时间限制（毫秒）
  /// [baselineRtMs] 用户/卡片的中位反应时间（可选，用于自适应阈值）
  ///
  /// 返回质量分 q ∈ {1, 3, 4, 5}
  static int calculateQuality({
    required AttemptResult result,
    required int reactionTime,
    required int timeLimit,
    int? baselineRtMs,
    double slowThresholdMultiplier = 1.5,
  }) {
    switch (result) {
      case AttemptResult.wrong:
      case AttemptResult.timeout:
        return 1; // 错误或超时

      case AttemptResult.correct:
        final safeTimeLimit = max(1, timeLimit);
        // 没有历史速度时，以时限的 60% 作为保守的初始基线。
        // 慢答阈值始终被限制在答题时限内，避免“慢答”在逻辑上永远不可能发生。
        final hasBaseline = baselineRtMs != null && baselineRtMs > 0;
        final baseline = hasBaseline
            ? baselineRtMs.toDouble()
            : safeTimeLimit * 0.6;
        final fastThreshold = hasBaseline
            ? min(safeTimeLimit * 0.5, baseline * 0.8)
            : safeTimeLimit * 0.5;
        final normalizedSensitivity =
            (slowThresholdMultiplier.clamp(1.0, 2.5) - 1.0) / 1.5;
        // 旧设置保存的是 1.0~2.5x。将它映射为有限的敏感度，保证阈值
        // 仍在时限内，同时避免历史基准稍慢时“慢答”永远不可达。
        final effectiveMultiplier = 0.8 + normalizedSensitivity * 0.6;
        final configuredSlow = baseline * effectiveMultiplier;
        final slowThreshold = min(
          safeTimeLimit * 0.95,
          max(safeTimeLimit * 0.8, configuredSlow),
        );

        if (reactionTime <= fastThreshold) {
          return 5; // 快对
        } else if (reactionTime >= slowThreshold) {
          return 3; // 慢对
        }
        return 4; // 普通对
    }
  }

  /// 将数值质量映射为展示和统计使用的质量标签。
  ///
  /// deadline 仍由会话倒计时负责；这里的 slow 只会出现在截止前已提交、
  /// 且高于慢答阈值的正确答案中。
  static ResponseQuality classifyResponseQuality({
    required AttemptResult result,
    required int reactionTime,
    required int timeLimit,
    int? baselineRtMs,
    double slowThresholdMultiplier = 1.5,
    int highestHintLevel = 0,
  }) {
    if (result != AttemptResult.correct) return ResponseQuality.failed;
    if (highestHintLevel > 0) return ResponseQuality.assisted;
    final quality = calculateQuality(
      result: result,
      reactionTime: reactionTime,
      timeLimit: timeLimit,
      baselineRtMs: baselineRtMs,
      slowThresholdMultiplier: slowThresholdMultiplier,
    );
    return switch (quality) {
      5 => ResponseQuality.fast,
      3 => ResponseQuality.slow,
      _ => ResponseQuality.ordinary,
    };
  }

  // ============================================================
  // 卡片状态更新
  // ============================================================

  /// 更新卡片状态
  static CardState updateCardState(
    CardState currentState,
    int quality, {
    DateTime? reviewedAt,
    bool shortTermReview = false,
    bool countFailureAsLongTerm = true,
    SrsConfig config = const SrsConfig(),
  }) {
    final newDifficulty = _updateDifficulty(currentState.difficulty, quality);
    final newStability = _updateStability(
      currentState.stability,
      quality,
      config,
      shortTermReview: shortTermReview,
    );
    final intervalDays = _calculateInterval(
      newStability,
      newDifficulty,
      config,
    );
    // 到期时间从实际复习时刻开始计算，不额外人为延后一天的复习。
    final reviewTime = reviewedAt ?? DateTime.now();
    final calculatedDue = reviewTime.add(Duration(days: intervalDays));
    // 提前的同日复测只强化短时记忆，不应把原本更晚的长期复习日期不断
    // 推后；已经到期的卡片仍按本次复习重新安排。
    final newDue = shortTermReview && currentState.due.isAfter(calculatedDue)
        ? currentState.due
        : calculatedDue;

    return currentState.updateSRS(
      newStability: newStability,
      newDifficulty: newDifficulty,
      newDue: newDue,
      newRtP50: currentState.rtP50,
      reviewedAt: reviewTime,
      countsAsLongTermReview: !shortTermReview && quality >= 3,
      // 遗忘（lapse）指学会后又忘记：从没跨日答对过的词答错不计。
      increaselapses:
          quality <= 2 &&
          countFailureAsLongTerm &&
          currentState.longTermReviews > 0,
    );
  }

  // ============================================================
  // 内部算法（P1 改进已内联）
  // ============================================================

  /// 更新难度 — 使用均值回归（P2 修复）
  ///
  /// 目标难度由 quality 决定，实际难度朝目标方向渐进移动。
  /// 这避免了"一次答错就大幅跳变"的问题。
  static double _updateDifficulty(double currentDifficulty, int quality) {
    // 目标难度：quality 越高，目标越低
    final targetD = max(1.2, 3.0 - (quality - 1) * 0.4);
    // 朝目标方向移动（步长 10%，避免震荡）
    final newD = currentDifficulty + 0.1 * (targetD - currentDifficulty);
    return newD.clamp(1.2, 3.0);
  }

  /// 更新稳定度（P1 修复：引入对数衰减因子）
  ///
  /// 正确时：S' = S * (1 + α * (q-2) * dampingFactor)
  ///   dampingFactor 随稳定度增大而减小，防止高稳定度卡片增长过快
  /// 失败时：保留部分记忆痕迹，高稳定度卡片保留更多（渐进式惩罚）
  static double _updateStability(
    double currentStability,
    int quality,
    SrsConfig config, {
    bool shortTermReview = false,
  }) {
    if (quality >= 3) {
      // 对数衰减因子：稳定度越高，增长越慢
      final growthDamping =
          1.0 / (1.0 + log(max(1.0, currentStability)) * 0.15);
      final growth = config.alphaStability * (quality - 2) * growthDamping;
      // 同日/短间隔重测主要反映短时记忆，只给予长期增长的一小部分。
      final multiplier =
          1 + (shortTermReview ? min(0.065, growth * 0.12) : growth);
      return currentStability * multiplier;
    } else {
      // 渐进式惩罚：高稳定度卡片保留更多"记忆痕迹"
      // 0.20 ~ 0.30，根据稳定度线性插值
      final retainRatio = 0.20 + 0.10 * min(1.0, currentStability / 30.0);
      return max(config.betaFailure, currentStability * retainRatio);
    }
  }

  /// 计算复习间隔（天数）
  static int _calculateInterval(
    double stability,
    double difficulty,
    SrsConfig config,
  ) {
    final rawInterval = config.gammaInterval * stability / difficulty;
    return rawInterval.round().clamp(1, config.maxIntervalDays);
  }

  // ============================================================
  // 牌组与统计（使用 LeechPolicy 参数）
  // ============================================================

  /// 获取今日牌组（到期词 + 不熟词）
  static List<int> getTodayDeck(
    Map<int, CardState> allStates,
    Set<String> levels,
    bool onlyLeeches, {
    LeechPolicy leechPolicy = const LeechPolicy(),
    Map<int, String>? wordLevels,
  }) {
    final today = DateTime.now();
    final todayWordIds = <int>[];

    for (final state in allStates.values) {
      if (wordLevels != null && levels.isNotEmpty) {
        final level = wordLevels[state.wordId];
        if (level == null || !levels.contains(level)) continue;
      }
      final isDue =
          state.due.isBefore(today) || state.due.isAtSameMomentAs(today);
      final isLeech = leechPolicy.isLeech(state);

      if (onlyLeeches) {
        if (isLeech) todayWordIds.add(state.wordId);
      } else {
        if (isDue || isLeech) todayWordIds.add(state.wordId);
      }
    }

    return todayWordIds;
  }

  /// 预测学习进度
  static Map<String, dynamic> predictProgress(List<CardState> states) {
    if (states.isEmpty) {
      return {
        'totalCards': 0,
        'learnedCards': 0,
        'masteredCards': 0,
        'avgStability': 0.0,
        'avgDifficulty': 0.0,
        'dueToday': 0,
        'dueThisWeek': 0,
      };
    }

    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));

    int learnedCards = 0; // 稳定度 >= 7天
    int masteredCards = 0; // 稳定度和跨日成功复习共同满足
    int dueToday = 0;
    int dueThisWeek = 0;

    double totalStability = 0;
    double totalDifficulty = 0;

    for (final state in states) {
      totalStability += state.stability;
      totalDifficulty += state.difficulty;

      if (state.stability >= 7) learnedCards++;
      if (state.isMastered) masteredCards++;

      if (state.isDue) dueToday++;
      if (state.due.isBefore(weekFromNow)) dueThisWeek++;
    }

    return {
      'totalCards': states.length,
      'learnedCards': learnedCards,
      'masteredCards': masteredCards,
      'avgStability': totalStability / states.length,
      'avgDifficulty': totalDifficulty / states.length,
      'dueToday': dueToday,
      'dueThisWeek': dueThisWeek,
    };
  }
}
