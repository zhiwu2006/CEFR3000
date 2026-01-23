import 'dart:math';
import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// 测试集生成器
class TestSetGenerator {
  final Random _random;

  TestSetGenerator({int? seed}) : _random = Random(seed);

  /// 生成测试集
  /// 
  /// [allWords] 所有可用单词
  /// [levels] 目标级别
  /// [size] 题目数量
  /// [orderPolicy] 排序策略：'by_level' 或 'random'
  /// [onlyLeeches] 是否只练不熟
  /// [leechWords] 不熟单词列表（当onlyLeeches为true时使用）
  /// [dueWords] 到期单词列表
  /// 
  /// 返回选中的单词列表
  List<Word> generateTestSet({
    required List<Word> allWords,
    required Set<String> levels,
    required int size,
    required String orderPolicy,
    bool onlyLeeches = false,
    List<Word>? leechWords,
    List<Word>? dueWords,
  }) {
    debugPrint('=== TestSetGenerator.generateTestSet ===');
    debugPrint('All words: ${allWords.length}');
    debugPrint('Target levels: $levels');
    debugPrint('Target size: $size');
    debugPrint('Order policy: $orderPolicy');
    debugPrint('Only leeches: $onlyLeeches');
    debugPrint('Leech words: ${leechWords?.length}');
    debugPrint('Due words: ${dueWords?.length}');
    
    List<Word> candidateWords;

    if (onlyLeeches && leechWords != null && leechWords.isNotEmpty) {
      // 只练不熟模式
      candidateWords = leechWords
          .where((word) => levels.contains(word.level))
          .toList();
      debugPrint('Leech candidate words: ${candidateWords.length}');
    } else {
      // 正常模式：优先到期词，然后新词
      candidateWords = _selectCandidateWords(
        allWords: allWords,
        levels: levels,
        dueWords: dueWords ?? [],
        targetSize: size,
      );
      debugPrint('Normal mode candidate words: ${candidateWords.length}');
    }

    // 确保有足够的候选词
    if (candidateWords.isEmpty) {
      // 如果没有候选词，从所有符合级别的词中选择
      candidateWords = allWords
          .where((word) => levels.contains(word.level))
          .toList();
      debugPrint('Fallback to all level words: ${candidateWords.length}');
    }
    
    // 检查是否有足够的单词
    if (candidateWords.length < size) {
      debugPrint('WARNING: Not enough words available!');
      debugPrint('Requested: $size words, Available: ${candidateWords.length} words');
      debugPrint('Available levels: ${candidateWords.map((w) => w.level).toSet()}');
      
      // 建议用户选择更多级别
      final availableLevels = allWords.map((w) => w.level).toSet();
      final missingLevels = availableLevels.difference(levels);
      if (missingLevels.isNotEmpty) {
        debugPrint('建议选择更多级别: $missingLevels');
      }
    }

    // 应用排序策略
    List<Word> orderedWords;
    switch (orderPolicy) {
      case 'by_level':
        orderedWords = _orderByLevel(candidateWords);
        break;
      case 'random':
        orderedWords = _orderRandomly(candidateWords);
        break;
      default:
        orderedWords = _orderByLevel(candidateWords);
    }
    
    debugPrint('Ordered words: ${orderedWords.length}');

    // 选择指定数量的词（如果不够就全部选择）
    final actualSize = min(size, orderedWords.length);
    final result = orderedWords.take(actualSize).toList();
    
    debugPrint('Final test set size: ${result.length} (requested: $size)');
    debugPrint('Final test set: ${result.map((w) => '${w.headword}(${w.level})').take(10).toList()}');
    
    return result;
  }

  /// 选择候选词（优先级：到期词 > 不熟词 > 新词）
  List<Word> _selectCandidateWords({
    required List<Word> allWords,
    required Set<String> levels,
    required List<Word> dueWords,
    required int targetSize,
  }) {
    final candidates = <Word>[];
    final usedIds = <int>{};
    
    debugPrint('=== _selectCandidateWords ===');
    debugPrint('All words: ${allWords.length}');
    debugPrint('Due words: ${dueWords.length}');
    debugPrint('Target size: $targetSize');

    // 1. 添加到期词
    for (final word in dueWords) {
      if (levels.contains(word.level) && 
          candidates.length < targetSize && 
          !usedIds.contains(word.id)) {
        candidates.add(word);
        usedIds.add(word.id);
      }
    }
    
    debugPrint('After adding due words: ${candidates.length}');

    // 2. 如果还需要更多词，从所有符合级别的词中随机选择
    if (candidates.length < targetSize) {
      final remainingWords = allWords
          .where((word) => 
              levels.contains(word.level) && 
              !usedIds.contains(word.id))
          .toList();
      
      debugPrint('Remaining words available: ${remainingWords.length}');

      remainingWords.shuffle(_random);
      
      final needed = targetSize - candidates.length;
      final toAdd = remainingWords.take(needed);
      candidates.addAll(toAdd);
      
      debugPrint('Added ${toAdd.length} additional words');
    }
    
    debugPrint('Final candidates: ${candidates.length}');
    return candidates;
  }

  /// 按级别排序（A1 -> A2 -> B1 -> B2，级内随机）
  List<Word> _orderByLevel(List<Word> words) {
    final levelOrder = ['A1', 'A2', 'B1', 'B2'];
    final grouped = <String, List<Word>>{};

    // 按级别分组
    for (final word in words) {
      grouped.putIfAbsent(word.level, () => []).add(word);
    }

    // 按级别顺序组合，级内随机
    final result = <Word>[];
    for (final level in levelOrder) {
      if (grouped.containsKey(level)) {
        final levelWords = grouped[level]!;
        levelWords.shuffle(_random);
        result.addAll(levelWords);
      }
    }

    return result;
  }

  /// 随机排序
  List<Word> _orderRandomly(List<Word> words) {
    final shuffled = List<Word>.from(words);
    shuffled.shuffle(_random);
    return shuffled;
  }

  /// 生成每日推荐牌组
  /// 
  /// [allStates] 所有卡片状态
  /// [allWords] 所有单词
  /// [levels] 目标级别
  /// [maxNewWords] 最大新词数量
  /// 
  /// 返回推荐的单词列表
  List<Word> generateDailyDeck({
    required Map<int, CardState> allStates,
    required List<Word> allWords,
    required Set<String> levels,
    int maxNewWords = 20,
  }) {
    final deckWords = <Word>[];
    final usedIds = <int>{};

    // 1. 添加到期的复习词
    for (final state in allStates.values) {
      if (state.isDue) {
        final word = allWords.firstWhere(
          (w) => w.id == state.wordId,
          orElse: () => allWords.first, // 这不应该发生
        );
        
        if (levels.contains(word.level) && !usedIds.contains(word.id)) {
          deckWords.add(word);
          usedIds.add(word.id);
        }
      }
    }

    // 2. 添加不熟词（失忆次数>=2或标记疑难）
    for (final state in allStates.values) {
      if (state.isLeech && !usedIds.contains(state.wordId)) {
        final word = allWords.firstWhere(
          (w) => w.id == state.wordId,
          orElse: () => allWords.first,
        );
        
        if (levels.contains(word.level)) {
          deckWords.add(word);
          usedIds.add(word.id);
        }
      }
    }

    // 3. 添加新词（未学过的），但限制数量
    final learnedIds = allStates.keys.toSet();
    final newWords = allWords
        .where((word) => 
            levels.contains(word.level) && 
            !learnedIds.contains(word.id) &&
            !usedIds.contains(word.id))
        .toList();

    newWords.shuffle(_random);
    deckWords.addAll(newWords.take(maxNewWords));

    return deckWords;
  }

  /// 验证测试集质量
  /// 
  /// [testSet] 测试集
  /// [candidatePool] 候选词池
  /// 
  /// 返回质量评估结果
  Map<String, dynamic> validateTestSetQuality(
    List<Word> testSet,
    List<Word> candidatePool,
  ) {
    if (testSet.isEmpty) {
      return {
        'isValid': false,
        'reason': 'Empty test set',
        'levelDistribution': <String, int>{},
        'posDistribution': <String, int>{},
        'avgDistractorPoolSize': 0.0,
      };
    }

    // 级别分布
    final levelDist = <String, int>{};
    for (final word in testSet) {
      levelDist[word.level] = (levelDist[word.level] ?? 0) + 1;
    }

    // 词性分布
    final posDist = <String, int>{};
    for (final word in testSet) {
      posDist[word.majorPos] = (posDist[word.majorPos] ?? 0) + 1;
    }

    // 检查每个词的干扰项池大小
    double totalDistractorPoolSize = 0;
    for (final word in testSet) {
      final sameLevelSamePos = candidatePool
          .where((w) => 
              w.id != word.id &&
              w.level == word.level &&
              w.majorPos == word.majorPos)
          .length;
      totalDistractorPoolSize += sameLevelSamePos;
    }

    final avgDistractorPoolSize = totalDistractorPoolSize / testSet.length;

    return {
      'isValid': avgDistractorPoolSize >= 3, // 至少能生成3个干扰项
      'levelDistribution': levelDist,
      'posDistribution': posDist,
      'avgDistractorPoolSize': avgDistractorPoolSize,
      'totalWords': testSet.length,
      'uniqueWords': testSet.map((w) => w.id).toSet().length,
    };
  }

  /// 重新排序现有测试集
  /// 
  /// [testSet] 原测试集
  /// [orderPolicy] 新的排序策略
  /// 
  /// 返回重排序后的测试集
  List<Word> reorderTestSet(List<Word> testSet, String orderPolicy) {
    switch (orderPolicy) {
      case 'by_level':
        return _orderByLevel(testSet);
      case 'random':
        return _orderRandomly(testSet);
      default:
        return testSet;
    }
  }

  /// 获取测试集统计信息
  Map<String, dynamic> getTestSetStatistics(List<Word> testSet) {
    if (testSet.isEmpty) {
      return {
        'totalWords': 0,
        'levelCounts': <String, int>{},
        'posCounts': <String, int>{},
        'avgDefinitionsPerWord': 0.0,
      };
    }

    final levelCounts = <String, int>{};
    final posCounts = <String, int>{};
    int totalDefinitions = 0;

    for (final word in testSet) {
      levelCounts[word.level] = (levelCounts[word.level] ?? 0) + 1;
      posCounts[word.majorPos] = (posCounts[word.majorPos] ?? 0) + 1;
      totalDefinitions += word.cnDefs.length;
    }

    return {
      'totalWords': testSet.length,
      'levelCounts': levelCounts,
      'posCounts': posCounts,
      'avgDefinitionsPerWord': totalDefinitions / testSet.length,
    };
  }
}
