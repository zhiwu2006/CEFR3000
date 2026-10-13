import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/features/progress/domain/study_streak.dart';
import 'package:vocab_flash_test/models/test_run.dart';

TestRun _run(DateTime startedAt, {DateTime? finishedAt}) => TestRun(
  id: startedAt.toIso8601String(),
  startedAt: startedAt,
  finishedAt: finishedAt,
  size: 50,
  levels: const ['A1'],
  timeLimitMs: 2000,
  attempts: const [],
  orderPolicy: 'random',
  onlyLeeches: false,
);

/// 手机迁移数据（2026-10-13）里实际完成测试的日期。
const _realDays = [
  '2026-09-16',
  '2026-09-17',
  '2026-09-19',
  '2026-09-23',
  '2026-09-24',
  '2026-09-25',
  '2026-09-26',
  '2026-09-27',
  '2026-09-28',
  '2026-09-29',
  '2026-09-30',
  '2026-10-05',
  '2026-10-06',
  '2026-10-07',
  '2026-10-08',
  '2026-10-09',
  '2026-10-10',
  '2026-10-11',
  '2026-10-12',
  '2026-10-13',
];

void main() {
  final realDays = _realDays.map(DateTime.parse).toList();

  test('real migrated history: current 9 (also the longest), total 20', () {
    final streak = StudyStreak.fromDays(
      realDays,
      now: DateTime(2026, 10, 13, 20),
    );
    expect(streak.currentDays, 9);
    expect(streak.longestDays, 9);
    expect(streak.totalDays, 20);
    expect(streak.checkedInToday, isTrue);
  });

  test('longest run before the current one is 8 days (09-23..09-30)', () {
    final before = realDays.where((d) => d.isBefore(DateTime(2026, 10)));
    final streak = StudyStreak.fromDays(before, now: DateTime(2026, 9, 30));
    expect(streak.longestDays, 8);
  });

  test('not yet checked in today keeps yesterday streak', () {
    final streak = StudyStreak.fromDays(
      realDays.take(realDays.length - 1),
      now: DateTime(2026, 10, 13, 7),
    );
    expect(streak.currentDays, 8);
    expect(streak.checkedInToday, isFalse);
  });

  test('a missed day resets the current streak', () {
    final streak = StudyStreak.fromDays(realDays, now: DateTime(2026, 10, 15));
    expect(streak.currentDays, 0);
    expect(streak.longestDays, 9);
  });

  test('only finished rounds count, by local finish day', () {
    final runs = [
      _run(DateTime(2026, 10, 12, 9), finishedAt: DateTime(2026, 10, 12, 9, 5)),
      _run(DateTime(2026, 10, 13, 9)), // 开始但没完成，不算打卡
      _run(
        DateTime(2026, 10, 11, 23, 58),
        finishedAt: DateTime(2026, 10, 12, 0, 3),
      ), // 跨零点按完成日
    ];
    final streak = StudyStreak.fromRuns(runs, now: DateTime(2026, 10, 13, 10));
    expect(streak.totalDays, 1);
    expect(streak.currentDays, 1);
    expect(streak.checkedInToday, isFalse);
  });

  test('empty history', () {
    expect(StudyStreak.fromRuns(const []).currentDays, 0);
  });
}
