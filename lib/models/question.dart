import 'word.dart';

/// 测试题目模型类
class Question {
  final Word word;
  final List<String> options; // 长度固定为4的选项列表
  final int correctIndex; // 正确答案在options中的索引

  Question({
    required this.word,
    required this.options,
    required this.correctIndex,
  }) {
    if (options.length != 4) {
      throw ArgumentError.value(
        options.length,
        'options.length',
        'Options must have exactly 4 items',
      );
    }
    if (correctIndex < 0 || correctIndex >= options.length) {
      throw RangeError.range(
        correctIndex,
        0,
        options.length - 1,
        'correctIndex',
        'Correct index must be within options range',
      );
    }
  }

  /// 获取正确答案
  String get correctAnswer => options[correctIndex];

  /// 检查用户选择是否正确
  bool isCorrect(int selectedIndex) => selectedIndex == correctIndex;

  /// 获取干扰项（不包括正确答案）
  List<String> get distractors {
    final result = <String>[];
    for (int i = 0; i < options.length; i++) {
      if (i != correctIndex) {
        result.add(options[i]);
      }
    }
    return result;
  }

  @override
  String toString() =>
      'Question(word: ${word.headword}, options: $options, correctIndex: $correctIndex)';
}
