import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'card_state.g.dart';

/// SRS卡片状态模型类
@HiveType(typeId: 2)
@JsonSerializable()
class CardState {
  @HiveField(0)
  final int wordId;

  @HiveField(1)
  final double stability; // 稳定度

  @HiveField(2)
  final double difficulty; // 难度

  @HiveField(3)
  final DateTime due; // 到期日期

  @HiveField(4)
  final int lapses; // 失忆次数

  @HiveField(5)
  final int rtP50; // 反应时间中位数（毫秒）

  @HiveField(6)
  final int flags; // 标记位集合

  @HiveField(7)
  final DateTime lastReview; // 最后复习时间

  const CardState({
    required this.wordId,
    required this.stability,
    required this.difficulty,
    required this.due,
    required this.lapses,
    required this.rtP50,
    required this.flags,
    required this.lastReview,
  });

  factory CardState.fromJson(Map<String, dynamic> json) => _$CardStateFromJson(json);
  Map<String, dynamic> toJson() => _$CardStateToJson(this);

  /// 创建新卡片状态
  static CardState newCard(int wordId) => CardState(
        wordId: wordId,
        stability: 2.5, // 初始稳定度
        difficulty: 2.5, // 初始难度
        due: DateTime.now().add(const Duration(days: 1)), // 明天到期
        lapses: 0,
        rtP50: 0,
        flags: 0,
        lastReview: DateTime.now(),
      );

  /// 是否标记为疑难
  bool get isMarkedDifficult => (flags & 1) != 0;

  static int leechLapsesThreshold = 2;
  static bool leechIncludeMarked = true;

  static void updateLeechPolicy({
    int? lapsesThreshold,
    bool? includeMarked,
  }) {
    if (lapsesThreshold != null && lapsesThreshold > 0) {
      leechLapsesThreshold = lapsesThreshold;
    }
    if (includeMarked != null) {
      leechIncludeMarked = includeMarked;
    }
  }

  /// 是否到期
  bool get isDue => DateTime.now().isAfter(due) || DateTime.now().isAtSameMomentAs(due);

  /// 是否为不熟单词（失忆次数达到阈值或标记疑难）
  bool get isLeech => lapses >= leechLapsesThreshold || (leechIncludeMarked && isMarkedDifficult);

  /// 标记为疑难
  CardState markDifficult() => copyWith(flags: flags | 1);

  /// 取消疑难标记
  CardState unmarkDifficult() => copyWith(flags: flags & ~1);

  /// 更新SRS参数
  CardState updateSRS({
    required double newStability,
    required double newDifficulty,
    required DateTime newDue,
    required int newRtP50,
    bool increaselapses = false,
  }) =>
      copyWith(
        stability: newStability,
        difficulty: newDifficulty,
        due: newDue,
        rtP50: newRtP50,
        lapses: increaselapses ? lapses + 1 : lapses,
        lastReview: DateTime.now(),
      );

  /// 复制并修改指定字段
  CardState copyWith({
    int? wordId,
    double? stability,
    double? difficulty,
    DateTime? due,
    int? lapses,
    int? rtP50,
    int? flags,
    DateTime? lastReview,
  }) =>
      CardState(
        wordId: wordId ?? this.wordId,
        stability: stability ?? this.stability,
        difficulty: difficulty ?? this.difficulty,
        due: due ?? this.due,
        lapses: lapses ?? this.lapses,
        rtP50: rtP50 ?? this.rtP50,
        flags: flags ?? this.flags,
        lastReview: lastReview ?? this.lastReview,
      );

  @override
  String toString() => 'CardState(wordId: $wordId, stability: $stability, difficulty: $difficulty, due: $due, lapses: $lapses)';
}
