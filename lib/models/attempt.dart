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

/// 答题发生在什么练习上下文中。
///
/// 会话内重测不能被当作独立的长期复习，否则同一轮重复答对会虚增
/// 长期掌握度。
@HiveType(typeId: 5)
enum AttemptKind {
  @HiveField(0)
  initial,
  @HiveField(1)
  inSessionRetry,
  @HiveField(2)
  scheduledReview,
  @HiveField(3)
  targetedPractice,
}

/// 答题质量与三元正误结果正交；例如慢答仍然是 correct。
enum ResponseQuality { fast, ordinary, slow, assisted, failed }

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

  /// 首次呈现、会话内重测或定向练习的来源。
  @HiveField(6)
  final AttemptKind kind;

  /// 看义拼词使用的最高提示等级；0 表示没有提示。
  @HiveField(7)
  final int highestHintLevel;

  const Attempt({
    required this.wordId,
    required this.result,
    required this.rtMs,
    required this.chosenIndex,
    required this.correctIndex,
    required this.timestamp,
    this.kind = AttemptKind.initial,
    this.highestHintLevel = 0,
  });

  factory Attempt.fromJson(Map<String, dynamic> json) =>
      _$AttemptFromJson(json);
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
    AttemptKind kind = AttemptKind.initial,
    int highestHintLevel = 0,
  }) => Attempt(
    wordId: wordId,
    result: AttemptResult.correct,
    rtMs: rtMs,
    chosenIndex: chosenIndex,
    correctIndex: correctIndex,
    timestamp: DateTime.now(),
    kind: kind,
    highestHintLevel: highestHintLevel,
  );

  /// 创建错误答题记录
  static Attempt wrong({
    required int wordId,
    required int rtMs,
    required int chosenIndex,
    required int correctIndex,
    AttemptKind kind = AttemptKind.initial,
    int highestHintLevel = 0,
  }) => Attempt(
    wordId: wordId,
    result: AttemptResult.wrong,
    rtMs: rtMs,
    chosenIndex: chosenIndex,
    correctIndex: correctIndex,
    timestamp: DateTime.now(),
    kind: kind,
    highestHintLevel: highestHintLevel,
  );

  /// 创建超时答题记录
  static Attempt timeout({
    required int wordId,
    required int correctIndex,
    AttemptKind kind = AttemptKind.initial,
    int highestHintLevel = 0,
  }) =>
      Attempt(
        wordId: wordId,
        result: AttemptResult.timeout,
        rtMs: 0,
        chosenIndex: -1,
        correctIndex: correctIndex,
        timestamp: DateTime.now(),
        kind: kind,
        highestHintLevel: highestHintLevel,
      );

  bool get usedHint => highestHintLevel > 0;

  bool get isInSessionRetry => kind == AttemptKind.inSessionRetry;

  Attempt copyWith({
    int? wordId,
    AttemptResult? result,
    int? rtMs,
    int? chosenIndex,
    int? correctIndex,
    DateTime? timestamp,
    AttemptKind? kind,
    int? highestHintLevel,
  }) => Attempt(
    wordId: wordId ?? this.wordId,
    result: result ?? this.result,
    rtMs: rtMs ?? this.rtMs,
    chosenIndex: chosenIndex ?? this.chosenIndex,
    correctIndex: correctIndex ?? this.correctIndex,
    timestamp: timestamp ?? this.timestamp,
    kind: kind ?? this.kind,
    highestHintLevel: highestHintLevel ?? this.highestHintLevel,
  );

  @override
  String toString() =>
      'Attempt(wordId: $wordId, result: $result, kind: $kind, rtMs: $rtMs)';
}
