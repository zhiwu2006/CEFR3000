import '../models/models.dart';
import '../data/progress_repository.dart';
import '../data/review_commit_repository.dart';
import '../data/word_repository.dart';
import '../domain/srs.dart';

/// 每日测试历史与重点单词分析服务
class DailyHistoryService {
  final ProgressRepository _progressRepository;
  final WordRepository _wordRepository;
  final LeechPolicy leechPolicy;
  final double slowThresholdMultiplier;

  DailyHistoryService({
    required ProgressRepository progressRepository,
    required WordRepository wordRepository,
    this.leechPolicy = LeechPolicy.defaultPolicy,
    this.slowThresholdMultiplier = 1.5,
  }) : _progressRepository = progressRepository,
       _wordRepository = wordRepository;

  /// 获取按天归档的学习历史汇总列表（默认取最近 maxDays 天）
  Future<List<DailyHistorySummary>> getDailySummaries({
    int maxDays = 30,
  }) async {
    final reviewRepository = _progressRepository is ReviewCommitRepository
        ? _progressRepository as ReviewCommitRepository
        : null;
    if (reviewRepository != null) {
      final events = (await reviewRepository.getReviewEvents())
          .where((event) => event.isCommitted)
          .toList();
      if (events.isNotEmpty) {
        final legacyRuns = await _progressRepository.getTestRunHistory(
          limit: 500,
        );
        final eventAttemptKeys = events
            .map((event) => _attemptKey(event.attempt))
            .toSet();
        return _summariesFromRuns([
          ..._testRunsFromReviewEvents(events),
          ..._removeProjectedAttempts(legacyRuns, eventAttemptKeys),
        ], maxDays: maxDays);
      }
    }

    final runs = await _progressRepository.getTestRunHistory(limit: 500);
    return _summariesFromRuns(runs, maxDays: maxDays);
  }

  /// 统一的历史投影逻辑。新流程用 ReviewEvent 合成只读轮次容器，
  /// 因而未完成会话的已提交回忆也会出现在历史中；旧库仍使用原有 TestRun。
  Future<List<DailyHistorySummary>> _summariesFromRuns(
    List<TestRun> runs, {
    required int maxDays,
  }) async {
    final finishedRuns = runs.where((r) => r.isFinished).toList();
    if (finishedRuns.isEmpty) {
      return [];
    }

    // 1. 按自然日分组 (年-月-日)
    final Map<DateTime, List<TestRun>> runsByDate = {};
    for (final run in finishedRuns) {
      final dateKey = DateTime(
        run.startedAt.year,
        run.startedAt.month,
        run.startedAt.day,
      );
      runsByDate.putIfAbsent(dateKey, () => []).add(run);
    }

    // 按日期倒序排列（最近的日期在最前）
    final sortedDates = runsByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final limitedDates = sortedDates.take(maxDays).toList();
    final List<DailyHistorySummary> summaries = [];

    // 预先缓存所有单词实体与卡片状态，提高处理性能
    final Map<int, Word?> wordCache = {};
    final Map<int, CardState?> cardStateCache = {};

    for (final date in limitedDates) {
      final dayRuns = runsByDate[date]!;
      // 当天轮次按开始时间升序排列（第1轮、第2轮...）
      dayRuns.sort((a, b) => a.startedAt.compareTo(b.startedAt));

      int totalWordsTested = 0;
      int totalDurationMs = 0;
      int totalAttemptsCount = 0;
      int totalCorrectCount = 0;

      // 统计当日所有 attempts 以提炼重点单词
      final Map<int, List<Attempt>> attemptsByWord = {};
      final Map<String, int> attemptTimeLimits = {};
      final List<SessionRunSummary> sessionSummaries = [];

      for (final run in dayRuns) {
        final totalQuestions = run.attempts.isNotEmpty
            ? run.attempts.length
            : run.size;
        final correctCount = run.attempts.where((a) => a.isCorrect).length;
        final wrongCount = run.attempts
            .where((a) => a.isWrong || a.isTimeout)
            .length;
        final accuracy = totalQuestions > 0
            ? correctCount / totalQuestions
            : 0.0;
        final avgRtMs = run.avgRtMs ?? run.calculateAvgRt();

        totalWordsTested += totalQuestions;
        totalAttemptsCount += totalQuestions;
        totalCorrectCount += correctCount;

        if (run.finishedAt != null) {
          totalDurationMs += run.finishedAt!
              .difference(run.startedAt)
              .inMilliseconds;
        }

        // 收集该轮中属于重点词的数量
        int runFocusCount = 0;
        for (final attempt in run.attempts) {
          if (attempt.wordId <= 0) continue;
          attemptsByWord.putIfAbsent(attempt.wordId, () => []).add(attempt);
          attemptTimeLimits[_attemptKey(attempt)] = run.timeLimitMs;
          if (attempt.isWrong ||
              attempt.isTimeout ||
              SrsAlgorithm.calculateQuality(
                    result: attempt.result,
                    reactionTime: attempt.rtMs,
                    timeLimit: run.timeLimitMs,
                    slowThresholdMultiplier: slowThresholdMultiplier,
                  ) ==
                  3) {
            runFocusCount++;
          }
        }

        sessionSummaries.add(
          SessionRunSummary(
            id: run.id,
            startedAt: run.startedAt,
            finishedAt: run.finishedAt,
            totalQuestions: totalQuestions,
            correctCount: correctCount,
            wrongCount: wrongCount,
            accuracy: accuracy,
            avgRtMs: avgRtMs,
            timeLimitMs: run.timeLimitMs,
            levels: run.levels,
            focusWordCount: runFocusCount,
          ),
        );
      }

      // 计算重点单词 FocusScore
      final List<FocusWordItem> focusWords = [];
      for (final entry in attemptsByWord.entries) {
        final wordId = entry.key;
        final attempts = entry.value;

        // 缓存加载 Word
        if (!wordCache.containsKey(wordId)) {
          wordCache[wordId] = await _wordRepository.getById(wordId);
        }
        final word = wordCache[wordId];
        if (word == null) continue;

        // 缓存加载 CardState
        if (!cardStateCache.containsKey(wordId)) {
          cardStateCache[wordId] = await _progressRepository.getCardState(
            wordId,
          );
        }
        final cardState = cardStateCache[wordId];

        final reasons = <FocusWordReason>{};
        int score = 0;
        int maxRtMs = 0;
        int wrongOrTimeoutCount = 0;

        for (final att in attempts) {
          if (att.rtMs > maxRtMs) {
            maxRtMs = att.rtMs;
          }
          if (att.isWrong) {
            reasons.add(FocusWordReason.wrong);
            score += 100;
            wrongOrTimeoutCount++;
          } else if (att.isTimeout) {
            reasons.add(FocusWordReason.timeout);
            score += 90;
            wrongOrTimeoutCount++;
          } else if (att.isCorrect &&
              SrsAlgorithm.calculateQuality(
                    result: att.result,
                    reactionTime: att.rtMs,
                    timeLimit: attemptTimeLimits[_attemptKey(att)] ?? 2000,
                    slowThresholdMultiplier: slowThresholdMultiplier,
                  ) ==
                  3) {
            // 迟疑答对 (默认反应时间 >= 1.5s 视为高检索努力)
            reasons.add(FocusWordReason.hesitation);
            score += 50;
          }
        }

        // 跨轮多次出错
        if (wrongOrTimeoutCount >= 2) {
          reasons.add(FocusWordReason.frequentFail);
          score += 60;
        }

        // FSRS 历史难词 / 失忆标记
        if (cardState != null && leechPolicy.isLeech(cardState)) {
          reasons.add(FocusWordReason.leech);
          score += 30;
        }

        // 达到重点词阈值（Score >= 50）即纳入重点池
        if (score >= 50 || reasons.isNotEmpty) {
          focusWords.add(
            FocusWordItem(
              word: word,
              focusScore: score,
              reasons: reasons,
              reactionTimeMs: maxRtMs,
              lapses: cardState?.lapses,
              stability: cardState?.stability,
            ),
          );
        }
      }

      // 按重点分 FocusScore 降序排列
      focusWords.sort((a, b) => b.focusScore.compareTo(a.focusScore));

      final averageAccuracy = totalAttemptsCount > 0
          ? totalCorrectCount / totalAttemptsCount
          : 0.0;

      summaries.add(
        DailyHistorySummary(
          date: date,
          sessions: sessionSummaries.reversed
              .toList(), // 界面展示通常按从早到晚或从晚到早，此处列表倒序让最新的在最上
          totalWordsTested: totalWordsTested,
          averageAccuracy: averageAccuracy,
          totalDurationMs: totalDurationMs,
          focusWords: focusWords,
        ),
      );
    }

    return summaries;
  }

  List<TestRun> _testRunsFromReviewEvents(List<ReviewEvent> events) {
    final grouped = <String, List<ReviewEvent>>{};
    for (final event in events) {
      final date = event.localDate.isEmpty
          ? DateTime(
              event.createdAt.year,
              event.createdAt.month,
              event.createdAt.day,
            )
          : DateTime.tryParse(event.localDate) ??
                DateTime(
                  event.createdAt.year,
                  event.createdAt.month,
                  event.createdAt.day,
                );
      final dateKey =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent('${event.sessionId}:$dateKey', () => []).add(event);
    }

    final runs = <TestRun>[];
    for (final entry in grouped.entries) {
      final dayEvents = entry.value.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (dayEvents.isEmpty) continue;
      final first = dayEvents.first;
      final last = dayEvents.last;
      final lastDuration = last.activeDurationMs > 0
          ? last.activeDurationMs
          : last.attempt.rtMs;
      var run = TestRun.create(
        id: 'events:${entry.key}',
        size: dayEvents.length,
        levels: const {},
        timeLimitMs: first.timeLimitMs,
        orderPolicy: 'event_projection',
        onlyLeeches: false,
      );
      for (final event in dayEvents) {
        run = run.addAttempt(event.attempt);
      }
      runs.add(
        run.finish().copyWith(
          startedAt: first.createdAt,
          finishedAt: last.createdAt.add(Duration(milliseconds: lastDuration)),
        ),
      );
    }
    return runs;
  }

  List<TestRun> _removeProjectedAttempts(
    List<TestRun> runs,
    Set<String> eventAttemptKeys,
  ) {
    final result = <TestRun>[];
    for (final run in runs) {
      if (run.attempts.isEmpty) {
        result.add(run);
        continue;
      }
      final remaining = run.attempts
          .where((attempt) => !eventAttemptKeys.contains(_attemptKey(attempt)))
          .toList();
      if (remaining.isEmpty) continue;
      if (remaining.length == run.attempts.length) {
        result.add(run);
        continue;
      }

      var rebuilt = TestRun.create(
        id: run.id,
        size: remaining.length,
        levels: run.levels.toSet(),
        timeLimitMs: run.timeLimitMs,
        orderPolicy: run.orderPolicy,
        onlyLeeches: run.onlyLeeches,
      ).copyWith(startedAt: run.startedAt);
      for (final attempt in remaining) {
        rebuilt = rebuilt.addAttempt(attempt);
      }
      result.add(
        run.isFinished
            ? rebuilt.finish().copyWith(
                startedAt: run.startedAt,
                finishedAt: run.finishedAt,
              )
            : rebuilt,
      );
    }
    return result;
  }

  String _attemptKey(Attempt attempt) =>
      '${attempt.wordId}:${attempt.timestamp.microsecondsSinceEpoch}:'
      '${attempt.result.name}:${attempt.chosenIndex}:${attempt.correctIndex}';

  /// 注入演示测试历史数据（用于冷启动一键体验与看板全景评审）
  Future<void> seedDemoHistoryData() async {
    final now = DateTime.now();
    final words = await _wordRepository.loadAll();
    if (words.length < 5) return;

    // 轮次 1：今天上午 - 包含错题、超时、迟疑
    final run1Id = 'demo-run-${now.millisecondsSinceEpoch}-1';
    final run1Time = now.subtract(const Duration(minutes: 35));
    final attempts1 = [
      Attempt(
        wordId: words[0].id,
        chosenIndex: 1,
        correctIndex: 2,
        rtMs: 1800,
        result: AttemptResult.wrong,
        timestamp: run1Time,
      ),
      Attempt(
        wordId: words[1].id,
        chosenIndex: -1,
        correctIndex: 0,
        rtMs: 5000,
        result: AttemptResult.timeout,
        timestamp: run1Time.add(const Duration(seconds: 6)),
      ),
      Attempt(
        wordId: words[2].id,
        chosenIndex: 1,
        correctIndex: 1,
        rtMs: 2300,
        result: AttemptResult.correct,
        timestamp: run1Time.add(const Duration(seconds: 12)),
      ),
      Attempt(
        wordId: words[3].id,
        chosenIndex: 0,
        correctIndex: 0,
        rtMs: 700,
        result: AttemptResult.correct,
        timestamp: run1Time.add(const Duration(seconds: 15)),
      ),
    ];

    var run1 = TestRun.create(
      id: run1Id,
      size: 4,
      levels: {'A1'},
      timeLimitMs: 5000,
      orderPolicy: 'by_level',
      onlyLeeches: false,
    );
    for (final a in attempts1) {
      run1 = run1.addAttempt(a);
    }
    run1 = run1.finish().copyWith(
      startedAt: run1Time,
      finishedAt: run1Time.add(const Duration(seconds: 20)),
    );

    // 轮次 2：今天早些时候 - 制造 words[0] 多轮连错
    final run2Id = 'demo-run-${now.millisecondsSinceEpoch}-2';
    final run2Time = now.subtract(const Duration(hours: 3));
    final attempts2 = [
      Attempt(
        wordId: words[0].id,
        chosenIndex: 3,
        correctIndex: 2,
        rtMs: 1400,
        result: AttemptResult.wrong,
        timestamp: run2Time,
      ),
      Attempt(
        wordId: words[4].id,
        chosenIndex: 1,
        correctIndex: 1,
        rtMs: 850,
        result: AttemptResult.correct,
        timestamp: run2Time.add(const Duration(seconds: 5)),
      ),
    ];

    var run2 = TestRun.create(
      id: run2Id,
      size: 2,
      levels: {'A1'},
      timeLimitMs: 5000,
      orderPolicy: 'by_level',
      onlyLeeches: false,
    );
    for (final a in attempts2) {
      run2 = run2.addAttempt(a);
    }
    run2 = run2.finish().copyWith(
      startedAt: run2Time,
      finishedAt: run2Time.add(const Duration(seconds: 10)),
    );

    await _progressRepository.saveTestRun(run1);
    await _progressRepository.batchSaveAttempts(attempts1);
    await _progressRepository.saveTestRun(run2);
    await _progressRepository.batchSaveAttempts(attempts2);

    // 轮次 3：昨天 - 演示跨天横向日期切换与对比
    final yesterday = now.subtract(const Duration(days: 1));
    final run3Id = 'demo-run-${now.millisecondsSinceEpoch}-3';
    final run3Time = yesterday.subtract(const Duration(hours: 4));
    final attempts3 = [
      Attempt(
        wordId: words[0].id,
        chosenIndex: 0,
        correctIndex: 0,
        rtMs: 650,
        result: AttemptResult.correct,
        timestamp: run3Time,
      ),
      Attempt(
        wordId: words[1].id,
        chosenIndex: 2,
        correctIndex: 0,
        rtMs: 2100,
        result: AttemptResult.wrong,
        timestamp: run3Time.add(const Duration(seconds: 8)),
      ),
    ];
    var run3 = TestRun.create(
      id: run3Id,
      size: 2,
      levels: {'A1'},
      timeLimitMs: 5000,
      orderPolicy: 'by_level',
      onlyLeeches: false,
    );
    for (final a in attempts3) {
      run3 = run3.addAttempt(a);
    }
    run3 = run3.finish().copyWith(
      startedAt: run3Time,
      finishedAt: run3Time.add(const Duration(seconds: 15)),
    );
    await _progressRepository.saveTestRun(run3);
    await _progressRepository.batchSaveAttempts(attempts3);
  }
}
