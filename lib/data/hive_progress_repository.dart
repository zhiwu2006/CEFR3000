import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/models.dart';
import '../domain/srs.dart';
import '../features/progress/domain/memory_analytics.dart';
import '../features/memory/domain/learning_item_state.dart';
import 'progress_repository.dart';
import 'review_commit_repository.dart';
import 'exposure_repository.dart';
import 'learning_item_state_repository.dart';
import 'word_repository.dart';
import 'word_preference_repository.dart';
import 'migration/legacy_progress_migrator.dart';

/// Hive实现的进度仓储
class HiveProgressRepository
    implements
        ProgressRepository,
        LeechPolicyProgressRepository,
        ReviewCommitRepository,
        ExposureRepository,
        LearningItemStateRepository,
        WordPreferenceRepository,
        LegacyProgressSource {
  static const String _cardStateBoxName = 'card_states';
  static const String _testRunBoxName = 'test_runs';
  static const String _attemptBoxName = 'attempts';
  static const String _reviewEventBoxName = 'review_events';
  static const String _exposureEventBoxName = 'exposure_events';
  static const String _learningItemStateBoxName = 'learning_item_states';
  static const String _wordPreferenceBoxName = 'word_preferences';
  static const int _exportVersion = 3;

  late Box<CardState> _cardStateBox;
  late Box<TestRun> _testRunBox;
  late Box<Attempt> _attemptBox;
  late Box<ReviewEvent> _reviewEventBox;
  late Box<ExposureEvent> _exposureEventBox;
  late Box<String> _learningItemStateBox;
  late Box<String> _wordPreferenceBox;

  final WordRepository _wordRepository;

  HiveProgressRepository(this._wordRepository);

  /// 初始化
  Future<void> init() async {
    // 注册适配器
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AttemptAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CardStateAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(TestRunAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(AttemptResultAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(AttemptKindAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(ReviewEventAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(ExposureEventAdapter());
    }

    // 打开boxes
    _cardStateBox = await Hive.openBox<CardState>(_cardStateBoxName);
    _testRunBox = await Hive.openBox<TestRun>(_testRunBoxName);
    _attemptBox = await Hive.openBox<Attempt>(_attemptBoxName);
    _reviewEventBox = await Hive.openBox<ReviewEvent>(_reviewEventBoxName);
    _exposureEventBox = await Hive.openBox<ExposureEvent>(
      _exposureEventBoxName,
    );
    _learningItemStateBox = await Hive.openBox<String>(
      _learningItemStateBoxName,
    );
    _wordPreferenceBox = await Hive.openBox<String>(_wordPreferenceBoxName);
    await recoverPendingReviews();
  }

  @override
  Future<CardState?> getCardState(int wordId) async {
    return _cardStateBox.get(wordId);
  }

  @override
  Future<List<CardState>> getCardStates(List<int> wordIds) async {
    final List<CardState> result = [];
    for (final wordId in wordIds) {
      final state = _cardStateBox.get(wordId);
      if (state != null) {
        result.add(state);
      }
    }
    return result;
  }

  @override
  Future<void> saveCardState(CardState cardState) async {
    await _cardStateBox.put(cardState.wordId, cardState);
  }

  @override
  Future<void> batchUpdateCardStates(Map<int, CardState> states) async {
    await _cardStateBox.putAll(states);
  }

  @override
  Future<List<Word>> getDueWords(Set<String> levels) async {
    final now = DateTime.now();
    // 收集到期卡片及其逾期时间
    final dueEntries = <({int wordId, Duration overdue})>[];

    for (final state in _cardStateBox.values) {
      if (state.isDue) {
        dueEntries.add((
          wordId: state.wordId,
          overdue: now.difference(state.due),
        ));
      }
    }

    // 按逾期时间降序排列（最紧急的排最前）
    dueEntries.sort((a, b) => b.overdue.compareTo(a.overdue));

    final dueWordIds = dueEntries.map((e) => e.wordId).toList();

    // 获取对应的单词并过滤级别，保持排序顺序
    final words = await _wordRepository.getByIds(dueWordIds);
    final wordMap = {for (final w in words) w.id: w};
    return dueWordIds
        .where(
          (id) =>
              wordMap.containsKey(id) && levels.contains(wordMap[id]!.level),
        )
        .map((id) => wordMap[id]!)
        .toList();
  }

  @override
  Future<List<Word>> getLeechWords(Set<String> levels) async {
    return getLeechWordsWithPolicy(levels, LeechPolicy.defaultPolicy);
  }

  @override
  Future<List<Word>> getLeechWordsWithPolicy(
    Set<String> levels,
    LeechPolicy policy,
  ) async {
    final leechWordIds = <int>[];

    // 找出所有不熟单词
    for (final state in _cardStateBox.values) {
      if (policy.isLeech(state)) {
        leechWordIds.add(state.wordId);
      }
    }

    // 获取对应的单词并过滤级别
    final words = await _wordRepository.getByIds(leechWordIds);
    final filteredWords = words
        .where((word) => levels.contains(word.level))
        .toList();

    return filteredWords;
  }

  @override
  Future<void> resetWordProgress(int wordId) async {
    // 删除该单词的卡片状态，相当于重置为未学习状态
    await _cardStateBox.delete(wordId);
    final lexemeId = 'legacy:$wordId';
    final itemIds = <String>[];
    for (final encoded in _learningItemStateBox.values) {
      try {
        final state = LearningItemState.fromJson(
          Map<String, dynamic>.from(jsonDecode(encoded) as Map),
        );
        if (state.lexemeId == lexemeId) itemIds.add(state.itemId);
      } catch (_) {}
    }
    await _learningItemStateBox.deleteAll(itemIds);
  }

  @override
  Future<void> markWordKnown(int wordId) async {
    final now = DateTime.now();
    final currentState = _cardStateBox.get(wordId);
    final updatedState = CardState(
      wordId: wordId,
      stability: 20.0,
      difficulty: 1.6,
      due: now.add(const Duration(days: 30)),
      lapses: 0,
      rtP50: currentState?.rtP50 ?? 0,
      flags:
          ((currentState?.flags ?? 0) & ~CardState.difficultFlag) |
          CardState.manuallyKnownFlag,
      lastReview: now,
      // 手动标记不伪造跨日独立回忆次数；实际回忆后由调度器清除手动来源。
      longTermReviews: currentState?.longTermReviews ?? 0,
      revision: (currentState?.revision ?? 0) + 1,
    );
    await _cardStateBox.put(wordId, updatedState);
  }

  @override
  Future<void> markWordDifficult(int wordId) async {
    final currentState = _cardStateBox.get(wordId) ?? CardState.newCard(wordId);
    final markedState = currentState.markDifficult();
    await _cardStateBox.put(wordId, markedState);
  }

  @override
  Future<void> unmarkWordDifficult(int wordId) async {
    final currentState = _cardStateBox.get(wordId);
    if (currentState != null) {
      final unmarkedState = currentState.unmarkDifficult();
      await _cardStateBox.put(wordId, unmarkedState);
    }
  }

  @override
  Future<List<Word>> getNewWords(Set<String> levels, int limit) async {
    final allWords = await _wordRepository.loadByLevels(levels);
    final learnedWordIds = _cardStateBox.keys.cast<int>().toSet();

    // 过滤出未学过的单词
    final newWords = allWords
        .where((word) => !learnedWordIds.contains(word.id))
        .toList();

    // 限制数量
    if (newWords.length > limit) {
      newWords.shuffle();
      return newWords.take(limit).toList();
    }

    return newWords;
  }

  @override
  Future<void> saveTestRun(TestRun testRun) async {
    await _testRunBox.put(testRun.id, testRun);
    debugPrint('Saved TestRun ${testRun.id}, total runs=${_testRunBox.length}');
  }

  @override
  Future<List<WordStudyStatus>> getWordStatuses(Set<String> levels) async {
    final words = await _wordRepository.loadByLevels(levels);
    final result = <WordStudyStatus>[];

    final attemptCountsByWord = <int, int>{};
    for (final attempt in _attemptBox.values) {
      attemptCountsByWord.update(
        attempt.wordId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    for (final word in words) {
      final state = _cardStateBox.get(word.id);
      result.add(
        WordStudyStatus(
          word: word,
          state: state,
          attemptCount: attemptCountsByWord[word.id] ?? 0,
        ),
      );
    }

    return result;
  }

  @override
  Future<List<TestRun>> getTestRunHistory({int limit = 10}) async {
    final testRuns = _testRunBox.values.toList();
    testRuns.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return testRuns.take(limit).toList();
  }

  @override
  Future<TestRun?> getLatestTestRun() async {
    if (_testRunBox.isEmpty) return null;

    final testRuns = _testRunBox.values.toList();
    testRuns.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return testRuns.first;
  }

  @override
  Future<void> batchSaveAttempts(List<Attempt> attempts) async {
    if (attempts.isEmpty) return;
    final existingKeys = <String>{};
    for (final existing in _attemptBox.values) {
      existingKeys.add(_attemptStorageKey(existing));
    }
    final Map<String, Attempt> attemptMap = {};
    for (final attempt in attempts) {
      final key = _attemptStorageKey(attempt);
      if (existingKeys.contains(key) || attemptMap.containsKey(key)) continue;
      attemptMap[key] = attempt;
    }
    if (attemptMap.isEmpty) return;
    await _attemptBox.putAll(attemptMap);
    debugPrint(
      'Saved ${attempts.length} attempts, total attempts=${_attemptBox.length}',
    );
  }

  /// 以 pending -> state -> committed 的顺序写入一次回忆。
  /// Hive 没有跨 box 事务，因此 pending 事件本身就是可重放日志；
  /// 启动时 recoverPendingReviews 会补齐中断的第二步。
  @override
  Future<ReviewCommitResult> commitReview(ReviewEvent event) async {
    final existing = _reviewEventBox.get(event.id);
    if (existing != null && existing.isCommitted) {
      return ReviewCommitResult(
        state:
            existing.resultingItemState?.toCardState(
              existing.resultingState.wordId,
            ) ??
            existing.resultingState,
        alreadyCommitted: true,
      );
    }

    final itemState = event.resultingItemState;
    final current = _cardStateBox.get(event.resultingState.wordId);
    final currentItem = itemState == null
        ? null
        : await getLearningItemState(itemState.itemId);
    final currentRevision = itemState == null
        ? current?.revision ?? 0
        : currentItem?.revision ?? 0;
    final targetRevision = itemState?.revision ?? event.resultingState.revision;
    if (existing != null && currentRevision >= targetRevision) {
      final committed = existing.copyWith(status: 'committed');
      await _reviewEventBox.put(existing.id, committed);
      return ReviewCommitResult(
        state: itemState?.toCardState(event.resultingState.wordId) ?? current!,
        alreadyCommitted: true,
      );
    }
    if (currentRevision != event.beforeRevision && existing == null) {
      throw ReviewCommitConflict(
        'Card ${event.resultingState.wordId} changed from revision '
        '${event.beforeRevision} to $currentRevision before ${event.id} was committed',
      );
    }

    await _reviewEventBox.put(event.id, event.copyWith(status: 'pending'));
    // 能力级学习项拥有独立状态；不要把英文产出等证据写入旧的
    // meaningRecognition CardState 投影。
    if (itemState == null) {
      await _cardStateBox.put(
        event.resultingState.wordId,
        event.resultingState,
      );
    }
    if (itemState != null) {
      await saveLearningItemState(itemState);
    }
    final committed = event.copyWith(status: 'committed');
    await _reviewEventBox.put(event.id, committed);
    return ReviewCommitResult(
      state: committed.resultingState,
      alreadyCommitted: false,
    );
  }

  @override
  Future<void> recoverPendingReviews() async {
    for (final event in _reviewEventBox.values.where(
      (event) => !event.isCommitted,
    )) {
      final current = _cardStateBox.get(event.resultingState.wordId);
      if (event.resultingItemState == null &&
          (current == null ||
              current.revision < event.resultingState.revision)) {
        await _cardStateBox.put(
          event.resultingState.wordId,
          event.resultingState,
        );
      }
      if (event.resultingItemState != null) {
        await saveLearningItemState(event.resultingItemState!);
      }
      await _reviewEventBox.put(event.id, event.copyWith(status: 'committed'));
    }
  }

  @override
  Future<ReviewEvent?> getReviewEvent(String eventId) async =>
      _reviewEventBox.get(eventId);

  @override
  Future<List<ReviewEvent>> getReviewEvents({String? sessionId}) async {
    final events = _reviewEventBox.values
        .where((event) => sessionId == null || event.sessionId == sessionId)
        .toList();
    events.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return events;
  }

  @override
  Future<bool> recordExposure(ExposureEvent event) async {
    if (_exposureEventBox.containsKey(event.id)) return false;
    await _exposureEventBox.put(event.id, event);
    return true;
  }

  @override
  Future<bool> hasExposureForDate({
    required int wordId,
    required String localDate,
  }) async => _exposureEventBox.values.any(
    (event) => event.wordId == wordId && event.localDate == localDate,
  );

  @override
  Future<List<ExposureEvent>> getExposureEvents({String? sessionId}) async {
    final events = _exposureEventBox.values
        .where((event) => sessionId == null || event.sessionId == sessionId)
        .toList();
    events.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return events;
  }

  @override
  Future<LearningItemState?> getLearningItemState(String itemId) async {
    final encoded = _learningItemStateBox.get(itemId);
    if (encoded == null) return null;
    try {
      return LearningItemState.fromJson(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveLearningItemState(LearningItemState state) async {
    await _learningItemStateBox.put(state.itemId, jsonEncode(state.toJson()));
  }

  @override
  Future<List<LearningItemState>> getLearningItemStates({
    String? lexemeId,
  }) async {
    final states = <LearningItemState>[];
    for (final encoded in _learningItemStateBox.values) {
      try {
        final state = LearningItemState.fromJson(
          Map<String, dynamic>.from(jsonDecode(encoded) as Map),
        );
        if (lexemeId == null || state.lexemeId == lexemeId) states.add(state);
      } catch (_) {
        // A malformed optional item state must not hide recognition progress.
      }
    }
    states.sort((a, b) => a.itemId.compareTo(b.itemId));
    return states;
  }

  @override
  Future<UserWordPreference?> getWordPreference(String lexemeId) async {
    final encoded = _wordPreferenceBox.get(lexemeId);
    if (encoded == null) return null;
    try {
      return UserWordPreference.decode(encoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<UserWordPreference>> getWordPreferences() async {
    final result = <UserWordPreference>[];
    for (final encoded in _wordPreferenceBox.values) {
      try {
        result.add(UserWordPreference.decode(encoded));
      } catch (_) {}
    }
    result.sort((a, b) => a.lexemeId.compareTo(b.lexemeId));
    return result;
  }

  @override
  Future<void> saveWordPreference(UserWordPreference preference) async {
    await _wordPreferenceBox.put(preference.lexemeId, preference.encode());
  }

  @override
  Future<void> clearWordPreference(String lexemeId) async {
    await _wordPreferenceBox.delete(lexemeId);
  }

  String _attemptStorageKey(Attempt attempt) =>
      '${attempt.wordId}_${attempt.timestamp.microsecondsSinceEpoch}_'
      '${attempt.result.name}_${attempt.chosenIndex}_${attempt.correctIndex}';

  @override
  Future<List<Attempt>> getWordAttempts(int wordId, {int limit = 10}) async {
    final attempts = _attemptBox.values
        .where((attempt) => attempt.wordId == wordId)
        .toList();
    attempts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return attempts.take(limit).toList();
  }

  @override
  Future<Map<String, dynamic>> getLearningStats({
    LeechPolicy policy = LeechPolicy.defaultPolicy,
  }) async {
    final stats = <String, dynamic>{};

    // 卡片状态统计
    int totalCards = _cardStateBox.length;
    int dueCards = 0;
    int leechCards = 0;
    double avgStability = 0;
    double avgDifficulty = 0;
    double minStability = double.infinity;
    double maxStability = 0;
    int masteredCards = 0;

    if (totalCards > 0) {
      for (final state in _cardStateBox.values) {
        if (state.isDue) dueCards++;
        if (policy.isLeech(state)) leechCards++;
        avgStability += state.stability;
        avgDifficulty += state.difficulty;
        if (state.stability < minStability) minStability = state.stability;
        if (state.stability > maxStability) maxStability = state.stability;
        if (state.isMastered) masteredCards++;
      }
      avgStability /= totalCards;
      avgDifficulty /= totalCards;
    } else {
      minStability = 0;
    }

    // 测试统计
    final testRuns = _testRunBox.values.toList();
    final finishedRuns = testRuns.where((run) => run.isFinished).toList();
    debugPrint(
      'Stats boxes: cards=${_cardStateBox.length}, runs=${testRuns.length}, attempts=${_attemptBox.length}',
    );

    double weightedAccuracy = 0;
    int avgResponseTime = 0;
    int totalDurationMs = 0;

    if (finishedRuns.isNotEmpty) {
      // 计算加权准确率：总答对数 / 总答题数
      int totalCorrect = 0;
      int totalAttemptsCount = 0;

      for (final run in finishedRuns) {
        // 如果attempts列表可用
        if (run.attempts.isNotEmpty) {
          totalCorrect += run.attempts.where((a) => a.isCorrect).length;
          totalAttemptsCount += run.attempts.length;
        } else if (run.accuracy != null) {
          // 如果只有预计算的accuracy (兼容旧数据)
          // 估算：accuracy * size
          totalCorrect += (run.accuracy! * run.size).round();
          totalAttemptsCount += run.size;
        }

        // 累计每次测试的有效学习时长
        if (run.attempts.isNotEmpty) {
          final attempts = run.attempts.toList()
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
          final first = attempts.first.timestamp;
          final last = attempts.last.timestamp;
          totalDurationMs += last.difference(first).inMilliseconds;
        } else if (run.finishedAt != null) {
          totalDurationMs += run.finishedAt!
              .difference(run.startedAt)
              .inMilliseconds;
        }
      }

      if (totalAttemptsCount > 0) {
        weightedAccuracy = totalCorrect / totalAttemptsCount;
      }

      // 平均反应时间
      avgResponseTime =
          finishedRuns.map((run) => run.avgRtMs ?? 0).reduce((a, b) => a + b) ~/
          finishedRuns.length;
    }

    // 新流程以 ReviewEvent 为事实来源：只有到期且未看答案的独立回忆
    // 才进入留存率；旧库没有事件时继续使用兼容的轮次准确率。
    final committedEvents = _reviewEventBox.values
        .where((event) => event.isCommitted)
        .toList();
    final independentDueEvents = committedEvents
        .where((event) => event.isDueReview && event.independentRecall)
        .toList();
    final exposureEvents = _exposureEventBox.values.toList();
    final itemStates = await getLearningItemStates();
    final todayKey = _localDate(DateTime.now());
    final todayNewWordCount = exposureEvents
        .where((event) => event.localDate == todayKey)
        .map((event) => event.wordId)
        .toSet()
        .length;
    if (committedEvents.isNotEmpty) {
      final successful = committedEvents
          .where((event) => event.isSuccessful)
          .length;
      weightedAccuracy = successful / committedEvents.length;
    }
    final retentionRate = independentDueEvents.isEmpty
        ? weightedAccuracy
        : independentDueEvents.where((event) => event.isSuccessful).length /
              independentDueEvents.length;

    // 兜底：若跨度为 0 但有答题记录，则用答题耗时估算
    int attemptDurationSum = 0;
    if (totalDurationMs == 0 && _attemptBox.isNotEmpty) {
      attemptDurationSum = _attemptBox.values.fold(
        0,
        (sum, attempt) => sum + attempt.rtMs,
      );
      totalDurationMs = attemptDurationSum;
    }

    // 计算连续学习天数 (使用优化后的宽松算法)
    int streakDays = _calculateStreakDays(testRuns);

    debugPrint(
      'Learning stats detail: totalCards=$totalCards mastered=$masteredCards '
      'retention=${(retentionRate * 100).toStringAsFixed(1)} '
      'stability(min=$minStability,max=$maxStability)',
    );
    debugPrint(
      'Learning duration: totalMs=$totalDurationMs '
      'attemptSum=$attemptDurationSum attempts=${_attemptBox.length}',
    );
    if (totalDurationMs == 0 && _attemptBox.isNotEmpty) {
      final samples = _attemptBox.values.take(3).map((a) => a.rtMs).toList();
      debugPrint('Sample attempt rtMs: $samples');
    }

    stats.addAll({
      'totalCards': totalCards,
      'dueCards': dueCards,
      'leechCards': leechCards,
      'masteredCards': masteredCards,
      'manuallyKnownCards': _cardStateBox.values
          .where((state) => state.isManuallyKnown)
          .length,
      'retentionRate': retentionRate,
      'avgStability': avgStability,
      'avgDifficulty': avgDifficulty,
      'totalTestRuns': testRuns.length,
      'finishedTestRuns': finishedRuns.length,
      'avgAccuracy': weightedAccuracy, // 使用加权准确率
      'avgResponseTime': avgResponseTime,
      'totalDurationMinutes': totalDurationMs ~/ 60000, // 总时长(分)
      'totalDurationMs': totalDurationMs,
      'totalAttempts': _attemptBox.length,
      'reviewEventCount': committedEvents.length,
      'exposureCount': exposureEvents.length,
      'learningItemCount': itemStates.length,
      'learningItemDueCount': itemStates
          .where((state) => !state.dueAt.isAfter(DateTime.now()))
          .length,
      'learningItemMasteredCount': itemStates
          .where((state) => state.isMastered)
          .length,
      'todayNewWordCount': todayNewWordCount,
      'independentDueReviewCount': independentDueEvents.length,
      'independentDueSuccessCount': independentDueEvents
          .where((event) => event.isSuccessful)
          .length,
      'streakDays': streakDays,
      ...MemoryAnalytics.summarize(committedEvents),
    });

    return stats;
  }

  String _localDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// 获取指定天数的每日统计数据
  @override
  Future<List<Map<String, dynamic>>> getDailyStats(int days) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = today.subtract(Duration(days: days - 1));

    // 初始化结果列表（填入0值）
    final statsList = List<Map<String, dynamic>>.generate(days, (index) {
      final date = startDate.add(Duration(days: index));
      return {
        'date': date,
        'durationMs': 0,
        'accuracy': 0.0,
        'count': 0,
        'totalAttempts': 0,
        'correctAttempts': 0,
      };
    });

    // 获取测试记录
    final testRuns = _testRunBox.values.toList();

    // 遍历记录并聚合
    for (final run in testRuns) {
      // 1. 只统计已完成的测试 (run.isFinished)
      if (!run.isFinished) continue;

      // 2. 只统计开始时间在范围内的记录
      if (run.startedAt.isBefore(startDate)) continue;

      final runDate = DateTime(
        run.startedAt.year,
        run.startedAt.month,
        run.startedAt.day,
      );

      final dayIndex = runDate.difference(startDate).inDays;
      if (dayIndex < 0 || dayIndex >= days) continue;

      var stats = statsList[dayIndex];
      stats['count'] = (stats['count'] as int) + 1;

      if (run.finishedAt != null) {
        final duration = run.finishedAt!
            .difference(run.startedAt)
            .inMilliseconds;
        stats['durationMs'] = (stats['durationMs'] as int) + duration;
      }

      // 累计答题正确数
      if (run.attempts.isNotEmpty) {
        final correct = run.attempts.where((a) => a.isCorrect).length;
        stats['correctAttempts'] = (stats['correctAttempts'] as int) + correct;
        stats['totalAttempts'] =
            (stats['totalAttempts'] as int) + run.attempts.length;
      } else if (run.isFinished && run.accuracy != null) {
        // 兼容旧数据
        final total = run.size;
        final correct = (run.accuracy! * total).round();
        stats['correctAttempts'] = (stats['correctAttempts'] as int) + correct;
        stats['totalAttempts'] = (stats['totalAttempts'] as int) + total;
      }
    }

    // 计算最终准确率
    for (var stats in statsList) {
      final total = stats['totalAttempts'] as int;
      if (total > 0) {
        stats['accuracy'] = (stats['correctAttempts'] as int) / total;
      }
    }

    return statsList;
  }

  /// 获取指定级别的进度
  @override
  Future<Map<String, int>> getLevelProgress(Set<String> levels) async {
    // 1. 获取级别总词数
    final allWords = await _wordRepository.loadByLevels(levels);
    final total = allWords.length;
    final levelSet = levels.isEmpty
        ? allWords.map((w) => w.level).toSet()
        : levels;

    // 2. 获取已学和掌握的词数
    int learned = 0;
    int mastered = 0;

    // 建立ID集合以快速查找
    final targetWordIds = allWords.map((w) => w.id).toSet();

    for (final state in _cardStateBox.values) {
      if (targetWordIds.contains(state.wordId)) {
        learned++;
        if (state.isMastered) {
          mastered++;
        }
      }
    }

    if (learned == 0 && _attemptBox.isNotEmpty) {
      final learnedIds = <int>{};
      final masteredIds = <int>{};
      for (final attempt in _attemptBox.values) {
        learnedIds.add(attempt.wordId);
        if (attempt.isCorrect) {
          masteredIds.add(attempt.wordId);
        }
      }
      learned = learnedIds.length;
      mastered = masteredIds.length;
    }

    if (total == 0 && _attemptBox.isNotEmpty) {
      final attemptedIds = _attemptBox.values.map((a) => a.wordId).toSet();
      final attemptedWords = await _wordRepository.getByIds(
        attemptedIds.toList(),
      );
      final filtered = attemptedWords.where((w) => levelSet.contains(w.level));
      final attemptedTotal = filtered.length;
      return {
        'total': attemptedTotal,
        'learned': learned,
        'mastered': mastered,
        'notStarted': attemptedTotal - learned,
      };
    }

    return {
      'total': total,
      'learned': learned,
      'mastered': mastered,
      'notStarted': total - learned,
    };
  }

  /// 计算连续学习天数
  int _calculateStreakDays(List<TestRun> testRuns) {
    if (testRuns.isEmpty) return 0;

    // 按日期分组（只考虑日期，不考虑时间）
    final daySet = <String>{};
    for (final run in testRuns) {
      // 优化：只要开始了测试就算打卡，不要求必须 finished
      // 这更能鼓励用户，防止因意外中断导致断签
      final dateStr = run.startedAt.toIso8601String().substring(0, 10);
      daySet.add(dateStr);
    }

    if (daySet.isEmpty) return 0;

    // 转换为日期列表并排序
    final dates = daySet.map((str) => DateTime.parse(str)).toList();
    dates.sort((a, b) => b.compareTo(a)); // 降序排列

    // 计算连续天数
    int streak = 0;
    DateTime? lastDate;

    for (final date in dates) {
      if (lastDate == null) {
        // 第一天
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final currentDate = DateTime(date.year, date.month, date.day);

        // 如果不是今天或昨天，连续天数为0
        final daysDiff = todayDate.difference(currentDate).inDays;
        if (daysDiff > 1) break;

        streak = 1;
        lastDate = date;
      } else {
        // 检查是否连续
        final daysDiff = lastDate.difference(date).inDays;
        if (daysDiff == 1) {
          streak++;
          lastDate = date;
        } else {
          break;
        }
      }
    }

    return streak;
  }

  @override
  Future<void> clearAllProgress() async {
    await _cardStateBox.clear();
    await _testRunBox.clear();
    await _attemptBox.clear();
    await _reviewEventBox.clear();
    await _exposureEventBox.clear();
    await _learningItemStateBox.clear();
    await _wordPreferenceBox.clear();
  }

  @override
  Future<void> clearTestRuns() async {
    await _testRunBox.clear();
  }

  @override
  Future<void> clearAttempts() async {
    await _attemptBox.clear();
    await _reviewEventBox.clear();
    await _exposureEventBox.clear();
  }

  @override
  Future<void> clearCardStates() async {
    await _cardStateBox.clear();
    await _learningItemStateBox.clear();
  }

  /// 对全部 box 做一次浅拷贝快照，用于导入失败时回滚。
  Map<String, Map<dynamic, dynamic>> _snapshotBoxes() => {
    'cardStates': _cardStateBox.toMap(),
    'testRuns': _testRunBox.toMap(),
    'attempts': _attemptBox.toMap(),
    'reviewEvents': _reviewEventBox.toMap(),
    'exposureEvents': _exposureEventBox.toMap(),
    'learningItemStates': _learningItemStateBox.toMap(),
    'wordPreferences': _wordPreferenceBox.toMap(),
  };

  /// 用快照覆盖全部 box，把状态还原到导入之前。
  Future<void> _restoreBoxes(
    Map<String, Map<dynamic, dynamic>> snapshot,
  ) async {
    Future<void> restore<T>(Box<T> box, String key) async {
      await box.clear();
      final values = snapshot[key];
      if (values != null && values.isNotEmpty) {
        await box.putAll(Map<dynamic, T>.from(values));
      }
    }

    await restore(_cardStateBox, 'cardStates');
    await restore(_testRunBox, 'testRuns');
    await restore(_attemptBox, 'attempts');
    await restore(_reviewEventBox, 'reviewEvents');
    await restore(_exposureEventBox, 'exposureEvents');
    await restore(_learningItemStateBox, 'learningItemStates');
    await restore(_wordPreferenceBox, 'wordPreferences');
  }

  @override
  Future<Map<String, dynamic>> exportProgress() async {
    return {
      'version': _exportVersion,
      'cardStates': _cardStateBox.values
          .map((state) => state.toJson())
          .toList(),
      'testRuns': _testRunBox.values.map((run) => run.toJson()).toList(),
      'attempts': _attemptBox.values
          .map((attempt) => attempt.toJson())
          .toList(),
      'reviewEvents': _reviewEventBox.values
          .map((event) => event.toJson())
          .toList(),
      'exposureEvents': _exposureEventBox.values
          .map((event) => event.toJson())
          .toList(),
      'learningItemStates': (await getLearningItemStates())
          .map((state) => state.toJson())
          .toList(),
      'wordPreferences': (await getWordPreferences())
          .map((preference) => preference.toJson())
          .toList(),
      'exportTime': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<void> importProgress(Map<String, dynamic> data) async {
    final version = data['version'] is int ? data['version'] as int : 0;
    if (version > _exportVersion) {
      debugPrint(
        'Warning: import data version $version is newer than supported $_exportVersion',
      );
    }
    // Hive 没有事务语义：先对全部 box 做内存快照，任何一步失败都整体回滚，
    // 避免出现「数据已清空、新数据只写入一半」的不可逆结果。
    final snapshot = _snapshotBoxes();
    try {
      await clearAllProgress();
      await _writeImportedProgress(data);
    } catch (error) {
      debugPrint('Progress import failed, rolling back: $error');
      try {
        await _restoreBoxes(snapshot);
      } catch (restoreError) {
        debugPrint('Progress import rollback failed: $restoreError');
      }
      rethrow;
    }
  }

  /// 把导出负载写入各 box。失败时由 [importProgress] 负责回滚。
  Future<void> _writeImportedProgress(Map<String, dynamic> data) async {
    // 导入卡片状态
    if (data['cardStates'] != null) {
      final states = (data['cardStates'] as List)
          .map((json) => CardState.fromJson(json))
          .toList();
      final stateMap = {for (var state in states) state.wordId: state};
      await _cardStateBox.putAll(stateMap);
    }

    // 导入测试记录
    if (data['testRuns'] != null) {
      final runs = (data['testRuns'] as List)
          .map((json) => TestRun.fromJson(json))
          .toList();
      final runMap = {for (var run in runs) run.id: run};
      await _testRunBox.putAll(runMap);
    }

    // 导入答题记录
    if (data['attempts'] != null) {
      final attempts = (data['attempts'] as List)
          .map((json) => Attempt.fromJson(json))
          .toList();
      await batchSaveAttempts(attempts);
    }

    if (data['reviewEvents'] != null) {
      final events = (data['reviewEvents'] as List).map(
        (json) => ReviewEvent.fromJson(Map<String, dynamic>.from(json as Map)),
      );
      await _reviewEventBox.putAll({
        for (final event in events) event.id: event,
      });
      await recoverPendingReviews();
    }

    if (data['exposureEvents'] != null) {
      final events = (data['exposureEvents'] as List).map(
        (json) =>
            ExposureEvent.fromJson(Map<String, dynamic>.from(json as Map)),
      );
      await _exposureEventBox.putAll({
        for (final event in events) event.id: event,
      });
    }

    if (data['learningItemStates'] != null) {
      for (final raw in (data['learningItemStates'] as List)) {
        final state = LearningItemState.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        await saveLearningItemState(state);
      }
    }

    if (data['wordPreferences'] != null) {
      for (final raw in (data['wordPreferences'] as List)) {
        final preference = UserWordPreference.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        await saveWordPreference(preference);
      }
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await _cardStateBox.close();
    await _testRunBox.close();
    await _attemptBox.close();
    await _reviewEventBox.close();
    await _exposureEventBox.close();
    await _learningItemStateBox.close();
    await _wordPreferenceBox.close();
  }
}
