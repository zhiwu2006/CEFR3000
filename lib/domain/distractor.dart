import 'dart:math';
import '../models/models.dart';

/// 干扰项生成服务
class DistractorService {
  final Random _random;

  DistractorService({int? seed}) : _random = Random(seed);

  /// 生成题目选项（1个正确答案 + 3个干扰项）
  ///
  /// [targetWord] 目标单词
  /// [candidatePool] 候选词库（用于生成干扰项）
  ///
  /// 返回：包含4个选项的列表和正确答案索引
  ({List<String> options, int correctIndex}) buildQuestion(
    Word targetWord,
    List<Word> candidatePool,
  ) {
    final correctAnswer = targetWord.primaryDefinition;
    final distractors = _generateDistractors(
      targetWord,
      candidatePool,
      correctAnswer,
    );

    // 组合选项并随机排序
    final allOptions = [correctAnswer, ...distractors];
    final shuffledOptions = _shuffleOptions(allOptions);
    final correctIndex = shuffledOptions.indexOf(correctAnswer);

    return (options: shuffledOptions, correctIndex: correctIndex);
  }

  /// 生成3个干扰项
  List<String> _generateDistractors(
    Word targetWord,
    List<Word> candidatePool,
    String correctAnswer,
  ) {
    final distractors = <String>[];

    // 策略1：同级别+同主要词性优先
    final sameLevelSamePos = candidatePool
        .where(
          (word) =>
              word.id != targetWord.id &&
              word.level == targetWord.level &&
              word.majorPos == targetWord.majorPos,
        )
        .toList();

    _addDistractorsFromPool(
      sameLevelSamePos,
      distractors,
      correctAnswer,
      targetWord,
      3,
      targetWord.cnDefs,
    );

    // 策略2：如果不足3个，从同级别任意词性补充
    if (distractors.length < 3) {
      final sameLevel = candidatePool
          .where(
            (word) =>
                word.id != targetWord.id &&
                word.level == targetWord.level &&
                !_isDefinitionUsed(word.primaryDefinition, distractors),
          )
          .toList();

      _addDistractorsFromPool(
        sameLevel,
        distractors,
        correctAnswer,
        targetWord,
        3 - distractors.length,
        targetWord.cnDefs,
      );
    }

    // 策略3：如果仍不足，从其他级别补充（跨级别扩展候选池）
    if (distractors.length < 3) {
      final otherWords = candidatePool
          .where(
            (word) =>
                word.id != targetWord.id &&
                !_isDefinitionUsed(word.primaryDefinition, distractors),
          )
          .toList();

      _addDistractorsFromPool(
        otherWords,
        distractors,
        correctAnswer,
        targetWord,
        3 - distractors.length,
        targetWord.cnDefs,
      );
    }

    // 兜底：如果仍不足3个，尝试从整个词库或占位符补足
    if (distractors.length < 3) {
      final used = {...distractors, correctAnswer};
      for (final word in candidatePool) {
        if (distractors.length >= 3) break;
        final def = word.primaryDefinition;
        if (!used.contains(def)) {
          distractors.add(def);
          used.add(def);
        }
      }
      int placeholderIndex = 1;
      while (distractors.length < 3) {
        final placeholder = '其他选项$placeholderIndex';
        if (!used.contains(placeholder)) {
          distractors.add(placeholder);
          used.add(placeholder);
        }
        placeholderIndex++;
      }
    }

    return distractors.take(3).toList();
  }

  /// 从词池中添加干扰项
  void _addDistractorsFromPool(
    List<Word> pool,
    List<String> distractors,
    String correctAnswer,
    Word targetWord,
    int needed,
    List<String> targetAllDefs,
  ) {
    if (pool.isEmpty || needed <= 0) return;

    // 随机打乱词池
    final shuffledPool = List<Word>.from(pool)..shuffle(_random);

    for (final word in shuffledPool) {
      if (distractors.length >= needed) break;

      // 如果候选词的任何一个释义，出现在目标词的释义中，则排除
      if (word.cnDefs.any((def) => targetAllDefs.contains(def))) {
        continue;
      }

      final definition = word.primaryDefinition;

      // 检查是否与正确答案相同、包含或已使用
      // 增加对正确答案的近义词检测：如果干扰项包含正确答案（或反之），跳过
      bool hasConflict = false;
      for (final targetDef in targetAllDefs) {
        if (definition == targetDef ||
            definition.contains(targetDef) ||
            targetDef.contains(definition)) {
          hasConflict = true;
          break;
        }
      }

      if (!hasConflict && !_isDefinitionUsed(definition, distractors)) {
        distractors.add(definition);
      }
    }
  }

  /// 检查释义是否已被使用或是否存在语义冲突
  bool _isDefinitionUsed(String definition, List<String> usedDefinitions) {
    if (usedDefinitions.contains(definition)) return true;

    // 简单的语义冲突检测：防止近义词“撞车”
    // 如果新选项包含已有选项（或反之），视为冲突
    // 例如：Target="建造", Option="建造/建立" -> 冲突
    for (final used in usedDefinitions) {
      if (used.contains(definition) || definition.contains(used)) {
        return true;
      }
    }
    return false;
  }

  /// 随机打乱选项顺序
  List<String> _shuffleOptions(List<String> options) {
    final shuffled = List<String>.from(options);
    shuffled.shuffle(_random);
    return shuffled;
  }

  /// 评估干扰项质量（用于后续优化）
  double evaluateDistractorQuality(
    Word targetWord,
    List<String> distractors,
    List<Word> candidatePool,
  ) {
    double score = 0.0;

    for (final distractor in distractors) {
      // 查找对应的单词
      final distractorWord = candidatePool.firstWhere(
        (word) => word.primaryDefinition == distractor,
        orElse: () => Word(
          id: -1,
          headword: '',
          lemma: '',
          level: '',
          pos: '',
          cnDefs: [distractor],
        ),
      );

      if (distractorWord.id == -1) {
        // 占位符，质量较低
        score += 0.1;
        continue;
      }

      // 同级别加分
      if (distractorWord.level == targetWord.level) {
        score += 0.3;
      }

      // 同词性加分
      if (distractorWord.majorPos == targetWord.majorPos) {
        score += 0.2;
      }

      // 基础分
      score += 0.5;
    }

    return score / distractors.length; // 平均分
  }

  /// 批量生成题目（用于提前生成大量题目）
  List<({List<String> options, int correctIndex})> batchBuildQuestions(
    List<Word> targetWords,
    List<Word> candidatePool,
  ) {
    final results = <({List<String> options, int correctIndex})>[];

    for (final word in targetWords) {
      results.add(buildQuestion(word, candidatePool));
    }

    return results;
  }
}
