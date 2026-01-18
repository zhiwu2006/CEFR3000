import 'dart:math';
import '../models/models.dart';

/// SRS算法实现
class SrsAlgorithm {
  // SRS参数
  static const double _alphaStability = 0.18; // 稳定度调整系数（提升成长幅度）
  static const double _betaFailure = 1.2; // 失败时稳定度重置
  static const double _gammaInterval = 1.0; // 间隔计算系数

  /// 计算质量分数
  /// 
  /// [result] 答题结果
  /// [reactionTime] 反应时间（毫秒）
  /// [timeLimit] 时间限制（毫秒）
  /// 
  /// 返回质量分 q ∈ {1, 3, 4, 5}
  static int calculateQuality({
    required AttemptResult result,
    required int reactionTime,
    required int timeLimit,
  }) {
    switch (result) {
      case AttemptResult.wrong:
      case AttemptResult.timeout:
        return 1; // 错误或超时

      case AttemptResult.correct:
        // 根据反应时间细分
        if (reactionTime <= timeLimit * 0.5) {
          return 5; // 快对（反应时间 <= 50% 时限）
        } else if (reactionTime > timeLimit * 0.8) {
          return 3; // 慢对（反应时间 > 80% 时限）
        } else {
          return 4; // 普通对
        }
    }
  }

  /// 更新卡片状态
  /// 
  /// [currentState] 当前卡片状态
  /// [quality] 质量分数
  /// 
  /// 返回更新后的卡片状态
  static CardState updateCardState(CardState currentState, int quality) {
    final newDifficulty = _updateDifficulty(currentState.difficulty, quality);
    final newStability = _updateStability(currentState.stability, quality);
    final intervalDays = _calculateInterval(newStability, newDifficulty);
    // 加1小时缓冲，避免因毫秒级差导致 inDays 取整为0
    final newDue = DateTime.now().add(Duration(days: intervalDays, hours: 1));
    
    return currentState.updateSRS(
      newStability: newStability,
      newDifficulty: newDifficulty,
      newDue: newDue,
      newRtP50: currentState.rtP50, // 暂时不更新，可在会话结束时批量更新
      increaselapses: quality <= 2,
    );
  }

  /// 更新难度
  /// 
  /// 更直观的调整规则：
  /// - 低质量（<=2）：增加难度
  /// - 中等质量（3,4）：微调
  /// - 高质量（5）：降低难度
  static double _updateDifficulty(double currentDifficulty, int quality) {
    double adjustment;
    if (quality <= 2) {
      adjustment = 0.3;
    } else if (quality == 3) {
      adjustment = 0.05;
    } else if (quality == 4) {
      adjustment = -0.05;
    } else {
      adjustment = -0.3;
    }
    return (currentDifficulty + adjustment).clamp(1.2, 3.0);
  }

  /// 更新稳定度
  /// 
  /// 如果 q >= 3: S' = S * (1 + α * (quality-2))，quality 越高增幅越大
  /// 如果 q <= 2: S' = β
  static double _updateStability(double currentStability, int quality) {
    if (quality >= 3) {
      // 正确答题，质量越高提升越多
      final multiplier = 1 + _alphaStability * (quality - 2);
      return currentStability * multiplier;
    } else {
      // 错误答题，惩罚性降低稳定度，但保留 25% 的记忆痕迹，避免断崖式归零
      // 最小不低于 betaFailure (1.2)
      return max(_betaFailure, currentStability * 0.25);
    }
  }

  /// 计算复习间隔（天数）
  /// 
  /// I = γ * S' / D'，限制在 [1, 45] 天
  static int _calculateInterval(double stability, double difficulty) {
    final rawInterval = _gammaInterval * stability / difficulty;
    return rawInterval.round().clamp(1, 90);
  }

  /// 批量更新卡片状态
  /// 
  /// [states] 当前状态映射 wordId -> CardState
  /// [attempts] 答题记录列表
  /// [timeLimit] 时间限制
  /// 
  /// 返回更新后的状态映射
  static Map<int, CardState> batchUpdateCardStates(
    Map<int, CardState> states,
    List<Attempt> attempts,
    int timeLimit,
  ) {
    final updatedStates = <int, CardState>{};
    
    // 按单词ID分组答题记录
    final attemptsByWord = <int, List<Attempt>>{};
    for (final attempt in attempts) {
      attemptsByWord.putIfAbsent(attempt.wordId, () => []).add(attempt);
    }
    
    // 为每个单词更新状态
    for (final entry in attemptsByWord.entries) {
      final wordId = entry.key;
      final wordAttempts = entry.value;
      
      // 获取当前状态，如果不存在则创建新状态
      CardState currentState = states[wordId] ?? CardState.newCard(wordId);
      
      // 依次处理每次答题
      for (final attempt in wordAttempts) {
        final quality = calculateQuality(
          result: attempt.result,
          reactionTime: attempt.rtMs,
          timeLimit: timeLimit,
        );
        
        currentState = updateCardState(currentState, quality);
      }
      
      // 更新反应时间中位数
      final validRts = wordAttempts
          .where((a) => a.result != AttemptResult.timeout)
          .map((a) => a.rtMs)
          .toList();
      
      if (validRts.isNotEmpty) {
        validRts.sort();
        final median = validRts.length % 2 == 0
            ? ((validRts[validRts.length ~/ 2 - 1] + validRts[validRts.length ~/ 2]) / 2).round()
            : validRts[validRts.length ~/ 2];
        
        currentState = currentState.copyWith(rtP50: median);
      }
      
      updatedStates[wordId] = currentState;
    }
    
    return updatedStates;
  }

  /// 获取今日牌组（到期词 + 不熟词）
  /// 
  /// [allStates] 所有卡片状态
  /// [levels] 目标级别
  /// [onlyLeeches] 是否只包含不熟词
  /// 
  /// 返回需要复习的单词ID列表
  static List<int> getTodayDeck(
    Map<int, CardState> allStates,
    Set<String> levels,
    bool onlyLeeches,
  ) {
    final today = DateTime.now();
    final todayWordIds = <int>[];
    
    for (final state in allStates.values) {
      // 检查是否到期
      final isDue = state.due.isBefore(today) || 
                    state.due.isAtSameMomentAs(today);
      
      // 检查是否为不熟词
      final isLeech = state.isLeech;
      
      if (onlyLeeches) {
        // 只练不熟模式：只包含不熟词
        if (isLeech) {
          todayWordIds.add(state.wordId);
        }
      } else {
        // 正常模式：包含到期词和不熟词
        if (isDue || isLeech) {
          todayWordIds.add(state.wordId);
        }
      }
    }
    
    return todayWordIds;
  }

  /// 预测学习进度
  /// 
  /// [states] 卡片状态列表
  /// 
  /// 返回学习统计信息
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
    int masteredCards = 0; // 稳定度 >= 30天
    int dueToday = 0;
    int dueThisWeek = 0;
    
    double totalStability = 0;
    double totalDifficulty = 0;
    
    for (final state in states) {
      totalStability += state.stability;
      totalDifficulty += state.difficulty;
      
      if (state.stability >= 7) learnedCards++;
      if (state.stability >= 30) masteredCards++;
      
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
