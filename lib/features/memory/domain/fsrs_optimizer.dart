import 'dart:math' as math;

import '../../../models/review_event.dart';
import 'fsrs_scheduler.dart';
import 'memory_replay.dart';

/// 一次参数拟合的结果。损失都是留出词上的对数损失（越低越准）。
class FsrsFitResult {
  final FsrsParameters parameters;
  final DateTime fittedAt;
  final int trainSamples;
  final int testSamples;
  final double defaultLoss;
  final double fittedLoss;

  /// 只用总体正确率当预测的损失；模型至少要比它好才有区分力。
  final double baselineLoss;

  const FsrsFitResult({
    required this.parameters,
    required this.fittedAt,
    required this.trainSamples,
    required this.testSamples,
    required this.defaultLoss,
    required this.fittedLoss,
    required this.baselineLoss,
  });

  /// 留出词上明显好于默认参数，且好于只猜总体正确率，才值得采用。
  bool get improves =>
      fittedLoss < defaultLoss - FsrsOptimizer.minGain &&
      fittedLoss < baselineLoss;

  Map<String, dynamic> toJson() => {
    'parameters': parameters.values,
    'fittedAt': fittedAt.toIso8601String(),
    'trainSamples': trainSamples,
    'testSamples': testSamples,
    'defaultLoss': defaultLoss,
    'fittedLoss': fittedLoss,
    'baselineLoss': baselineLoss,
  };

  factory FsrsFitResult.fromJson(Map<String, dynamic> json) => FsrsFitResult(
    parameters: FsrsParameters([
      for (final v in json['parameters'] as List) (v as num).toDouble(),
    ]),
    fittedAt: DateTime.parse(json['fittedAt'] as String),
    trainSamples: json['trainSamples'] as int,
    testSamples: json['testSamples'] as int,
    defaultLoss: (json['defaultLoss'] as num).toDouble(),
    fittedLoss: (json['fittedLoss'] as num).toDouble(),
    baselineLoss: (json['baselineLoss'] as num).toDouble(),
  );
}

/// 用历史作答拟合 FSRS 参数（坐标下降，无需梯度）。
///
/// 按词划分训练/留出集：同一个词的整条复习轨迹只出现在一边，留出集的
/// 损失才能反映对没见过的词的预测能力。纯函数，可放进后台 isolate。
class FsrsOptimizer {
  /// 跨日复习样本少于这个数时不拟合，避免对少量数据过拟合。
  static const minSamples = 200;

  /// 留出集损失至少要降低这么多才算有改进。
  static const minGain = 0.002;

  /// 每个参数的取值范围（FSRS v4 的 17 个参数）。
  static const _bounds = <(double, double)>[
    (0.05, 100), (0.05, 100), (0.05, 100), (0.05, 100), // 初始稳定性
    (1, 10), (0.1, 5), // 初始难度
    (0, 5), (0, 0.5), // 难度更新
    (0, 3), (0, 0.8), (0.01, 3), // 记住后稳定性增长
    (0.1, 5), (0.01, 0.5), (0.01, 0.9), (0.01, 3), // 遗忘后稳定性
    (0, 1), (1, 6), // 困难/容易系数
  ];

  static const _steps = [0.5, 0.8, 1.25, 2.0];

  final int passes;

  const FsrsOptimizer({this.passes = 3});

  static bool _isHoldout(int wordId) => wordId % 5 == 0;

  /// 样本不足时返回 null。
  FsrsFitResult? fit(List<ReviewEvent> events, {DateTime? now}) {
    final train = [
      for (final e in events)
        if (!_isHoldout(e.attempt.wordId)) e,
    ];
    final test = [
      for (final e in events)
        if (_isHoldout(e.attempt.wordId)) e,
    ];
    const defaults = FsrsParameters();
    final trainReport = _replay(train, defaults);
    final testReport = _replay(test, defaults);
    if (trainReport.samples.length < minSamples || testReport.samples.isEmpty) {
      return null;
    }

    var best = List<double>.of(defaults.values);
    var bestLoss = trainReport.fsrsLogLoss;
    for (var pass = 0; pass < passes; pass++) {
      var improved = false;
      for (var i = 0; i < best.length; i++) {
        final (low, high) = _bounds[i];
        for (final step in _steps) {
          // 接近 0 的参数乘法步长太小，额外按区间宽度做加法试探。
          final candidates = {
            (best[i] * step).clamp(low, high).toDouble(),
            (best[i] + (high - low) * (step - 1) * 0.05)
                .clamp(low, high)
                .toDouble(),
          };
          for (final value in candidates) {
            if (value == best[i]) continue;
            final trial = List<double>.of(best)..[i] = value;
            final loss = _replay(train, FsrsParameters(trial)).fsrsLogLoss;
            if (loss < bestLoss - 1e-6) {
              best = trial;
              bestLoss = loss;
              improved = true;
            }
          }
        }
      }
      if (!improved) break;
    }

    final fitted = FsrsParameters(List.unmodifiable(best));
    return FsrsFitResult(
      parameters: fitted,
      fittedAt: now ?? DateTime.now(),
      trainSamples: trainReport.samples.length,
      testSamples: testReport.samples.length,
      defaultLoss: testReport.fsrsLogLoss,
      fittedLoss: _replay(test, fitted).fsrsLogLoss,
      baselineLoss: testReport.baselineLogLoss,
    );
  }

  static ReplayReport _replay(
    List<ReviewEvent> events,
    FsrsParameters parameters,
  ) => MemoryReplay(fsrs: FsrsScheduler(parameters: parameters)).run(events);

  /// 用给定参数重放全部作答，估计每个词此刻的回忆概率（0~1）。
  static Map<int, double> recallEstimates(
    List<ReviewEvent> events,
    FsrsParameters parameters, {
    DateTime? at,
  }) {
    final scheduler = FsrsScheduler(parameters: parameters);
    final report = MemoryReplay(fsrs: scheduler).run(events);
    final time = at ?? DateTime.now();
    return {
      for (final entry in report.fsrsStates.entries)
        entry.key: math.min(
          1.0,
          math.max(0.0, scheduler.retrievability(entry.value, at: time)),
        ),
    };
  }
}
