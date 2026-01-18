import 'package:hive/hive.dart';
import '../models/models.dart';
import 'progress_repository.dart';
import 'word_repository.dart';

/// Hive实现的进度仓储
class HiveProgressRepository implements ProgressRepository {
  static const String _cardStateBoxName = 'card_states';
  static const String _testRunBoxName = 'test_runs';
  static const String _attemptBoxName = 'attempts';

  late Box<CardState> _cardStateBox;
  late Box<TestRun> _testRunBox;
  late Box<Attempt> _attemptBox;

  final WordRepository _wordRepository;

  HiveProgressRepository(this._wordRepository);

  /// 初始化
  Future<void> init() async {
    // 注册适配器
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(AttemptAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CardStateAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(TestRunAdapter());
    if (!Hive.isAdapterRegistered(4))
      Hive.registerAdapter(AttemptResultAdapter());
    if (!Hive.isAdapterRegistered(5))
      Hive.registerAdapter(DelayProfileAdapter());
    if (!Hive.isAdapterRegistered(6))
      Hive.registerAdapter(AppSettingsAdapter());

    // 打开boxes
    _cardStateBox = await Hive.openBox<CardState>(_cardStateBoxName);
    _testRunBox = await Hive.openBox<TestRun>(_testRunBoxName);
    _attemptBox = await Hive.openBox<Attempt>(_attemptBoxName);
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
      } else {
        // 如果没有状态，创建新的
        result.add(CardState.newCard(wordId));
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
    final dueWordIds = <int>[];

    // 找出所有到期的卡片
    for (final state in _cardStateBox.values) {
      if (state.isDue) {
        dueWordIds.add(state.wordId);
      }
    }

    // 获取对应的单词并过滤级别
    final words = await _wordRepository.getByIds(dueWordIds);
    return words.where((word) => levels.contains(word.level)).toList();
  }

  @override
  Future<List<Word>> getLeechWords(Set<String> levels) async {
    final leechWordIds = <int>[];

    // 找出所有不熟单词
    for (final state in _cardStateBox.values) {
      if (state.isLeech) {
        leechWordIds.add(state.wordId);
      }
    }

    // 获取对应的单词并过滤级别
    final words = await _wordRepository.getByIds(leechWordIds);
    final filteredWords = words
        .where((word) => levels.contains(word.level))
        .toList();

    // 如果不熟悉单词太少，可以考虑包含一些答错过的单词
    if (filteredWords.length < 10) {
      final allWords = await _wordRepository.loadByLevels(levels);
      final additionalWords = <Word>[];

      for (final word in allWords) {
        if (filteredWords.any((w) => w.id == word.id)) continue;

        final state = _cardStateBox.get(word.id);
        if (state != null && state.lapses > 0) {
          additionalWords.add(word);
        }
      }

      filteredWords.addAll(additionalWords.take(20 - filteredWords.length));
    }

    return filteredWords;
  }

  @override
  Future<void> resetWordProgress(int wordId) async {
    // 删除该单词的卡片状态，相当于重置为未学习状态
    await _cardStateBox.delete(wordId);
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
  }

  @override
  Future<List<WordStudyStatus>> getWordStatuses(Set<String> levels) async {
    final words = await _wordRepository.loadByLevels(levels);
    final result = <WordStudyStatus>[];

    for (final word in words) {
      final state = _cardStateBox.get(word.id);
      final attempts = _attemptBox.values.where((a) => a.wordId == word.id);
      result.add(
        WordStudyStatus(
          word: word,
          state: state,
          attemptCount: attempts.length,
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
    final Map<String, Attempt> attemptMap = {};
    for (int i = 0; i < attempts.length; i++) {
      attemptMap['${attempts[i].wordId}_${attempts[i].timestamp.millisecondsSinceEpoch}_$i'] =
          attempts[i];
    }
    await _attemptBox.putAll(attemptMap);
  }

  @override
  Future<List<Attempt>> getWordAttempts(int wordId, {int limit = 10}) async {
    final attempts = _attemptBox.values
        .where((attempt) => attempt.wordId == wordId)
        .toList();
    attempts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return attempts.take(limit).toList();
  }

  @override
  Future<Map<String, dynamic>> getLearningStats() async {
    final stats = <String, dynamic>{};

    // 卡片状态统计
    int totalCards = _cardStateBox.length;
    int dueCards = 0;
    int leechCards = 0;
    double avgStability = 0;
    double avgDifficulty = 0;

    if (totalCards > 0) {
      for (final state in _cardStateBox.values) {
        if (state.isDue) dueCards++;
        if (state.isLeech) leechCards++;
        avgStability += state.stability;
        avgDifficulty += state.difficulty;
      }
      avgStability /= totalCards;
      avgDifficulty /= totalCards;
    }

    // 测试统计
    final testRuns = _testRunBox.values.toList();
    final finishedRuns = testRuns.where((run) => run.isFinished).toList();

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
        
        // 计算总时长
        if (run.finishedAt != null) {
          totalDurationMs += run.finishedAt!.difference(run.startedAt).inMilliseconds;
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
    
    // 计算留存率 (Mastery Rate)：稳定度 > 21天的单词比例
    double retentionRate = 0;
    int masteredCards = 0;
    if (totalCards > 0) {
      for (final state in _cardStateBox.values) {
        if (state.stability > 21) {
          masteredCards++;
        }
      }
      retentionRate = masteredCards / totalCards;
    }

    // 计算连续学习天数 (使用优化后的宽松算法)
    int streakDays = _calculateStreakDays(testRuns);

    stats.addAll({
      'totalCards': totalCards,
      'dueCards': dueCards,
      'leechCards': leechCards,
      'masteredCards': masteredCards,
      'retentionRate': retentionRate,
      'avgStability': avgStability,
      'avgDifficulty': avgDifficulty,
      'totalTestRuns': testRuns.length,
      'finishedTestRuns': finishedRuns.length,
      'avgAccuracy': weightedAccuracy, // 使用加权准确率
      'avgResponseTime': avgResponseTime,
      'totalDurationMinutes': totalDurationMs ~/ 60000, // 总时长(分)
      'totalAttempts': _attemptBox.length,
      'streakDays': streakDays,
    });

    return stats;
  }

  /// 获取指定天数的每日统计数据
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
         final duration = run.finishedAt!.difference(run.startedAt).inMilliseconds;
         stats['durationMs'] = (stats['durationMs'] as int) + duration;
      }
      
      // 累计答题正确数
      if (run.attempts.isNotEmpty) {
        final correct = run.attempts.where((a) => a.isCorrect).length;
        stats['correctAttempts'] = (stats['correctAttempts'] as int) + correct;
        stats['totalAttempts'] = (stats['totalAttempts'] as int) + run.attempts.length;
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
  Future<Map<String, int>> getLevelProgress(Set<String> levels) async {
    // 1. 获取级别总词数
    final allWords = await _wordRepository.loadByLevels(levels);
    final total = allWords.length;
    
    // 2. 获取已学和掌握的词数
    int learned = 0;
    int mastered = 0;
    
    // 建立ID集合以快速查找
    final targetWordIds = allWords.map((w) => w.id).toSet();
    
    for (final state in _cardStateBox.values) {
      if (targetWordIds.contains(state.wordId)) {
        learned++;
        if (state.stability > 16) {
          mastered++;
        }
      }
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
  }

  @override
  Future<Map<String, dynamic>> exportProgress() async {
    return {
      'cardStates': _cardStateBox.values
          .map((state) => state.toJson())
          .toList(),
      'testRuns': _testRunBox.values.map((run) => run.toJson()).toList(),
      'attempts': _attemptBox.values
          .map((attempt) => attempt.toJson())
          .toList(),
      'exportTime': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<void> importProgress(Map<String, dynamic> data) async {
    await clearAllProgress();

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
  }

  /// 释放资源
  Future<void> dispose() async {
    await _cardStateBox.close();
    await _testRunBox.close();
    await _attemptBox.close();
  }
}
