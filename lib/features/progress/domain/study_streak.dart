import '../../../models/test_run.dart';

/// 打卡统计。打卡标准：当天（本地自然日）至少完成一轮测试。
class StudyStreak {
  /// 截至今天的连续打卡天数；今天还没打卡时，昨天打过卡也不断签。
  final int currentDays;

  /// 历史最长连续打卡天数。
  final int longestDays;

  /// 累计打卡天数。
  final int totalDays;

  /// 今天是否已打卡。
  final bool checkedInToday;

  /// 已打卡的自然日（只含年月日），升序。
  final List<DateTime> checkInDays;

  const StudyStreak({
    required this.currentDays,
    required this.longestDays,
    required this.totalDays,
    required this.checkedInToday,
    required this.checkInDays,
  });

  static const empty = StudyStreak(
    currentDays: 0,
    longestDays: 0,
    totalDays: 0,
    checkedInToday: false,
    checkInDays: [],
  );

  /// 按完成时间所在的本地自然日计算；未完成的轮次不计入。
  factory StudyStreak.fromRuns(Iterable<TestRun> runs, {DateTime? now}) {
    final days = <DateTime>{
      for (final run in runs)
        if (run.finishedAt != null) _day(run.finishedAt!.toLocal()),
    };
    return StudyStreak.fromDays(days, now: now);
  }

  factory StudyStreak.fromDays(Iterable<DateTime> source, {DateTime? now}) {
    final days = {for (final d in source) _day(d)}.toList()..sort();
    if (days.isEmpty) return empty;

    var longest = 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      run = _gap(days[i - 1], days[i]) == 1 ? run + 1 : 1;
      if (run > longest) longest = run;
    }

    final today = _day(now ?? DateTime.now());
    final sinceLast = _gap(days.last, today);
    var current = 0;
    if (sinceLast <= 1) {
      current = 1;
      for (var i = days.length - 1; i > 0; i--) {
        if (_gap(days[i - 1], days[i]) != 1) break;
        current++;
      }
    }

    return StudyStreak(
      currentDays: current,
      longestDays: longest,
      totalDays: days.length,
      checkedInToday: sinceLast == 0,
      checkInDays: List.unmodifiable(days),
    );
  }

  Map<String, dynamic> toJson() => {
    'streakDays': currentDays,
    'longestStreakDays': longestDays,
    'totalStudyDays': totalDays,
    'checkedInToday': checkedInToday,
  };

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 按日历日计算差值，用 UTC 避免夏令时切换日只有 23 小时。
  static int _gap(DateTime a, DateTime b) => DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}
