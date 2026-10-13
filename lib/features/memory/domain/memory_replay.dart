import 'dart:math' as math;

import '../../../models/card_state.dart';
import '../../../models/review_event.dart';
import '../application/recall_commit_service.dart';
import 'fsrs_scheduler.dart';
import 'memory_scheduler.dart';
import 'recall_models.dart';

/// 一次跨日复习的观测：复习前的预测与实际结果。
class ReplaySample {
  final int wordId;
  final double elapsedDays;
  final bool success;

  /// FSRS（独立轨迹）在作答前预测的回忆概率。
  final double fsrsRetrievability;

  /// 现行算法在这一天是否认为该词已到期。
  final bool legacyDue;

  /// 现行算法上一次安排的间隔（天）。
  final int legacyIntervalDays;

  /// FSRS 上一次安排的间隔（天）。
  final int fsrsIntervalDays;

  const ReplaySample({
    required this.wordId,
    required this.elapsedDays,
    required this.success,
    required this.fsrsRetrievability,
    required this.legacyDue,
    required this.legacyIntervalDays,
    required this.fsrsIntervalDays,
  });
}

class CalibrationBucket {
  final double low;
  final double high;
  final int count;
  final double meanPredicted;
  final double observed;

  const CalibrationBucket(
    this.low,
    this.high,
    this.count,
    this.meanPredicted,
    this.observed,
  );
}

/// 重放结果与汇总指标。
class ReplayReport {
  /// 四选一的随机蒙对概率，用来从观测正确率估计真实回忆率。
  static const guessRate = 0.25;

  final int events;
  final int words;
  final List<ReplaySample> samples;
  final Map<int, CardState> legacyStates;
  final Map<int, CardState> fsrsStates;

  const ReplayReport({
    required this.events,
    required this.words,
    required this.samples,
    required this.legacyStates,
    required this.fsrsStates,
  });

  static double trueRecall(double observed) =>
      ((observed - guessRate) / (1 - guessRate)).clamp(0.0, 1.0);

  double _rate(Iterable<ReplaySample> s) =>
      s.isEmpty ? double.nan : s.where((x) => x.success).length / s.length;

  double get observedRecall => _rate(samples);

  /// 现行算法认为到期时的实际正确率，即它真正达到的保持率。
  double get legacyDueRecall => _rate(samples.where((s) => s.legacyDue));

  int get legacyDueCount => samples.where((s) => s.legacyDue).length;

  /// FSRS 预测的对数损失（越低越准）。按观测正确率比较，预测里加入蒙对概率。
  double get fsrsLogLoss {
    if (samples.isEmpty) return double.nan;
    var sum = 0.0;
    for (final s in samples) {
      final p = (guessRate + (1 - guessRate) * s.fsrsRetrievability).clamp(
        1e-6,
        1 - 1e-6,
      );
      sum += s.success ? -math.log(p) : -math.log(1 - p);
    }
    return sum / samples.length;
  }

  /// 只用总体正确率当预测的基准对数损失；FSRS 必须比它低才算有区分力。
  double get baselineLogLoss {
    if (samples.isEmpty) return double.nan;
    final p = observedRecall.clamp(1e-6, 1 - 1e-6);
    return -(p * math.log(p) + (1 - p) * math.log(1 - p));
  }

  List<CalibrationBucket> calibration({
    List<double> edges = const [0, 0.5, 0.7, 0.85, 0.95, 1.0001],
  }) {
    final buckets = <CalibrationBucket>[];
    for (var i = 0; i < edges.length - 1; i++) {
      final inBucket = samples
          .where(
            (s) =>
                s.fsrsRetrievability >= edges[i] &&
                s.fsrsRetrievability < edges[i + 1],
          )
          .toList();
      if (inBucket.isEmpty) continue;
      final mean =
          inBucket.fold<double>(0, (a, s) => a + s.fsrsRetrievability) /
          inBucket.length;
      buckets.add(
        CalibrationBucket(
          edges[i],
          math.min(1, edges[i + 1]),
          inBucket.length,
          mean,
          trueRecall(_rate(inBucket)),
        ),
      );
    }
    return buckets;
  }

  /// 各算法最终状态下的间隔分布（天 → 词数）。
  static Map<int, int> intervalHistogram(Map<int, CardState> states) {
    final hist = <int, int>{};
    for (final s in states.values) {
      final days = math.max(
        0,
        (s.due.difference(s.lastReview).inHours / 24).round(),
      );
      hist[days] = (hist[days] ?? 0) + 1;
    }
    return Map.fromEntries(
      hist.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }
}

/// 用历史作答事件分别重放现行算法与独立的 FSRS 轨迹。
///
/// 纯函数：不读写任何存储。两套算法各自持有自己的状态，FSRS 不再从现行
/// 算法的状态出发（线上影子字段就是这样被污染的），因此可以公平比较。
class MemoryReplay {
  final MemoryScheduler legacy;
  final FsrsScheduler fsrs;
  final int timeLimitMsFallback;
  final double slowThreshold;

  const MemoryReplay({
    this.legacy = const MemoryScheduler(),
    this.fsrs = const FsrsScheduler(),
    this.timeLimitMsFallback = 2000,
    this.slowThreshold = 1.5,
  });

  ReplayReport run(
    Iterable<ReviewEvent> source, {
    LearningSkill skill = LearningSkill.meaningRecognition,
  }) {
    final events =
        source
            .where((e) => e.isCommitted && e.skill == skill.name)
            .where((e) => e.attempt.wordId > 0)
            .toList()
          ..sort((a, b) => a.attempt.timestamp.compareTo(b.attempt.timestamp));

    final legacyStates = <int, CardState>{};
    final fsrsStates = <int, CardState>{};
    final samples = <ReplaySample>[];

    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      final attempt = event.attempt;
      final wordId = attempt.wordId;
      final at = attempt.timestamp;
      final legacyBefore =
          legacyStates[wordId] ?? CardState.newCard(wordId, now: at);
      final fsrsBefore =
          fsrsStates[wordId] ?? CardState.newCard(wordId, now: at);
      final seenBefore = legacyStates.containsKey(wordId);

      final evidence = RecallCommitService.evidenceFromAttempt(
        sessionId: event.sessionId,
        eventId: event.id,
        attempt: attempt,
        timeLimitMs: event.timeLimitMs > 0
            ? event.timeLimitMs
            : timeLimitMsFallback,
        slowThreshold: slowThreshold,
        baselineRtMs: legacyBefore.rtP50 > 0 ? legacyBefore.rtP50 : null,
        isDueReview: RecallCommitService.isDueOn(legacyBefore.due, at),
        answerRevealed: event.answerRevealed,
        hintUsed: event.hintUsed,
        taskType: ReviewTaskType.recognition,
        skill: skill,
        source: EvaluationSource.objective,
        ratingOverride: null,
      );

      // 只把「上次复习在更早的自然日、且不是会话内重测」的作答当成一次
      // 记忆检验；同一天内的重复只反映短时记忆。
      final lastDay = DateTime(
        legacyBefore.lastReview.year,
        legacyBefore.lastReview.month,
        legacyBefore.lastReview.day,
      );
      final today = DateTime(at.year, at.month, at.day);
      if (seenBefore &&
          !evidence.isInSessionRetry &&
          evidence.isIndependentRecall &&
          today.isAfter(lastDay)) {
        samples.add(
          ReplaySample(
            wordId: wordId,
            elapsedDays:
                at.difference(legacyBefore.lastReview).inMinutes / (60 * 24),
            success: evidence.isSuccess,
            fsrsRetrievability: fsrs.retrievability(fsrsBefore, at: at),
            legacyDue: evidence.isDueReview,
            legacyIntervalDays: _days(legacyBefore),
            fsrsIntervalDays: _days(fsrsBefore),
          ),
        );
      }

      legacyStates[wordId] = legacy.schedule(
        legacyBefore,
        evidence,
        reviewedAt: at,
      );
      fsrsStates[wordId] = fsrs
          .schedule(fsrsBefore, evidence, reviewedAt: at)
          .state;
    }

    return ReplayReport(
      events: events.length,
      words: legacyStates.length,
      samples: samples,
      legacyStates: legacyStates,
      fsrsStates: fsrsStates,
    );
  }

  static int _days(CardState s) =>
      math.max(0, (s.due.difference(s.lastReview).inHours / 24).round());
}
