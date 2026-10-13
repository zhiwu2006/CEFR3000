import 'dart:io';
import 'dart:async';
import 'dart:math';

import '../features/progress/domain/daily_records.dart';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/models.dart';

import '../data/repositories.dart';
import '../domain/domain.dart';
import 'ai_benchmark.dart';
import 'word_explanation_service.dart';
import '../utils/ai_studio_models.dart';
import '../utils/openrouter_models.dart';
import 'session_controller.dart';
import 'session_models.dart';
import 'app_settings_notifier.dart';
import '../services/daily_history_service.dart';
import '../features/study/domain/session_checkpoint.dart';
import '../features/study/data/session_checkpoint_store.dart';
import '../features/study/application/study_plan_service.dart';
import '../features/memory/application/fsrs_fit_controller.dart';

bool _useSqliteLearningCore() {
  if (kIsWeb || Platform.environment['FLUTTER_TEST'] == 'true') {
    return false;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => true,
    _ => false,
  };
}

/// SharedPreferences provider
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return await SharedPreferences.getInstance();
});

/// 当前学习会话的版本化检查点存储。
final sessionCheckpointStoreProvider = FutureProvider<SessionCheckpointStore>((
  ref,
) async {
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  return SessionCheckpointStore(preferences);
});

final studyPlanServiceProvider = Provider<StudyPlanService>((ref) {
  return StudyPlanService(
    wordRepository: ref.watch(wordRepositoryProvider),
    progressRepository: ref.watch(progressRepositoryProvider),
  );
});

/// Word Repository provider
final wordRepositoryProvider = Provider<WordRepository>((ref) {
  return HiveWordRepository();
});

/// Progress Repository provider
final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  final wordRepo = ref.watch(wordRepositoryProvider);
  if (_useSqliteLearningCore()) {
    return SqliteProgressRepository(wordRepo);
  }
  return HiveProgressRepository(wordRepo);
});

/// TTS Service provider
final ttsServiceProvider = Provider<TtsService>((ref) {
  return FlutterTtsService();
});

/// Distractor Service provider
final distractorServiceProvider = Provider<DistractorService>((ref) {
  return DistractorService();
});

/// App Settings provider
final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return AppSettingsNotifier(prefs);
    });

/// OpenRouter free models provider
final openRouterFreeModelsProvider =
    FutureProvider.autoDispose<List<OpenRouterModel>>((ref) async {
      final apiKey = ref.watch(
        appSettingsProvider.select((s) => s.openRouterApiKey),
      );
      final models = await fetchOpenRouterModels(apiKey: apiKey);
      final freeModels = models.where((model) => model.isFree).toList();
      if (freeModels.isNotEmpty) return freeModels;
      return fallbackFreeModels;
    });

/// Google AI Studio models provider (free-tier available via key)
final aiStudioModelsProvider = FutureProvider.autoDispose<List<AiStudioModel>>((
  ref,
) async {
  final apiKey = ref.watch(appSettingsProvider.select((s) => s.aiStudioApiKey));
  final models = await fetchAiStudioModels(apiKey: apiKey);
  final freeTierModels = models.where((model) => model.isFreeTier).toList();
  if (freeTierModels.isNotEmpty) return freeTierModels;
  return fallbackAiStudioModels;
});

/// AI model benchmark provider
final aiBenchmarkProvider =
    StateNotifierProvider<AiBenchmarkNotifier, AiBenchmarkState>((ref) {
      return AiBenchmarkNotifier();
    });

final wordExplanationServiceProvider = Provider<WordExplanationService>((ref) {
  return WordExplanationService();
});

final wordExplanationProvider = FutureProvider.family<WordExplanation, Word>((
  ref,
  word,
) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final settings = ref.watch(appSettingsProvider);
  final service = ref.watch(wordExplanationServiceProvider);
  return service.getExplanation(word: word, settings: settings, prefs: prefs);
});

final wordDetailedExplanationProvider =
    FutureProvider.family<WordDetailedExplanation, Word>((ref, word) async {
      final prefs = await ref.watch(sharedPreferencesProvider.future);
      final settings = ref.watch(appSettingsProvider);
      final service = ref.watch(wordExplanationServiceProvider);
      return service.getDetailedExplanation(
        word: word,
        settings: settings,
        prefs: prefs,
      );
    });

/// Session Controller provider
final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionData>((ref) {
      final wordRepo = ref.watch(wordRepositoryProvider);
      final progressRepo = ref.watch(progressRepositoryProvider);
      final ttsService = ref.watch(ttsServiceProvider);
      final distractorService = ref.watch(distractorServiceProvider);
      final settingsNotifier = ref.watch(appSettingsProvider.notifier);

      return SessionController(
        wordRepository: wordRepo,
        progressRepository: progressRepo,
        ttsService: ttsService,
        distractorService: distractorService,
        getDailyNewRemaining: settingsNotifier.getDailyNewRemaining,
        consumeDailyNew: settingsNotifier.consumeDailyNew,
        consumeNewOnSelection: false,
        checkpointStoreGetter: () =>
            ref.read(sessionCheckpointStoreProvider).asData?.value,
      );
    });

/// Words provider (cached)
final wordsProvider = FutureProvider<List<Word>>((ref) async {
  final repo = ref.watch(wordRepositoryProvider);
  return await repo.loadAll();
});

/// Word stats provider: total and per-level counts
final wordStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  // 确保初始化完成
  await ref.watch(initializationProvider.future);
  final repo = ref.read(wordRepositoryProvider);
  return await repo.getStatistics();
});

/// Words by levels provider
final wordsByLevelsProvider = FutureProvider.family<List<Word>, String>((
  ref,
  levelsKey,
) async {
  final repo = ref.read(wordRepositoryProvider); // 使用 read 而不是 watch 避免循环依赖
  final levels = levelsKey.split(',').where((e) => e.isNotEmpty).toSet();
  return await repo.loadByLevels(levels);
});

/// Due words provider
final dueWordsProvider = FutureProvider.family<List<Word>, Set<String>>((
  ref,
  levels,
) async {
  final repo = ref.read(progressRepositoryProvider);
  return await repo.getDueWords(levels);
});

/// Leech words provider - 响应设置变化但避免持续重建
final leechWordsProvider = FutureProvider.autoDispose<List<Word>>((ref) async {
  // 等待初始化完成
  await ref.watch(initializationProvider.future);

  // 监听设置变化，但只获取选择的级别
  final settings = ref.watch(appSettingsProvider);
  final levels = settings.selectedLevelsSet;
  final repo = ref.read(progressRepositoryProvider);

  try {
    // 获取当前选择级别的不熟悉单词
    final leechPolicy = LeechPolicy(
      lapsesThreshold: settings.leechLapsesThreshold,
      includeMarked: settings.leechIncludeMarked,
    );
    final leechWords = repo is LeechPolicyProgressRepository
        ? await (repo as LeechPolicyProgressRepository).getLeechWordsWithPolicy(
            levels,
            leechPolicy,
          )
        : await repo.getLeechWords(levels);
    debugPrint('Found ${leechWords.length} leech words for levels $levels');
    return leechWords;
  } catch (e) {
    debugPrint('Error loading leech words: $e');
    return <Word>[];
  }
});

/// Leech word statuses provider - 包含进度与统计信息
final leechWordStatusesProvider =
    FutureProvider.autoDispose<List<WordStudyStatus>>((ref) async {
      await ref.watch(initializationProvider.future);

      final settings = ref.watch(appSettingsProvider);
      final levels = settings.selectedLevelsSet;
      final repo = ref.read(progressRepositoryProvider);

      try {
        final statuses = await repo.getWordStatuses(levels);
        final leechPolicy = LeechPolicy(
          lapsesThreshold: settings.leechLapsesThreshold,
          includeMarked: settings.leechIncludeMarked,
        );
        final leechStatuses = statuses
            .where(
              (status) =>
                  status.state != null && leechPolicy.isLeech(status.state!),
            )
            .toList();
        debugPrint(
          'Found ${leechStatuses.length} leech word statuses for levels $settings',
        );
        return leechStatuses;
      } catch (e) {
        debugPrint('Error loading leech word statuses: $e');
        return <WordStudyStatus>[];
      }
    });

/// Learning stats provider - 从数据库获取真实统计数据
final learningStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  // 等待初始化完成
  await ref.watch(initializationProvider.future);

  final settings = ref.watch(appSettingsProvider);
  final progressRepo = ref.read(progressRepositoryProvider);

  // 「当前会话」以检查点为准，而不是 settings.hasActiveSession。
  // 后者依赖 currentSessionId，而该字段只由 stageCustomSession 写入：首页
  // 「开始学习」从不写它，会漏报主路径的会话；其进度更新入口
  // （updateTestProgress）也零调用，因此对自定义会话恒显示 0 进度。
  // 检查点才是「是否存在未完成会话」的唯一真实来源（与 4.1 的恢复判据同源）。
  // 检查点存储初始化失败（SharedPreferences 不可用等）不应让整个统计页报错。
  // 该 await 原先落在下方 try 之外，异常会直接冒泡成 AsyncError，连
  // 「其余统计照常展示」的降级分支都走不到；这里显式降级为「没有进行中的会话」。
  SessionCheckpoint? activeCheckpoint;
  try {
    final checkpoint = (await ref.watch(
      sessionCheckpointStoreProvider.future,
    )).load();
    activeCheckpoint = (checkpoint != null && checkpoint.isResumable)
        ? checkpoint
        : null;
  } catch (e) {
    debugPrint('Error loading session checkpoint: $e');
    activeCheckpoint = null;
  }
  final currentSessionProgress = activeCheckpoint?.currentProgress ?? 0;
  final currentSessionTotal = activeCheckpoint?.totalQuestionCount ?? 0;

  try {
    // 从数据库获取学习统计
    final leechPolicy = LeechPolicy(
      lapsesThreshold: settings.leechLapsesThreshold,
      includeMarked: settings.leechIncludeMarked,
    );
    final dbStats = await progressRepo.getLearningStats(policy: leechPolicy);

    // 「待复习」「疑难词」只统计当前选择的级别：范围外的旧词既不会进入
    // 今日计划，也不应让首页数字虚高。
    final levelWords = await ref
        .read(wordRepositoryProvider)
        .loadByLevels(settings.selectedLevelsSet);
    final levelStates = await progressRepo.getCardStates(
      levelWords.map((word) => word.id).toList(),
    );

    // 获取测试历史来计算今日测试数
    final testRuns = await progressRepo.getTestRunHistory(limit: 100);
    final today = DateTime.now();
    final todayRuns = testRuns.where((run) {
      return run.startedAt.year == today.year &&
          run.startedAt.month == today.month &&
          run.startedAt.day == today.day &&
          run.isFinished;
    }).toList();

    // 今日测试次数
    final todayTests = todayRuns.length;

    // 今日最后一次完整测试的准确率（以最后一次为准）
    double todayAccuracy = 0.0;
    if (todayRuns.isNotEmpty) {
      // 按时间排序，取最后一次
      todayRuns.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      final lastRun = todayRuns.first;
      if (lastRun.accuracy != null) {
        todayAccuracy = lastRun.accuracy!;
      } else if (lastRun.attempts.isNotEmpty) {
        final correct = lastRun.attempts.where((a) => a.isCorrect).length;
        todayAccuracy = correct / lastRun.attempts.length;
      }
    }

    final statsMap = {
      'totalTests': dbStats['finishedTestRuns'] ?? 0,
      'averageAccuracy': dbStats['avgAccuracy'] ?? 0.0,
      'todayTests': todayTests,
      'todayAccuracy': todayAccuracy, // 今日最后一次测试的准确率
      'currentSessionProgress': currentSessionProgress,
      'currentSessionTotal': currentSessionTotal,
      'hasActiveSession': activeCheckpoint != null,
      'totalCards': dbStats['totalCards'] ?? 0,
      'dueCards': dbStats['dueCards'] ?? 0,
      'leechCards': dbStats['leechCards'] ?? 0,
      'streakDays': dbStats['streakDays'] ?? 0,
      'levelCards': levelStates.length,
      'levelDueCards': levelStates.where((state) => state.isDue).length,
      'levelLeechCards': levelStates.where(leechPolicy.isLeech).length,
      'longestStreakDays': dbStats['longestStreakDays'] ?? 0,
      'totalStudyDays': dbStats['totalStudyDays'] ?? 0,
      'checkedInToday': dbStats['checkedInToday'] ?? false,
      'retentionRate': dbStats['retentionRate'] ?? 0.0,
      'totalDurationMinutes': dbStats['totalDurationMinutes'] ?? 0,
      'totalDurationMs': dbStats['totalDurationMs'] ?? 0,
      'reviewEventCount': dbStats['reviewEventCount'] ?? 0,
      'exposureCount': dbStats['exposureCount'] ?? 0,
      'observation7d': dbStats['observation7d'] ?? const {},
      'observation30d': dbStats['observation30d'] ?? const {},
      'skillCoverage': dbStats['skillCoverage'] ?? const [],
    };

    // 我们需要将上面的 Map 赋值给一个可变的 result 变量，以便后续添加数据
    final result = Map<String, dynamic>.from(statsMap);

    // 获取高级统计数据
    try {
      final dailyStats = await progressRepo.getDailyStats(30);
      final levelProgress = await progressRepo.getLevelProgress(
        settings.selectedLevelsSet,
      );

      result.addAll({
        'dailyStats': dailyStats,
        'levelTotal': levelProgress['total'] ?? 0,
        'levelLearned': levelProgress['learned'] ?? 0,
        'levelMastered': levelProgress['mastered'] ?? 0,
      });
    } catch (e) {
      debugPrint('Error loading advanced stats: $e');
    }

    return result;
  } catch (e) {
    debugPrint('Error loading learning stats: $e');
    return {
      'totalTests': 0,
      'averageAccuracy': 0.0,
      'todayTests': 0,
      'currentSessionProgress': currentSessionProgress,
      'currentSessionTotal': currentSessionTotal,
      'hasActiveSession': activeCheckpoint != null,
      'totalCards': 0,
      'dueCards': 0,
      'leechCards': 0,
      'streakDays': 0,
      'levelCards': 0,
      'levelDueCards': 0,
      'levelLeechCards': 0,
      'longestStreakDays': 0,
      'totalStudyDays': 0,
      'checkedInToday': false,
      'retentionRate': 0.0,
      'totalDurationMinutes': 0,
      'totalDurationMs': 0,
    };
  }
});

/// Test run history provider
final testRunHistoryProvider = FutureProvider<List<TestRun>>((ref) async {
  final repo = ref.read(progressRepositoryProvider);
  return await repo.getTestRunHistory();
});

/// 平板首页学习记录：按自然日汇总全部已完成轮次。
final dailyRecordsProvider = FutureProvider.autoDispose<List<DailyRecord>>((
  ref,
) async {
  await ref.watch(initializationProvider.future);
  // 跟随统计刷新：完成一轮后 learningStatsProvider 会失效，这里一起重算。
  ref.watch(learningStatsProvider);
  final repo = ref.read(progressRepositoryProvider);
  return DailyRecord.fromRuns(await repo.getTestRunHistory(limit: 100000));
});

Future<void> _measureStartup(
  String stage,
  Future<void> Function() action,
) async {
  final watch = Stopwatch()..start();
  try {
    await action();
  } finally {
    debugPrint('Startup $stage: ${watch.elapsedMilliseconds}ms');
  }
}

/// 语音预热只执行一次，首次发音也复用服务内部的同一个初始化 Future。
final ttsWarmupProvider = FutureProvider<void>((ref) async {
  try {
    await _measureStartup('tts', () => _initTtsService(ref));
  } catch (error) {
    debugPrint('TTS initialization failed (non-critical): $error');
  }
});

final initializationProvider = FutureProvider<void>((ref) async {
  await ref.watch(coreInitializationProvider.future);
  unawaited(ref.read(ttsWarmupProvider.future));
});

Future<void> _initHive() async {
  debugPrint('Initializing Hive...');
  await Hive.initFlutter();
  debugPrint('Hive initialized successfully');
}

Future<void> _initWordRepository(Ref ref) async {
  debugPrint('Initializing WordRepository...');
  final wordRepo = ref.read(wordRepositoryProvider) as HiveWordRepository;
  await wordRepo.init();
  debugPrint('WordRepository initialized successfully');
}

Future<void> _initProgressRepository(Ref ref) async {
  debugPrint('Initializing ProgressRepository...');
  final progressRepo = ref.read(progressRepositoryProvider);
  if (progressRepo is HiveProgressRepository) {
    await progressRepo.init();
  } else if (progressRepo is SqliteProgressRepository) {
    await progressRepo.init();
    // The legacy Hive store remains read-only and is only opened when a
    // migration can actually run; a settled SQLite core skips seven boxes.
    if (!await progressRepo.hasCoreData()) {
      final legacy = HiveProgressRepository(ref.read(wordRepositoryProvider));
      await legacy.init();
      try {
        final report = await LegacyProgressMigrator().migrate(
          source: legacy,
          target: progressRepo,
        );
        debugPrint(
          'Legacy progress migration: ${report.status}, '
          'cards=${report.cardStates}, events=${report.reviewEvents}',
        );
      } finally {
        await legacy.dispose();
      }
    }
    await progressRepo.indexLegacyLexicon(
      await ref.read(wordRepositoryProvider).loadAll(),
    );
  }
  debugPrint('ProgressRepository initialized successfully');
}

Future<void> _initTtsService(Ref ref) async {
  debugPrint('Initializing TTS...');
  final ttsService = ref.read(ttsServiceProvider);
  await ttsService.init();
  debugPrint('TTS initialized successfully');
}

/// 首页必需的数据；语音服务不属于就绪门槛。
final coreInitializationProvider = FutureProvider<void>((ref) async {
  try {
    debugPrint('=== Starting initialization ===');

    try {
      await _measureStartup('_initHive', () => _initHive());
    } catch (e, stackTrace) {
      debugPrint('Hive initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }

    try {
      await _measureStartup(
        '_initWordRepository',
        () => _initWordRepository(ref),
      );
    } catch (e, stackTrace) {
      debugPrint('WordRepository initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }

    try {
      await _measureStartup(
        '_initProgressRepository',
        () => _initProgressRepository(ref),
      );
    } catch (e, stackTrace) {
      debugPrint('ProgressRepository initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }

    debugPrint('=== Initialization completed ===');
  } catch (e, stackTrace) {
    debugPrint('=== Initialization failed ===');
    debugPrint('Error: $e');
    debugPrint('Stack trace: $stackTrace');
    rethrow;
  }
});

/// 当前会话配置 provider
final currentSessionConfigProvider = Provider<SessionConfig>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return SessionConfig.fromAppSettings(settings);
});

/// 今日牌组 provider
final todayDeckProvider = FutureProvider.autoDispose<List<Word>>((ref) async {
  // 等待初始化完成
  await ref.watch(initializationProvider.future);

  final settings = ref.watch(appSettingsProvider);
  final wordRepo = ref.read(wordRepositoryProvider);

  debugPrint('=== Loading today deck ===');
  debugPrint('Selected levels: ${settings.selectedLevelsSet}');

  // 直接从词库获取指定级别的所有词汇
  final words = await wordRepo.loadByLevels(settings.selectedLevelsSet);
  debugPrint(
    'Found ${words.length} words for levels ${settings.selectedLevelsSet}',
  );

  return words;
});

/// 今日主动回忆计划只读投影；计划预览不会消费新词额度。
final todayStudyPlanProvider = FutureProvider.autoDispose<StudyPlan>((
  ref,
) async {
  await ref.watch(initializationProvider.future);
  final settings = ref.watch(appSettingsProvider);
  final service = ref.watch(studyPlanServiceProvider);
  final policy = LeechPolicy(
    lapsesThreshold: settings.leechLapsesThreshold,
    includeMarked: settings.leechIncludeMarked,
  );
  return service.buildTodayPlan(
    levels: settings.selectedLevelsSet,
    maxItems: settings.wordsPerSession,
    maxMinutes: 10,
    dailyNewLimit: settings.dailyNewLimit,
    dailyNewUsed: settings.dailyNewUsed,
    leechPolicy: policy,
    onlyLeeches: settings.onlyLeeches,
    skill: LearningSkill.meaningRecall,
  );
});

/// 传统四选一闪测的兼容计划。它继续使用识别 CardState，但与主动
/// 回忆计划分开，避免一次答题推进了错误能力的状态。
final todayRecognitionPlanProvider = FutureProvider.autoDispose<StudyPlan>((
  ref,
) async {
  await ref.watch(initializationProvider.future);
  final settings = ref.watch(appSettingsProvider);
  final policy = LeechPolicy(
    lapsesThreshold: settings.leechLapsesThreshold,
    includeMarked: settings.leechIncludeMarked,
  );
  // 没有采用拟合时立即返回空表；估计失败时退回按到期日排序。
  Map<int, double> recallEstimates;
  try {
    recallEstimates = await ref.watch(recallEstimatesProvider.future);
  } catch (error) {
    debugPrint('Recall estimates unavailable: $error');
    recallEstimates = const {};
  }
  final targetWords = settings.wordsPerSession;
  // 闪测单题估时仅 3~4 秒（见 StudyPlanService），100 题约 7 分钟；
  // 这里留出 30 分钟下限，保证时间预算不会截断用户设定的词数。
  final budgetMinutes = max(30, (targetWords * 4 / 60).ceil());
  return ref
      .watch(studyPlanServiceProvider)
      .buildTodayPlan(
        levels: settings.selectedLevelsSet,
        maxItems: targetWords,
        maxMinutes: budgetMinutes,
        dailyNewLimit: settings.dailyNewLimit,
        dailyNewUsed: settings.dailyNewUsed,
        leechPolicy: policy,
        onlyLeeches: settings.onlyLeeches,
        skill: LearningSkill.meaningRecognition,
        recallEstimates: recallEstimates,
      );
});

/// 英文产出使用独立 LearningItem 状态的计划。它不会把识别卡的到期日
/// 或复习次数当作产出能力已经掌握；旧词库内容仅在用户主动进入时以
/// legacy-fallback 资格加入。
final todayProductionPlanProvider = FutureProvider.autoDispose<StudyPlan>((
  ref,
) async {
  await ref.watch(initializationProvider.future);
  final settings = ref.watch(appSettingsProvider);
  return ref
      .watch(studyPlanServiceProvider)
      .buildTodayPlan(
        levels: settings.selectedLevelsSet,
        maxItems: settings.wordsPerSession,
        maxMinutes: 10,
        dailyNewLimit: settings.dailyNewLimit,
        dailyNewUsed: settings.dailyNewUsed,
        leechPolicy: LeechPolicy(
          lapsesThreshold: settings.leechLapsesThreshold,
          includeMarked: settings.leechIncludeMarked,
        ),
        skill: LearningSkill.englishProduction,
        allowLegacyFallback: true,
      );
});

/// 会话暂停状态 provider
final sessionPausedProvider = StateProvider<bool>((ref) => false);

/// 应用是否准备就绪
final appReadyProvider = FutureProvider<bool>((ref) async {
  await ref.watch(initializationProvider.future);
  return true;
});

/// 每日历史与重点词分析服务 Provider
final dailyHistoryServiceProvider = Provider<DailyHistoryService>((ref) {
  final progressRepo = ref.watch(progressRepositoryProvider);
  final wordRepo = ref.watch(wordRepositoryProvider);
  final settings = ref.watch(appSettingsProvider);
  return DailyHistoryService(
    progressRepository: progressRepo,
    wordRepository: wordRepo,
    leechPolicy: LeechPolicy(
      lapsesThreshold: settings.leechLapsesThreshold,
      includeMarked: settings.leechIncludeMarked,
    ),
    slowThresholdMultiplier: settings.slowThreshold,
  );
});

/// 每日测试历史汇总列表 Provider
final dailyHistorySummariesProvider =
    FutureProvider.autoDispose<List<DailyHistorySummary>>((ref) async {
      await ref.watch(initializationProvider.future);
      final service = ref.watch(dailyHistoryServiceProvider);
      return await service.getDailySummaries();
    });

/// 用户当前选中的历史日期 Provider（null 默认为当天或最新日期）
final selectedHistoryDateProvider = StateProvider<DateTime?>((ref) => null);
