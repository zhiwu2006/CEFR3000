import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/features/memory/domain/fsrs_optimizer.dart';
import 'package:vocab_flash_test/features/memory/domain/fsrs_scheduler.dart';
import 'package:vocab_flash_test/features/study/domain/study_plan.dart';
import 'package:vocab_flash_test/models/attempt.dart';
import 'package:vocab_flash_test/models/card_state.dart';
import 'package:vocab_flash_test/models/review_event.dart';

ReviewEvent _event(int wordId, DateTime at, bool correct) => ReviewEvent(
  id: '$wordId-${at.toIso8601String()}',
  sessionId: 's-${at.month}-${at.day}',
  attempt: Attempt(
    wordId: wordId,
    result: correct ? AttemptResult.correct : AttemptResult.wrong,
    rtMs: 900,
    chosenIndex: correct ? 0 : 1,
    correctIndex: 0,
    timestamp: at,
  ),
  beforeRevision: 0,
  resultingState: CardState.newCard(wordId, now: at),
  status: 'committed',
  evaluationSource: 'objective',
  taskType: 'recognition',
  createdAt: at,
  skill: 'meaningRecognition',
  timeLimitMs: 2000,
);

/// 模拟一个记得比默认参数假设差得多的学习者，词有难有易：
/// 记住的词间隔会拉长，忘掉的词回到短间隔，模型才能按历史区分。
List<ReviewEvent> _forgetfulLearner({int words = 300}) {
  final random = math.Random(7);
  final events = <ReviewEvent>[];
  final start = DateTime(2026, 8, 1, 8);
  for (var w = 1; w <= words; w++) {
    final base = 0.3 + random.nextDouble() * 2;
    var stability = base;
    var day = 0;
    var gap = 1;
    events.add(_event(w, start.add(Duration(days: day, minutes: w)), true));
    for (var review = 0; review < 6; review++) {
      day += gap;
      final recall = math.exp(-gap / stability);
      final remembered = random.nextDouble() < recall;
      // 四选一：没记住也有四分之一蒙对。
      final correct = remembered || random.nextDouble() < 0.25;
      events.add(
        _event(w, start.add(Duration(days: day, minutes: w)), correct),
      );
      stability = remembered ? stability * 2.5 : base;
      gap = remembered ? gap * 2 : 1;
    }
  }
  return events;
}

void main() {
  test('fitting beats the default parameters on held-out words', () {
    final result = const FsrsOptimizer().fit(_forgetfulLearner());
    expect(result, isNotNull);
    expect(result!.testSamples, greaterThan(100));
    // 默认参数高估了这个学习者的记忆，拟合后留出词上的误差明显下降。
    expect(result.fittedLoss, lessThan(result.defaultLoss - 0.2));
    final restored = FsrsFitResult.fromJson(
      jsonDecode(jsonEncode(result.toJson())) as Map<String, dynamic>,
    );
    expect(restored.parameters.values, result.parameters.values);
    expect(restored.fittedLoss, result.fittedLoss);
  });

  test('a fit is adopted only if it beats both defaults and the average', () {
    FsrsFitResult fit(double fitted) => FsrsFitResult(
      parameters: const FsrsParameters(),
      fittedAt: DateTime(2026, 10, 13),
      trainSamples: 600,
      testSamples: 150,
      defaultLoss: 0.88,
      fittedLoss: fitted,
      baselineLoss: 0.65,
    );
    expect(fit(0.62).improves, isTrue);
    expect(fit(0.70).improves, isFalse); // 不如只猜平均
    expect(fit(0.879).improves, isFalse);
  });

  test('too little history is not fitted', () {
    expect(const FsrsOptimizer().fit(_forgetfulLearner(words: 20)), isNull);
  });

  test('due words with lower recall are planned first', () {
    final now = DateTime(2026, 10, 13, 9);
    final due = now.subtract(const Duration(days: 1));
    StudyCandidate candidate(int id, double? recall) => StudyCandidate(
      wordId: id,
      dueAt: due,
      isNew: false,
      isLeech: false,
      isRelearning: false,
      recallProbability: recall,
    );
    final plan = const StudyPlanner().build(
      [candidate(1, 0.9), candidate(2, 0.2), candidate(3, 0.6)],
      const StudyPolicy(
        maxItems: 2,
        maxMinutes: 10,
        dailyNewLimit: 0,
        dailyNewUsed: 0,
      ),
      now: now,
    );
    expect(plan.items.map((i) => i.wordId), [2, 3]);
  });

  // 真实数据：REPLAY_EVENTS=<每行一个 ReviewEvent JSON> flutter test ...
  final path = Platform.environment['REPLAY_EVENTS'];
  test(
    'fit on real history',
    () {
      final events = File(path!)
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty)
          .map(
            (l) => ReviewEvent.fromJson(jsonDecode(l) as Map<String, dynamic>),
          )
          .toList();
      final watch = Stopwatch()..start();
      final r = const FsrsOptimizer().fit(events);
      // ignore: avoid_print
      print(
        r == null
            ? 'not enough samples'
            : 'train=${r.trainSamples} test=${r.testSamples} '
                  'default=${r.defaultLoss.toStringAsFixed(4)} '
                  'fitted=${r.fittedLoss.toStringAsFixed(4)} '
                  'baseline=${r.baselineLoss.toStringAsFixed(4)} '
                  'improves=${r.improves} ${watch.elapsedMilliseconds}ms\n'
                  'params=${r.parameters.values.map((v) => v.toStringAsFixed(3)).join(', ')}',
      );
    },
    skip: path == null ? 'set REPLAY_EVENTS to run' : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
