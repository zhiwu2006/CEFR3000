import 'dart:math' as math;

import '../../../models/card_state.dart';
import 'recall_models.dart';

/// A versioned FSRS v4 reference adapter used for shadow scheduling.
///
/// The production scheduler remains `MemoryScheduler` until enough local
/// events have been collected. Keeping the candidate deterministic makes it
/// possible to compare future due dates without changing a learner's queue.
class FsrsParameters {
  final List<double> values;

  const FsrsParameters([
    this.values = const [
      0.4,
      0.6,
      2.4,
      5.8,
      4.93,
      0.94,
      0.86,
      0.01,
      1.49,
      0.14,
      0.94,
      2.18,
      0.05,
      0.34,
      1.26,
      0.29,
      2.61,
    ],
  ]);

  double operator [](int index) => values[index];
}

class FsrsShadowResult {
  final CardState state;
  final double retrievability;
  final int grade;
  final String schedulerVersion;

  const FsrsShadowResult({
    required this.state,
    required this.retrievability,
    required this.grade,
    required this.schedulerVersion,
  });
}

/// Pure candidate scheduler. It never performs I/O and never changes the
/// active scheduler's state.
class FsrsScheduler {
  static const String version = 'fsrs-v4-reference';
  final FsrsParameters parameters;
  final double desiredRetention;
  final int maxIntervalDays;

  const FsrsScheduler({
    this.parameters = const FsrsParameters(),
    this.desiredRetention = 0.9,
    this.maxIntervalDays = 365,
  });

  FsrsShadowResult schedule(
    CardState current,
    RecallEvidence evidence, {
    DateTime? reviewedAt,
  }) {
    final grade = _grade(evidence.rating);
    final reviewTime = reviewedAt ?? evidence.occurredAt;
    final isNew = current.revision == 0 && current.longTermReviews == 0;
    final currentStability = math.max(0.1, current.stability);
    final currentDifficulty = _toFsrsDifficulty(current.difficulty);
    final elapsedDays = math.max(
      0.0,
      reviewTime.difference(current.lastReview).inMilliseconds /
          Duration.millisecondsPerDay,
    );
    final retrievability = isNew
        ? 1.0
        : _retrievability(elapsedDays, currentStability);
    final difficulty = isNew
        ? _initialDifficulty(grade)
        : _nextDifficulty(currentDifficulty, grade);
    final stability = isNew
        ? _initialStability(grade)
        : grade == 1
        ? _forgettingStability(currentStability, difficulty, retrievability)
        : _recallStability(currentStability, difficulty, retrievability, grade);
    final safeStability = math.max(0.1, stability);
    final intervalDays = _nextInterval(safeStability);
    final next = current.updateSRS(
      newStability: safeStability,
      newDifficulty: _fromFsrsDifficulty(difficulty),
      newDue: reviewTime.add(Duration(days: intervalDays)),
      newRtP50: current.rtP50,
      reviewedAt: reviewTime,
      countsAsLongTermReview:
          evidence.isIndependentRecall && evidence.isDueReview && grade >= 3,
      increaselapses: grade == 1,
    );
    return FsrsShadowResult(
      state: next,
      retrievability: retrievability,
      grade: grade,
      schedulerVersion: version,
    );
  }

  double retrievability(CardState state, {DateTime? at}) {
    final time = at ?? DateTime.now();
    final elapsedDays = math.max(
      0.0,
      time.difference(state.lastReview).inMilliseconds /
          Duration.millisecondsPerDay,
    );
    return _retrievability(elapsedDays, math.max(0.1, state.stability));
  }

  int _grade(RecallRating rating) => switch (rating) {
    RecallRating.forgot => 1,
    RecallRating.difficult => 2,
    RecallRating.recalled => 3,
    RecallRating.easy => 4,
  };

  double _initialStability(int grade) =>
      parameters[grade - 1].clamp(0.1, 365.0);

  double _initialDifficulty(int grade) =>
      (parameters[4] - (grade - 3) * parameters[5]).clamp(1.0, 10.0);

  double _nextDifficulty(double difficulty, int grade) {
    final target = _initialDifficulty(3);
    final value =
        parameters[7] * target +
        (1 - parameters[7]) * (difficulty - parameters[6] * (grade - 3));
    return value.clamp(1.0, 10.0);
  }

  double _retrievability(double elapsedDays, double stability) =>
      1 / (1 + elapsedDays / (9 * stability));

  double _recallStability(
    double stability,
    double difficulty,
    double retrievability,
    int grade,
  ) {
    var increase =
        math.exp(parameters[8]) *
        (11 - difficulty) *
        math.pow(stability, -parameters[9]).toDouble() *
        (math.exp(parameters[10] * (1 - retrievability)) - 1);
    if (grade == 2) increase *= parameters[15];
    if (grade == 4) increase *= parameters[16];
    return stability * (1 + math.max(0, increase));
  }

  double _forgettingStability(
    double stability,
    double difficulty,
    double retrievability,
  ) {
    final value =
        parameters[11] *
        math.pow(difficulty, -parameters[12]).toDouble() *
        (math.pow(stability + 1, parameters[13]).toDouble() - 1) *
        math.exp(parameters[14] * (1 - retrievability));
    return math.min(stability, math.max(0.1, value));
  }

  int _nextInterval(double stability) {
    final raw = 9 * stability * (1 / desiredRetention - 1);
    return raw.round().clamp(1, maxIntervalDays);
  }

  double _toFsrsDifficulty(double legacyDifficulty) =>
      (1 + (legacyDifficulty - 1.2) / 1.8 * 9).clamp(1.0, 10.0);

  double _fromFsrsDifficulty(double fsrsDifficulty) =>
      (1.2 + (fsrsDifficulty - 1) / 9 * 1.8).clamp(1.2, 3.0);
}
