import '../../../models/test_run.dart';

/// 某一自然日的学习汇总（只统计已完成的轮次）。
class DailyRecord {
  final DateTime day;
  final int rounds;
  final int attempts;
  final int correct;
  final int wrong;
  final int timeout;
  final int distinctWords;

  /// 作答反应时间之和（只含思考时间，不含反馈与翻页）。
  final int activeMs;

  /// 学习用时：每轮从开始到完成的实际时长之和，单轮最多计 [maxRunDuration]。
  final int studyMs;

  /// 题量或准确率明显偏离日常的异常天（如调试、误操作、一次性大量刷题），
  /// 不参与趋势、构成与明细统计；打卡仍照常计算。
  final bool anomalous;

  const DailyRecord({
    required this.day,
    required this.rounds,
    required this.attempts,
    required this.correct,
    required this.wrong,
    required this.timeout,
    required this.distinctWords,
    required this.activeMs,
    required this.studyMs,
    this.anomalous = false,
  });

  /// 暂停后很久才完成的轮次只计这么长，避免一轮把当天用时拉到几小时。
  static const maxRunDuration = Duration(minutes: 60);

  DailyRecord _withAnomalous(bool value) => DailyRecord(
    day: day,
    rounds: rounds,
    attempts: attempts,
    correct: correct,
    wrong: wrong,
    timeout: timeout,
    distinctWords: distinctWords,
    activeMs: activeMs,
    studyMs: studyMs,
    anomalous: value,
  );

  /// 异常天判定：题量超过日常中位数 3 倍，或有一定题量但准确率低于 10%。
  /// 少于 3 个学习日时没有可靠的「日常」，只按准确率判断。
  static List<DailyRecord> markAnomalies(List<DailyRecord> records) {
    final counts = records.map((r) => r.attempts).toList()..sort();
    final median = counts.isEmpty ? 0 : counts[counts.length ~/ 2];
    return [
      for (final r in records)
        r._withAnomalous(
          r.attempts >= 20 &&
              (r.accuracy < 0.10 ||
                  (records.length >= 3 && r.attempts > median * 3)),
        ),
    ];
  }

  double get accuracy => attempts == 0 ? 0 : correct / attempts;
  double get timeoutRate => attempts == 0 ? 0 : timeout / attempts;
  bool get checkedIn => rounds > 0;

  /// 按本地完成日分组；同一轮的所有作答算在完成那一天，与打卡口径一致。
  static List<DailyRecord> fromRuns(Iterable<TestRun> runs) {
    final byDay = <DateTime, List<TestRun>>{};
    for (final run in runs) {
      final finished = run.finishedAt?.toLocal();
      if (finished == null) continue;
      final day = DateTime(finished.year, finished.month, finished.day);
      byDay.putIfAbsent(day, () => []).add(run);
    }
    final records = [
      for (final entry in byDay.entries) _aggregate(entry.key, entry.value),
    ]..sort((a, b) => a.day.compareTo(b.day));
    return markAnomalies(records);
  }

  static DailyRecord _aggregate(DateTime day, List<TestRun> runs) {
    var correct = 0, wrong = 0, timeout = 0, attempts = 0, activeMs = 0;
    var studyMs = 0;
    final words = <int>{};
    for (final run in runs) {
      final elapsed = run.finishedAt!.difference(run.startedAt);
      if (!elapsed.isNegative) {
        studyMs += (elapsed > maxRunDuration ? maxRunDuration : elapsed)
            .inMilliseconds;
      }
      for (final a in run.attempts) {
        if (a.wordId <= 0) continue;
        attempts++;
        words.add(a.wordId);
        activeMs += a.rtMs;
        if (a.isCorrect) {
          correct++;
        } else if (a.isTimeout) {
          timeout++;
        } else {
          wrong++;
        }
      }
    }
    return DailyRecord(
      day: day,
      rounds: runs.length,
      attempts: attempts,
      correct: correct,
      wrong: wrong,
      timeout: timeout,
      distinctWords: words.length,
      activeMs: activeMs,
      studyMs: studyMs,
    );
  }
}

/// 一段时间窗口内的作答构成。
class AnswerComposition {
  final int correct;
  final int wrong;
  final int timeout;

  const AnswerComposition(this.correct, this.wrong, this.timeout);

  factory AnswerComposition.of(Iterable<DailyRecord> records) {
    var c = 0, w = 0, t = 0;
    for (final r in records) {
      c += r.correct;
      w += r.wrong;
      t += r.timeout;
    }
    return AnswerComposition(c, w, t);
  }

  int get total => correct + wrong + timeout;
}
