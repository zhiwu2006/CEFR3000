import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'attempt.g.dart';

/// 答题结果枚举
@HiveType(typeId: 4)
enum AttemptResult {
  @HiveField(0)
  correct,
  @HiveField(1)
  wrong,
  @HiveField(2)
  timeout,
}

/// 答题记录模型类
@HiveType(typeId: 1)
@JsonSerializable()
class Attempt {
  @HiveField(0)
  final int wordId;

  @HiveField(1)
  final AttemptResult result;

  @HiveField(2)
  final int rtMs; // 反应时间（毫秒）

  @HiveField(3)
  final int chosenIndex; // 用户选择的选项索引，-1表示超时

  @HiveField(4)
  final int correctIndex; // 正确答案索引

  @HiveField(5)
  final DateTime timestamp;

  const Attempt({
    required this.wordId,
    required this.result,
    required this.rtMs,
    required this.chosenIndex,
    required this.correctIndex,
    required this.timestamp,
  });

  factory Attempt.fromJson(Map<String, dynamic> json) => _$AttemptFromJson(json);
  Map<String, dynamic> toJson() => _$AttemptToJson(this);

  /// 是否正确
  bool get isCorrect => result == AttemptResult.correct;

  /// 是否错误
  bool get isWrong => result == AttemptResult.wrong;

  /// 是否超时
  bool get isTimeout => result == AttemptResult.timeout;

  /// 创建正确答题记录
  static Attempt correct({
    required int wordId,
    required int rtMs,
    required int chosenIndex,
    required int correctIndex,
  }) =>
      Attempt(
        wordId: wordId,
        result: AttemptResult.correct,
        rtMs: rtMs,
        chosenIndex: chosenIndex,
        correctIndex: correctIndex,
        timestamp: DateTime.now(),
      );

  /// 创建错误答题记录
  static Attempt wrong({
    required int wordId,
    required int rtMs,
    required int chosenIndex,
    required int correctIndex,
  }) =>
      Attempt(
        wordId: wordId,
        result: AttemptResult.wrong,
        rtMs: rtMs,
        chosenIndex: chosenIndex,
        correctIndex: correctIndex,
        timestamp: DateTime.now(),
      );

  /// 创建超时答题记录
  static Attempt timeout({
    required int wordId,
    required int correctIndex,
  }) =>
      Attempt(
        wordId: wordId,
        result: AttemptResult.timeout,
        rtMs: 0,
        chosenIndex: -1,
        correctIndex: correctIndex,
        timestamp: DateTime.now(),
      );

  @override
  String toString() => 'Attempt(wordId: $wordId, result: $result, rtMs: $rtMs)';
}