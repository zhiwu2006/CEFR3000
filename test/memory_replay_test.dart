import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/features/memory/domain/memory_replay.dart';
import 'package:vocab_flash_test/models/attempt.dart';
import 'package:vocab_flash_test/models/card_state.dart';
import 'package:vocab_flash_test/models/review_event.dart';

ReviewEvent _event(int wordId, DateTime at, AttemptResult result) {
  final attempt = Attempt(
    wordId: wordId,
    result: result,
    rtMs: 900,
    chosenIndex: 0,
    correctIndex: 0,
    timestamp: at,
  );
  return ReviewEvent(
    id: '$wordId-${at.toIso8601String()}',
    sessionId: 's-${at.day}',
    attempt: attempt,
    beforeRevision: 0,
    resultingState: CardState.newCard(wordId, now: at),
    status: 'committed',
    evaluationSource: 'objective',
    taskType: 'recognition',
    createdAt: at,
    skill: 'meaningRecognition',
    timeLimitMs: 2000,
  );
}

void main() {
  test('only cross-day independent answers become samples', () {
    final d1 = DateTime(2026, 10, 1, 7);
    final report = const MemoryReplay().run([
      _event(1, d1, AttemptResult.correct),
      _event(1, d1.add(const Duration(minutes: 3)), AttemptResult.correct),
      _event(1, d1.add(const Duration(days: 1)), AttemptResult.correct),
      _event(1, d1.add(const Duration(days: 3)), AttemptResult.wrong),
    ]);
    expect(report.events, 4);
    expect(report.words, 1);
    expect(report.samples.length, 2); // 同日重复不算
    expect(report.samples.map((s) => s.success), [true, false]);
    // 独立轨迹：FSRS 从自己的状态出发，最终稳定度与现行算法不同
    expect(
      report.fsrsStates[1]!.stability,
      isNot(closeTo(report.legacyStates[1]!.stability, 1e-6)),
    );
    for (final sample in report.samples) {
      expect(sample.fsrsRetrievability, inExclusiveRange(0, 1));
    }
  });

  test('true recall removes the four-option guess rate', () {
    expect(ReplayReport.trueRecall(0.25), 0);
    expect(ReplayReport.trueRecall(1), 1);
    expect(ReplayReport.trueRecall(0.625), closeTo(0.5, 1e-9));
  });

  // 真实数据报告：REPLAY_EVENTS=<每行一个 ReviewEvent JSON 的文件> flutter test ...
  final path = Platform.environment['REPLAY_EVENTS'];
  test(
    'replay report on real history',
    () {
      final events = File(path!)
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty)
          .map(
            (l) => ReviewEvent.fromJson(jsonDecode(l) as Map<String, dynamic>),
          )
          .toList();
      final r = const MemoryReplay().run(events);
      String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
      final out = StringBuffer()
        ..writeln(
          'events=${r.events} words=${r.words} samples=${r.samples.length}',
        )
        ..writeln(
          'observed recall=${pct(r.observedRecall)} '
          'true≈${pct(ReplayReport.trueRecall(r.observedRecall))}',
        )
        ..writeln(
          'legacy due samples=${r.legacyDueCount} '
          'recall=${pct(r.legacyDueRecall)} '
          'true≈${pct(ReplayReport.trueRecall(r.legacyDueRecall))}',
        )
        ..writeln(
          'logloss fsrs=${r.fsrsLogLoss.toStringAsFixed(4)} '
          'baseline=${r.baselineLogLoss.toStringAsFixed(4)}',
        )
        ..writeln('calibration (fsrs predicted → true recall):');
      for (final b in r.calibration()) {
        out.writeln(
          '  [${b.low.toStringAsFixed(2)}-${b.high.toStringAsFixed(2)}) '
          'n=${b.count} predicted=${pct(b.meanPredicted)} actual≈${pct(b.observed)}',
        );
      }
      final byGap = <int, List<ReplaySample>>{};
      for (final s in r.samples) {
        byGap.putIfAbsent(s.elapsedDays.round().clamp(0, 8), () => []).add(s);
      }
      out.writeln('recall by elapsed days (8 = 8+):');
      for (final k in (byGap.keys.toList()..sort())) {
        final s = byGap[k]!;
        final obs = s.where((x) => x.success).length / s.length;
        out.writeln(
          '  ${k}d n=${s.length} observed=${pct(obs)} '
          'true≈${pct(ReplayReport.trueRecall(obs))}',
        );
      }
      out
        ..writeln(
          'legacy intervals: ${ReplayReport.intervalHistogram(r.legacyStates)}',
        )
        ..writeln(
          'fsrs intervals:   ${ReplayReport.intervalHistogram(r.fsrsStates)}',
        );
      // ignore: avoid_print
      print(out);
    },
    skip: path == null ? 'set REPLAY_EVENTS to run' : false,
  );
}
