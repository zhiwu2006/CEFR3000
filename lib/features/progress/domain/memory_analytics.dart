import '../../../models/review_event.dart';

class ObservationWindowMetric {
  final int windowDays;
  final int eligibleCount;
  final int successCount;

  const ObservationWindowMetric({
    required this.windowDays,
    required this.eligibleCount,
    required this.successCount,
  });

  double? get successRate =>
      eligibleCount == 0 ? null : successCount / eligibleCount;

  Map<String, dynamic> toJson() => {
    'windowDays': windowDays,
    'eligibleCount': eligibleCount,
    'successCount': successCount,
    'successRate': successRate,
  };
}

class SkillCoverageMetric {
  final String skill;
  final int eventCount;
  final int successfulEventCount;
  final int distinctWordCount;

  const SkillCoverageMetric({
    required this.skill,
    required this.eventCount,
    required this.successfulEventCount,
    required this.distinctWordCount,
  });

  double get practiceAccuracy =>
      eventCount == 0 ? 0 : successfulEventCount / eventCount;

  Map<String, dynamic> toJson() => {
    'skill': skill,
    'eventCount': eventCount,
    'successfulEventCount': successfulEventCount,
    'distinctWordCount': distinctWordCount,
    'practiceAccuracy': practiceAccuracy,
  };
}

class MemoryAnalytics {
  const MemoryAnalytics._();

  static List<ReviewEvent> committed(Iterable<ReviewEvent> events) =>
      events.where((event) => event.isCommitted).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// Counts the first eligible recall after a real elapsed window per word.
  /// Same-day corrections and earlier practice are excluded from the window.
  static ObservationWindowMetric observation(
    Iterable<ReviewEvent> source,
    int windowDays,
  ) {
    final events = committed(source);
    // 按 (wordId, skill) 组合键分组，避免将不同技能类型的复习事件
    // （如识别 vs 产出回忆）混入同一观测样本。
    final byKey = <(int, String), List<ReviewEvent>>{};
    for (final event in events) {
      if (!event.independentRecall || !event.isDueReview) continue;
      final key = (event.resultingState.wordId, event.skill);
      byKey.putIfAbsent(key, () => []).add(event);
    }
    var eligible = 0;
    var success = 0;
    for (final eventsForKey in byKey.values) {
      ReviewEvent? previous;
      for (final event in eventsForKey) {
        if (previous != null &&
            event.createdAt.difference(previous.createdAt).inHours >=
                windowDays * 24) {
          eligible++;
          if (event.isSuccessful) success++;
          break;
        }
        previous = event;
      }
    }
    return ObservationWindowMetric(
      windowDays: windowDays,
      eligibleCount: eligible,
      successCount: success,
    );
  }

  static List<SkillCoverageMetric> skillCoverage(Iterable<ReviewEvent> source) {
    final bySkill = <String, List<ReviewEvent>>{};
    for (final event in committed(source)) {
      bySkill.putIfAbsent(event.skill, () => []).add(event);
    }
    return bySkill.entries
        .map(
          (entry) => SkillCoverageMetric(
            skill: entry.key,
            eventCount: entry.value.length,
            successfulEventCount: entry.value
                .where((event) => event.isSuccessful)
                .length,
            distinctWordCount: entry.value
                .map((event) => event.resultingState.wordId)
                .toSet()
                .length,
          ),
        )
        .toList();
  }

  static Map<String, dynamic> summarize(Iterable<ReviewEvent> source) {
    final events = committed(source);
    final seven = observation(events, 7);
    final thirty = observation(events, 30);
    final skills = skillCoverage(events);
    return {
      'observation7d': seven.toJson(),
      'observation30d': thirty.toJson(),
      'skillCoverage': skills.map((metric) => metric.toJson()).toList(),
    };
  }
}
