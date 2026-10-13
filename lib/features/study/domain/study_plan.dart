import '../../memory/domain/recall_models.dart';

enum PlanReason { resume, relearning, overdue, leech, newCard, extraPractice }

class StudyCandidate {
  final int wordId;

  /// Stable LearningItem identity.  Legacy recognition candidates may omit it,
  /// but skill-specific plans must use this key so two abilities on one word
  /// never collapse into a single queue entry.
  final String? learningItemId;
  final String? lexemeId;
  final LearningSkill skill;
  final ReviewTaskType taskType;
  final String contentVersion;
  final DateTime? dueAt;
  final bool isNew;
  final bool isLeech;
  final bool isRelearning;
  final int estimatedSeconds;
  final bool needsConsolidation;

  /// 拟合后的记忆模型估计的此刻回忆概率；到期词里越低越先复习。
  final double? recallProbability;

  const StudyCandidate({
    required this.wordId,
    this.learningItemId,
    this.lexemeId,
    this.skill = LearningSkill.meaningRecognition,
    this.taskType = ReviewTaskType.recognition,
    this.contentVersion = 'legacy-v1',
    required this.dueAt,
    required this.isNew,
    required this.isLeech,
    required this.isRelearning,
    this.estimatedSeconds = 25,
    this.needsConsolidation = false,
    this.recallProbability,
  });

  String get uniqueKey => learningItemId ?? 'legacy:$wordId:${skill.name}';
}

class StudyPolicy {
  final int maxItems;
  final int maxMinutes;
  final int dailyNewLimit;
  final int dailyNewUsed;
  final int maxRelearningItems;
  final bool onlyLeeches;

  const StudyPolicy({
    required this.maxItems,
    required this.maxMinutes,
    required this.dailyNewLimit,
    required this.dailyNewUsed,
    this.maxRelearningItems = 12,
    this.onlyLeeches = false,
  });

  int get budgetSeconds => maxMinutes * 60;
  int get remainingNew =>
      (dailyNewLimit - dailyNewUsed).clamp(0, dailyNewLimit);
}

class PlannedItem {
  final int wordId;
  final String? learningItemId;
  final String? lexemeId;
  final LearningSkill skill;
  final ReviewTaskType taskType;
  final String contentVersion;
  final PlanReason reason;
  final int priority;

  const PlannedItem({
    required this.wordId,
    this.learningItemId,
    this.lexemeId,
    this.skill = LearningSkill.meaningRecognition,
    this.taskType = ReviewTaskType.recognition,
    this.contentVersion = 'legacy-v1',
    required this.reason,
    required this.priority,
  });
}

class StudyPlan {
  final DateTime createdAt;
  final List<PlannedItem> items;
  final int estimatedSeconds;
  final int newItemCount;

  const StudyPlan({
    required this.createdAt,
    required this.items,
    required this.estimatedSeconds,
    required this.newItemCount,
  });

  bool get isEmpty => items.isEmpty;

  Set<int> get wordIds => items.map((item) => item.wordId).toSet();

  Set<String> get learningItemIds =>
      items.map((item) => item.learningItemId).whereType<String>().toSet();

  List<PlannedItem> itemsForSkill(LearningSkill skill) =>
      items.where((item) => item.skill == skill).toList(growable: false);
}

/// 只负责“今天选哪些项目”，不修改卡片状态，也不消费新词额度。
class StudyPlanner {
  const StudyPlanner();

  StudyPlan build(
    List<StudyCandidate> candidates,
    StudyPolicy policy, {
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final unique = <String, StudyCandidate>{};
    for (final candidate in candidates) {
      unique.putIfAbsent(candidate.uniqueKey, () => candidate);
    }

    final filtered = unique.values
        .where((candidate) => !policy.onlyLeeches || candidate.isLeech)
        .toList();

    // 到期按自然日判断，与卡片的 isDue 和回忆提交口径一致。
    final today = DateTime(timestamp.year, timestamp.month, timestamp.day);
    bool isDue(StudyCandidate candidate) {
      final due = candidate.dueAt;
      return due != null &&
          !DateTime(due.year, due.month, due.day).isAfter(today);
    }

    int priority(StudyCandidate candidate) {
      if (candidate.needsConsolidation) return -1;
      if (candidate.isRelearning) return 0;
      if (candidate.isLeech) return 1;
      if (isDue(candidate)) {
        return 2;
      }
      if (candidate.isNew) return 4;
      return 3;
    }

    filtered.sort((a, b) {
      final byPriority = priority(a).compareTo(priority(b));
      if (byPriority != 0) return byPriority;
      // 到期词超出今日容量时，先复习模型认为最可能已经忘掉的。
      final aRecall = a.recallProbability;
      final bRecall = b.recallProbability;
      if (aRecall != null && bRecall != null && aRecall != bRecall) {
        return aRecall.compareTo(bRecall);
      }
      final aDue = a.dueAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDue = b.dueAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final byDue = aDue.compareTo(bDue);
      return byDue != 0 ? byDue : a.uniqueKey.compareTo(b.uniqueKey);
    });

    final selected = <PlannedItem>[];
    var seconds = 0;
    final newLexemes = <String>{};
    var relearningCount = 0;

    for (final candidate in filtered) {
      if (selected.length >= policy.maxItems) break;
      if (candidate.isRelearning &&
          !candidate.needsConsolidation &&
          relearningCount >= policy.maxRelearningItems) {
        continue;
      }
      final lexemeKey = candidate.lexemeId ?? 'legacy:${candidate.wordId}';
      if (candidate.isNew &&
          !newLexemes.contains(lexemeKey) &&
          newLexemes.length >= policy.remainingNew) {
        continue;
      }
      if (seconds + candidate.estimatedSeconds > policy.budgetSeconds &&
          selected.isNotEmpty) {
        continue;
      }

      final reason = candidate.isRelearning
          ? PlanReason.relearning
          : candidate.isLeech
          ? PlanReason.leech
          : candidate.isNew
          ? PlanReason.newCard
          : isDue(candidate)
          ? PlanReason.overdue
          : PlanReason.extraPractice;
      selected.add(
        PlannedItem(
          wordId: candidate.wordId,
          learningItemId: candidate.learningItemId,
          lexemeId: candidate.lexemeId,
          skill: candidate.skill,
          taskType: candidate.taskType,
          contentVersion: candidate.contentVersion,
          reason: reason,
          priority: priority(candidate),
        ),
      );
      seconds += candidate.estimatedSeconds;
      if (candidate.isNew) newLexemes.add(lexemeKey);
      if (candidate.isRelearning) relearningCount++;
    }

    return StudyPlan(
      createdAt: timestamp,
      items: List.unmodifiable(selected),
      estimatedSeconds: seconds,
      newItemCount: newLexemes.length,
    );
  }
}
