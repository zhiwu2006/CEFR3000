import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/features/progress/domain/daily_records.dart';
import 'package:vocab_flash_test/models/attempt.dart';
import 'package:vocab_flash_test/models/test_run.dart';

Attempt _a(int wordId, AttemptResult result, DateTime at, {int rt = 1000}) =>
    Attempt(
      wordId: wordId,
      result: result,
      rtMs: rt,
      chosenIndex: 0,
      correctIndex: 0,
      timestamp: at,
    );

TestRun _run(DateTime start, List<Attempt> attempts, {DateTime? finished}) =>
    TestRun(
      id: start.toIso8601String(),
      startedAt: start,
      finishedAt: finished,
      size: attempts.length,
      levels: const ['A1'],
      timeLimitMs: 2000,
      attempts: attempts,
      orderPolicy: 'random',
      onlyLeeches: false,
    );

void main() {
  final d12 = DateTime(2026, 10, 12, 9);
  final d13 = DateTime(2026, 10, 13, 9);

  test('aggregates finished runs per local finish day', () {
    final records = DailyRecord.fromRuns([
      _run(d13, [
        _a(1, AttemptResult.correct, d13),
        _a(2, AttemptResult.timeout, d13, rt: 2000),
        _a(2, AttemptResult.wrong, d13),
        _a(0, AttemptResult.correct, d13), // 恢复占位，不计入
      ], finished: d13.add(const Duration(minutes: 5))),
      _run(d12, [
        _a(3, AttemptResult.correct, d12),
      ], finished: d12.add(const Duration(minutes: 5))),
      _run(d13, [_a(9, AttemptResult.correct, d13)]), // 未完成
    ]);

    expect(records.map((r) => r.day), [
      DateTime(2026, 10, 12),
      DateTime(2026, 10, 13),
    ]);
    final today = records.last;
    expect(today.rounds, 1);
    expect(today.attempts, 3);
    expect(today.correct, 1);
    expect(today.wrong, 1);
    expect(today.timeout, 1);
    expect(today.distinctWords, 2);
    expect(today.activeMs, 4000);
    expect(today.accuracy, closeTo(1 / 3, 1e-9));

    final mix = AnswerComposition.of(records);
    expect((mix.correct, mix.wrong, mix.timeout, mix.total), (2, 1, 1, 4));
  });

  test('study time uses wall-clock round duration capped at 60 min', () {
    final start = DateTime(2026, 10, 13, 7);
    final records = DailyRecord.fromRuns([
      _run(start, [
        _a(1, AttemptResult.correct, start),
      ], finished: start.add(const Duration(minutes: 4))),
      _run(
        start.add(const Duration(hours: 1)),
        [_a(2, AttemptResult.correct, start)],
        finished: start.add(const Duration(hours: 4)),
      ), // 暂停很久
    ]);
    expect(records.single.studyMs, const Duration(minutes: 64).inMilliseconds);
  });

  test('flags outlier days like the migrated 9/16 and 9/17', () {
    DailyRecord day(int d, int attempts, int correct) => DailyRecord(
      day: DateTime(2026, 9, d),
      rounds: 1,
      attempts: attempts,
      correct: correct,
      wrong: attempts - correct,
      timeout: 0,
      distinctWords: 50,
      activeMs: 0,
      studyMs: 0,
    );
    final marked = DailyRecord.markAnomalies([
      day(16, 68, 0), // 0% 准确率
      day(17, 1033, 200), // 题量是日常的 8 倍
      day(19, 255, 133),
      day(23, 157, 88),
      day(24, 143, 59),
      day(25, 140, 76),
    ]);
    expect(marked.where((r) => r.anomalous).map((r) => r.day.day), [16, 17]);
  });
}
