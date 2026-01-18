import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'attempt.dart';

part 'test_run.g.dart';

/// 测试会话记录模型类
@HiveType(typeId: 3)
@JsonSerializable()
class TestRun {
  @HiveField(0)
  final String id; // UUID

  @HiveField(1)
  final DateTime startedAt;

  @HiveField(2)
  final DateTime? finishedAt;

  @HiveField(3)
  final int size; // 计划题目数量

  @HiveField(4)
  final List<String> levels; // 参与的级别

  @HiveField(5)
  final int timeLimitMs; // 时间限制（毫秒）

  @HiveField(6)
  final double? accuracy; // 准确率

  @HiveField(7)
  final int? avgRtMs; // 平均反应时间

  @HiveField(8)
  final List<Attempt> attempts; // 答题记录列表

  @HiveField(9)
  final String orderPolicy; // 排序策略

  @HiveField(10)
  final bool onlyLeeches; // 是否只练不熟

  const TestRun({
    required this.id,
    required this.startedAt,
    this.finishedAt,
    required this.size,
    required this.levels,
    required this.timeLimitMs,
    this.accuracy,
    this.avgRtMs,
    required this.attempts,
    required this.orderPolicy,
    required this.onlyLeeches,
  });

  factory TestRun.fromJson(Map<String, dynamic> json) => _$TestRunFromJson(json);
  Map<String, dynamic> toJson() => _$TestRunToJson(this);

  /// 创建新的测试会话
  static TestRun create({
    required String id,
    required int size,
    required Set<String> levels,
    required int timeLimitMs,
    required String orderPolicy,
    required bool onlyLeeches,
  }) =>
      TestRun(
        id: id,
        startedAt: DateTime.now(),
        size: size,
        levels: levels.toList(),
        timeLimitMs: timeLimitMs,
        attempts: [],
        orderPolicy: orderPolicy,
        onlyLeeches: onlyLeeches,
      );

  /// 是否已完成
  bool get isFinished => finishedAt != null;

  /// 当前进度
  int get currentProgress => attempts.length;

  /// 计算准确率
  double calculateAccuracy() {
    if (attempts.isEmpty) return 0.0;
    final correctCount = attempts.where((a) => a.isCorrect).length;
    return correctCount / attempts.length;
  }

  /// 计算平均反应时间
  int calculateAvgRt() {
    if (attempts.isEmpty) return 0;
    final validAttempts = attempts.where((a) => !a.isTimeout);
    if (validAttempts.isEmpty) return 0;
    final totalRt = validAttempts.map((a) => a.rtMs).reduce((a, b) => a + b);
    return (totalRt / validAttempts.length).round();
  }

  /// 计算中位反应时间
  int calculateMedianRt() {
    if (attempts.isEmpty) return 0;
    final validRts = attempts.where((a) => !a.isTimeout).map((a) => a.rtMs).toList();
    if (validRts.isEmpty) return 0;
    validRts.sort();
    final middle = validRts.length ~/ 2;
    if (validRts.length % 2 == 0) {
      return ((validRts[middle - 1] + validRts[middle]) / 2).round();
    } else {
      return validRts[middle];
    }
  }

  /// 获取错题列表
  List<Attempt> get wrongAttempts => attempts.where((a) => a.isWrong || a.isTimeout).toList();

  /// 获取勉强正确的题目（正确但反应时间过长）
  List<Attempt> getSlowCorrectAttempts(double slowThreshold) {
    return attempts.where((a) => a.isCorrect && a.rtMs > timeLimitMs * slowThreshold).toList();
  }

  /// 添加答题记录
  TestRun addAttempt(Attempt attempt) => copyWith(
        attempts: [...attempts, attempt],
      );

  /// 完成测试
  TestRun finish() => copyWith(
        finishedAt: DateTime.now(),
        accuracy: calculateAccuracy(),
        avgRtMs: calculateAvgRt(),
      );

  /// 复制并修改指定字段
  TestRun copyWith({
    String? id,
    DateTime? startedAt,
    DateTime? finishedAt,
    int? size,
    Set<String>? levels,
    int? timeLimitMs,
    double? accuracy,
    int? avgRtMs,
    List<Attempt>? attempts,
    String? orderPolicy,
    bool? onlyLeeches,
  }) =>
      TestRun(
        id: id ?? this.id,
        startedAt: startedAt ?? this.startedAt,
        finishedAt: finishedAt ?? this.finishedAt,
        size: size ?? this.size,
        levels: levels?.toList() ?? this.levels,
        timeLimitMs: timeLimitMs ?? this.timeLimitMs,
        accuracy: accuracy ?? this.accuracy,
        avgRtMs: avgRtMs ?? this.avgRtMs,
        attempts: attempts ?? this.attempts,
        orderPolicy: orderPolicy ?? this.orderPolicy,
        onlyLeeches: onlyLeeches ?? this.onlyLeeches,
      );

  @override
  String toString() => 'TestRun(id: $id, size: $size, progress: $currentProgress, accuracy: ${accuracy?.toStringAsFixed(2)})';
}