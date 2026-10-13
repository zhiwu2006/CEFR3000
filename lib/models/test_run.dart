import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'attempt.dart';

part 'test_run.g.dart';

/// 测试会话记录模型类
@HiveType(typeId: 3)
@JsonSerializable(explicitToJson: true)
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

  /// 本轮结束仍需巩固的词；旧记录默认空集合。
  @HiveField(11, defaultValue: <int>[])
  final List<int> unresolvedWordIds;

  /// 恢复待巩固集合时回看的最近轮数上限。
  ///
  /// [pendingConsolidation] 对每个词只取「最近一次出现」所在的那一轮，因此
  /// 覆盖全部历史并无必要。调用方原先传 100000，会把每条 TestRun（含全部
  /// attempts）都反序列化进内存，历史越长启动与建计划越慢。改为固定回看窗口后，
  /// 只有窗口内再未出现过的词会失去「待巩固」标记——而这些词本就已经很久没被
  /// 重新触及，与「已巩固」的语义一致。
  static const int pendingConsolidationLookbackRuns = 200;

  /// 按每个词最近一轮的结果恢复待巩固集合（支持跨重启）。
  static Set<int> pendingConsolidation(Iterable<TestRun> runs) {
    final ordered = runs.where((run) => run.isFinished).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final seen = <int>{};
    final pending = <int>{};
    for (final run in ordered) {
      final unresolved = run.unresolvedWordIds.toSet();
      for (final id in {...run.attempts.map((a) => a.wordId), ...unresolved}) {
        if (seen.add(id) && unresolved.contains(id)) pending.add(id);
      }
    }
    return pending;
  }

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
    this.unresolvedWordIds = const [],
  });

  factory TestRun.fromJson(Map<String, dynamic> json) =>
      _$TestRunFromJson(json);
  Map<String, dynamic> toJson() => _$TestRunToJson(this);

  /// 创建新的测试会话
  static TestRun create({
    required String id,
    required int size,
    required Set<String> levels,
    required int timeLimitMs,
    required String orderPolicy,
    required bool onlyLeeches,
  }) => TestRun(
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

  /// 每个单词第一次作答的记录；会话内重测不重复计入。
  List<Attempt> get firstAttempts {
    final firstByWord = <int, Attempt>{};
    for (final attempt in attempts) {
      firstByWord.putIfAbsent(attempt.wordId, () => attempt);
    }
    return firstByWord.values.toList(growable: false);
  }

  /// 计算准确率
  double calculateAccuracy() {
    if (attempts.isEmpty) return 0.0;
    final correctCount = attempts.where((a) => a.isCorrect).length;
    return correctCount / attempts.length;
  }

  Set<int> get firstWrongWordIds => firstAttempts
      .where((attempt) => attempt.isWrong || attempt.isTimeout)
      .map((attempt) => attempt.wordId)
      .toSet();

  Set<int> get correctedWordIds {
    final firstByWord = <int, Attempt>{};
    for (final attempt in attempts) {
      firstByWord.putIfAbsent(attempt.wordId, () => attempt);
    }
    return firstWrongWordIds
        .where(
          (wordId) => attempts.any(
            (attempt) =>
                attempt.wordId == wordId &&
                !identical(attempt, firstByWord[wordId]) &&
                attempt.isCorrect &&
                !attempt.usedHint,
          ),
        )
        .toSet();
  }

  double get correctionSuccessRate => firstWrongWordIds.isEmpty
      ? 0.0
      : correctedWordIds.length / firstWrongWordIds.length;

  /// 计算平均反应时间
  int calculateAvgRt() {
    if (attempts.isEmpty) return 0;
    final validAttempts = attempts.where((a) => !a.isTimeout);
    if (validAttempts.isEmpty) return 0;
    final totalRt = validAttempts.map((a) => a.rtMs).reduce((a, b) => a + b);
    return (totalRt / validAttempts.length).round();
  }

  /// 获取错题列表
  List<Attempt> get wrongAttempts =>
      attempts.where((a) => a.isWrong || a.isTimeout).toList();

  /// 添加答题记录
  TestRun addAttempt(Attempt attempt) =>
      copyWith(attempts: [...attempts, attempt]);

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
    List<int>? unresolvedWordIds,
  }) => TestRun(
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
    unresolvedWordIds: unresolvedWordIds ?? this.unresolvedWordIds,
  );

  @override
  String toString() =>
      'TestRun(id: $id, size: $size, progress: $currentProgress, accuracy: ${accuracy?.toStringAsFixed(2)})';
}
