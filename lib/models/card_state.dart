import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import '../domain/srs.dart';

part 'card_state.g.dart';

/// SRS卡片状态模型类
@HiveType(typeId: 2)
@JsonSerializable()
class CardState {
  static const int difficultFlag = 1;
  static const int manuallyKnownFlag = 1 << 1;
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

  /// 已完成的跨日成功复习次数。
  ///
  /// 即时重测不会增加这个值，避免只靠同一时段刷题就被判定为长期掌握。
  /// Hive 新增字段保持向后兼容，旧数据由适配器按稳定度提供迁移兜底。
  @HiveField(8)
  final int longTermReviews;

  /// 单调递增版本，用于防止重复提交或并发提交覆盖新的记忆状态。
  @HiveField(9)
  final int revision;

  const CardState({
    required this.wordId,
    required this.stability,
    required this.difficulty,
    required this.due,
    required this.lapses,
    required this.rtP50,
    required this.flags,
    required this.lastReview,
    this.longTermReviews = 0,
    this.revision = 0,
  });

  factory CardState.fromJson(Map<String, dynamic> json) =>
      _$CardStateFromJson(json);
  Map<String, dynamic> toJson() => _$CardStateToJson(this);

  /// 创建新卡片状态
  static CardState newCard(int wordId, {DateTime? now}) {
    final createdAt = now ?? DateTime.now();
    return CardState(
      wordId: wordId,
      stability: 1.5, // 初始稳定度（更保守，配合对数衰减增长）
      difficulty: 2.5, // 初始难度
      due: createdAt.add(const Duration(days: 1)), // 明天到期
      lapses: 0,
      rtP50: 0,
      flags: 0,
      lastReview: createdAt,
    );
  }

  /// 是否标记为疑难
  bool get isMarkedDifficult => (flags & difficultFlag) != 0;

  /// 用户自报“认识”的标记；它不增加独立回忆次数。
  bool get isManuallyKnown => (flags & manuallyKnownFlag) != 0;

  /// 是否到期（按自然日零点判定，当天即可进入到期复习）
  bool get isDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    return !today.isBefore(dueDay);
  }

  /// 指定基准时间判定是否到期
  bool isDueAt([DateTime? at]) {
    final ref = at ?? DateTime.now();
    final refDay = DateTime(ref.year, ref.month, ref.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    return !refDay.isBefore(dueDay);
  }

  /// 长期掌握需要稳定度和至少两次跨日成功回忆共同满足。
  bool get isMastered =>
      isManuallyKnown || (stability >= 16 && longTermReviews >= 2);

  bool get isVerifiedMastered =>
      !isManuallyKnown && stability >= 16 && longTermReviews >= 2;

  /// 使用指定策略判断是否为不熟单词（推荐用法）
  bool isLeechWith(LeechPolicy policy) => policy.isLeech(this);

  /// 是否为不熟单词（使用默认策略，兼容旧代码）
  bool get isLeech => const LeechPolicy().isLeech(this);

  /// 标记为疑难
  CardState markDifficult() =>
      copyWith(flags: flags | difficultFlag, revision: revision + 1);

  /// 取消疑难标记
  CardState unmarkDifficult() =>
      copyWith(flags: flags & ~difficultFlag, revision: revision + 1);

  /// 更新SRS参数
  CardState updateSRS({
    required double newStability,
    required double newDifficulty,
    required DateTime newDue,
    required int newRtP50,
    DateTime? reviewedAt,
    bool countsAsLongTermReview = false,
    bool increaselapses = false,
  }) => copyWith(
    stability: newStability,
    difficulty: newDifficulty,
    due: newDue,
    rtP50: newRtP50,
    lapses: increaselapses ? lapses + 1 : lapses,
    lastReview: reviewedAt ?? DateTime.now(),
    longTermReviews: countsAsLongTermReview
        ? longTermReviews + 1
        : longTermReviews,
    revision: revision + 1,
    clearManualKnown: true,
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
    int? longTermReviews,
    int? revision,
    bool clearManualKnown = false,
  }) => CardState(
    wordId: wordId ?? this.wordId,
    stability: stability ?? this.stability,
    difficulty: difficulty ?? this.difficulty,
    due: due ?? this.due,
    lapses: lapses ?? this.lapses,
    rtP50: rtP50 ?? this.rtP50,
    // 一次真实回忆会把“手动认识”降级为待验证状态；用户的疑难标记仍保留。
    flags: clearManualKnown
        ? (flags ?? this.flags) & ~manuallyKnownFlag
        : flags ?? this.flags,
    lastReview: lastReview ?? this.lastReview,
    longTermReviews: longTermReviews ?? this.longTermReviews,
    revision: revision ?? this.revision,
  );

  @override
  String toString() =>
      'CardState(wordId: $wordId, stability: $stability, difficulty: $difficulty, due: $due, lapses: $lapses, longTermReviews: $longTermReviews)';
}
