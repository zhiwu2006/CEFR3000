import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/models.dart';
import '../data/repositories.dart';
import '../domain/domain.dart';
import 'session_controller.dart';
import 'session_models.dart';

/// SharedPreferences provider
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

/// Word Repository provider
final wordRepositoryProvider = Provider<WordRepository>((ref) {
  return HiveWordRepository();
});

/// Progress Repository provider  
final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  final wordRepo = ref.watch(wordRepositoryProvider);
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

/// TestSet Generator provider
final testSetGeneratorProvider = Provider<TestSetGenerator>((ref) {
  return TestSetGenerator();
});

/// App Settings provider
final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AppSettingsNotifier(prefs);
});

/// Session Controller provider
final sessionControllerProvider = StateNotifierProvider<SessionController, SessionData>((ref) {
  final wordRepo = ref.watch(wordRepositoryProvider);
  final progressRepo = ref.watch(progressRepositoryProvider);
  final ttsService = ref.watch(ttsServiceProvider);
  final distractorService = ref.watch(distractorServiceProvider);
  
  return SessionController(
    wordRepository: wordRepo,
    progressRepository: progressRepo,
    ttsService: ttsService,
    distractorService: distractorService,
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
final wordsByLevelsProvider = FutureProvider.family<List<Word>, String>((ref, levelsKey) async {
  final repo = ref.read(wordRepositoryProvider); // 使用 read 而不是 watch 避免循环依赖
  final levels = levelsKey.split(',').where((e) => e.isNotEmpty).toSet();
  return await repo.loadByLevels(levels);
});

/// Due words provider
final dueWordsProvider = FutureProvider.family<List<Word>, Set<String>>((ref, levels) async {
  final repo = ref.read(progressRepositoryProvider);
  return await repo.getDueWords(levels);
});

/// Leech words provider - 响应设置变化但避免持续重建
final leechWordsProvider = FutureProvider.autoDispose<List<Word>>((ref) async {
  // 等待初始化完成
  await ref.watch(initializationProvider.future);
  
  // 监听设置变化，但只获取选择的级别
  final settings = ref.watch(appSettingsProvider.select((s) => s.selectedLevelsSet));
  final repo = ref.read(progressRepositoryProvider);
  
  try {
    // 获取当前选择级别的不熟悉单词
    final leechWords = await repo.getLeechWords(settings);
    print('Found ${leechWords.length} leech words for levels $settings');
    return leechWords;
  } catch (e) {
    print('Error loading leech words: $e');
    return <Word>[];
  }
});

/// Learning stats provider - 从数据库获取真实统计数据
final learningStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  // 等待初始化完成
  await ref.watch(initializationProvider.future);
  
  final settings = ref.watch(appSettingsProvider);
  final progressRepo = ref.read(progressRepositoryProvider);
  
  try {
    // 从数据库获取学习统计
    final dbStats = await progressRepo.getLearningStats();
    
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
      'currentSessionProgress': settings.hasActiveSession ? settings.currentProgress : 0,
      'currentSessionTotal': settings.hasActiveSession ? settings.totalWords : 0,
      'hasActiveSession': settings.hasActiveSession,
      'totalCards': dbStats['totalCards'] ?? 0,
      'dueCards': dbStats['dueCards'] ?? 0,
      'leechCards': dbStats['leechCards'] ?? 0,
      'streakDays': dbStats['streakDays'] ?? 0,
      'retentionRate': dbStats['retentionRate'] ?? 0.0,
      'totalDurationMinutes': dbStats['totalDurationMinutes'] ?? 0,
    };
    
    // 我们需要将上面的 Map 赋值给一个可变的 result 变量，以便后续添加数据
    final result = Map<String, dynamic>.from(statsMap);
    
    // 获取高级统计数据
    try {
      final dailyStats = await progressRepo.getDailyStats(30);
      final levelProgress = await progressRepo.getLevelProgress(settings.selectedLevelsSet);
      
      result.addAll({
        'dailyStats': dailyStats,
        'levelTotal': levelProgress['total'] ?? 0,
        'levelLearned': levelProgress['learned'] ?? 0,
        'levelMastered': levelProgress['mastered'] ?? 0,
      });
    } catch (e) {
      print('Error loading advanced stats: $e');
    }
    
    return result;
  } catch (e) {
    print('Error loading learning stats: $e');
    return {
      'totalTests': 0,
      'averageAccuracy': 0.0,
      'todayTests': 0,
      'currentSessionProgress': settings.hasActiveSession ? settings.currentProgress : 0,
      'currentSessionTotal': settings.hasActiveSession ? settings.totalWords : 0,
      'hasActiveSession': settings.hasActiveSession,
      'totalCards': 0,
      'dueCards': 0,
      'leechCards': 0,
      'streakDays': 0,
      'retentionRate': 0.0,
      'totalDurationMinutes': 0,
    };
  }
});

/// Test run history provider
final testRunHistoryProvider = FutureProvider<List<TestRun>>((ref) async {
  final repo = ref.read(progressRepositoryProvider);
  return await repo.getTestRunHistory();
});

/// App Settings Notifier
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  final AsyncValue<SharedPreferences> _prefsAsync;
  
  AppSettingsNotifier(this._prefsAsync) : super(AppSettings.defaultSettings) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefsAsync = _prefsAsync;
    if (prefsAsync is AsyncData<SharedPreferences>) {
      final prefs = prefsAsync.value;
      
      try {
        final levelsString = prefs.getString('selectedLevels') ?? 'A1';
        final levels = levelsString.split(',').toSet();
        
        // 加载测试进度
        final currentSessionId = prefs.getString('currentSessionId');
        final currentProgress = prefs.getInt('currentProgress') ?? 0;
        final totalWords = prefs.getInt('totalWords') ?? 0;
        final remainingIdsString = prefs.getString('remainingWordIds') ?? '';
        final remainingWordIds = remainingIdsString.isEmpty 
            ? <int>[]
            : remainingIdsString.split(',').map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList();
        
        // 加载主题设置
        final themeStyle = prefs.getString('themeStyle') ?? 'standard';
        
        state = state.copyWith(
          selectedLevels: levels.toSet(),
          wordsPerSession: prefs.getInt('wordsPerSession') ?? 100,
          timeLimitMs: prefs.getInt('timeLimitMs') ?? 2000,
          orderPolicy: prefs.getString('orderPolicy') ?? 'by_level',
          onlyLeeches: prefs.getBool('onlyLeeches') ?? false,
          delayProfile: _parseDelayProfile(prefs.getString('delayProfile') ?? 'standard'),
          ttsLocale: prefs.getString('ttsLocale') ?? 'en-US',
          ttsRate: prefs.getDouble('ttsRate') ?? 0.44,
          ttsPitch: prefs.getDouble('ttsPitch') ?? 1.0,
          highContrast: prefs.getBool('highContrast') ?? false,
          uiLocale: prefs.getString('uiLocale') ?? 'zh-CN',
          currentSessionId: currentSessionId,
          currentProgress: currentProgress,
          totalWords: totalWords,
          remainingWordIds: remainingWordIds,
          themeStyle: themeStyle,
        );
      } catch (e) {
        print('Error loading settings: $e');
        // Keep default settings
      }
    }
  }

  DelayProfile _parseDelayProfile(String value) {
    switch (value) {
      case 'gentle':
        return DelayProfile.gentle;
      case 'aggressive':
        return DelayProfile.aggressive;
      default:
        return DelayProfile.standard;
    }
  }

  String _delayProfileToString(DelayProfile profile) {
    switch (profile) {
      case DelayProfile.gentle:
        return 'gentle';
      case DelayProfile.aggressive:
        return 'aggressive';
      case DelayProfile.standard:
        return 'standard';
    }
  }

  Future<void> updateSelectedLevels(Set<String> levels) async {
    state = state.copyWith(selectedLevels: levels);
    await _saveSettings();
  }

  Future<void> updateWordsPerSession(int count) async {
    state = state.copyWith(wordsPerSession: count);
    await _saveSettings();
  }

  Future<void> updateTimeLimitMs(int timeMs) async {
    state = state.copyWith(timeLimitMs: timeMs);
    await _saveSettings();
  }

  Future<void> updateOrderPolicy(String policy) async {
    state = state.copyWith(orderPolicy: policy);
    await _saveSettings();
  }

  Future<void> updateOnlyLeeches(bool onlyLeeches) async {
    state = state.copyWith(onlyLeeches: onlyLeeches);
    await _saveSettings();
  }

  Future<void> updateDelayProfile(DelayProfile profile) async {
    state = state.copyWith(delayProfile: profile);
    await _saveSettings();
  }

  Future<void> updateTtsSettings({
    String? locale,
    double? rate,
    double? pitch,
  }) async {
    state = state.copyWith(
      ttsLocale: locale ?? state.ttsLocale,
      ttsRate: rate ?? state.ttsRate,
      ttsPitch: pitch ?? state.ttsPitch,
    );
    await _saveSettings();
  }

  Future<void> updateAccessibility({
    bool? highContrast,
    String? uiLocale,
  }) async {
    state = state.copyWith(
      highContrast: highContrast ?? state.highContrast,
      uiLocale: uiLocale ?? state.uiLocale,
    );
    await _saveSettings();
  }

  /// 更新主题风格
  Future<void> updateThemeStyle(String themeStyle) async {
    // 同步更新 highContrast 以保持兼容
    final isHighContrast = themeStyle == 'highContrast';
    state = state.copyWith(
      themeStyle: themeStyle,
      highContrast: isHighContrast,
    );
    await _saveSettings();
  }

  Future<void> resetToDefaults() async {
    state = AppSettings.defaultSettings;
    await _saveSettings();
  }

  /// 保存测试进度
  Future<void> saveTestProgress({
    required String sessionId,
    required int currentProgress,
    required int totalWords,
    required List<int> remainingWordIds,
  }) async {
    state = state.copyWith(
      currentSessionId: sessionId,
      currentProgress: currentProgress,
      totalWords: totalWords,
      remainingWordIds: remainingWordIds,
    );
    await _saveSettings();
  }

  /// 清除测试进度
  Future<void> clearTestProgress() async {
    print('=== clearTestProgress called ===');
    print('Before: hasActiveSession=${state.hasActiveSession}, sessionId=${state.currentSessionId}');
    state = state.clearProgress();
    print('After: hasActiveSession=${state.hasActiveSession}, sessionId=${state.currentSessionId}');
    await _saveSettings();
    print('Settings saved');
  }

  /// 更新测试进度
  Future<void> updateTestProgress({
    int? currentProgress,
    List<int>? remainingWordIds,
  }) async {
    state = state.copyWith(
      currentProgress: currentProgress ?? state.currentProgress,
      remainingWordIds: remainingWordIds ?? state.remainingWordIds,
    );
    await _saveSettings();
  }

  /// 恢复测试会话
  Future<void> resumeTestSession() async {
    // 这个方法主要用于标记要恢复会话，实际的恢复逻辑在SessionController中处理
    print('=== Resuming test session ===');
    print('Session ID: ${state.currentSessionId}');
    print('Progress: ${state.currentProgress}/${state.totalWords}');
    print('Remaining words: ${state.remainingWordIds.length}');
  }

  Future<void> _saveSettings() async {
    final prefsAsync = _prefsAsync;
    if (prefsAsync is AsyncData<SharedPreferences>) {
      final prefs = prefsAsync.value;
      
      try {
        await prefs.setString('selectedLevels', state.selectedLevelsSet.join(','));
        await prefs.setInt('wordsPerSession', state.wordsPerSession);
        await prefs.setInt('timeLimitMs', state.timeLimitMs);
        await prefs.setString('orderPolicy', state.orderPolicy);
        await prefs.setBool('onlyLeeches', state.onlyLeeches);
        await prefs.setString('delayProfile', _delayProfileToString(state.delayProfile));
        await prefs.setString('ttsLocale', state.ttsLocale);
        await prefs.setDouble('ttsRate', state.ttsRate);
        await prefs.setDouble('ttsPitch', state.ttsPitch);
        await prefs.setBool('highContrast', state.highContrast);
        await prefs.setString('uiLocale', state.uiLocale);
        await prefs.setString('themeStyle', state.themeStyle);
        
        // 保存测试进度
        if (state.currentSessionId != null) {
          await prefs.setString('currentSessionId', state.currentSessionId!);
        } else {
          await prefs.remove('currentSessionId');
        }
        await prefs.setInt('currentProgress', state.currentProgress);
        await prefs.setInt('totalWords', state.totalWords);
        await prefs.setString('remainingWordIds', state.remainingWordIds.join(','));
      } catch (e) {
        print('Error saving settings: $e');
      }
    }
  }
}

/// 初始化所有数据服务
final initializationProvider = FutureProvider<void>((ref) async {
  try {
    print('=== Starting initialization ===');
    
    // 初始化 Hive
    print('Initializing Hive...');
    await Hive.initFlutter();
    print('Hive initialized successfully');
    
    // 初始化各个仓储
    print('Initializing WordRepository...');
    final wordRepo = ref.read(wordRepositoryProvider) as HiveWordRepository;
    await wordRepo.init();
    
    // 强制重新加载词库以确保数据正确
    print('Force reloading word database...');
    await wordRepo.forceReload();
    print('WordRepository initialized successfully');
    
    print('Initializing ProgressRepository...');
    final progressRepo = ref.read(progressRepositoryProvider) as HiveProgressRepository;
    await progressRepo.init();
    print('ProgressRepository initialized successfully');
    
    // 初始化 TTS (可选，失败不影响主要功能)
    try {
      print('Initializing TTS...');
      final ttsService = ref.read(ttsServiceProvider);
      await ttsService.init();
      print('TTS initialized successfully');
    } catch (e) {
      print('TTS initialization failed (non-critical): $e');
      // TTS失败不影响主要功能
    }
    
    print('=== Initialization completed ===');
  } catch (e, stackTrace) {
    print('=== Initialization failed ===');
    print('Error: $e');
    print('Stack trace: $stackTrace');
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
  
  print('=== Loading today deck ===');
  print('Selected levels: ${settings.selectedLevelsSet}');
  
  // 直接从词库获取指定级别的所有词汇
  final words = await wordRepo.loadByLevels(settings.selectedLevelsSet);
  print('Found ${words.length} words for levels ${settings.selectedLevelsSet}');
  
  return words;
});

/// 会话暂停状态 provider
final sessionPausedProvider = StateProvider<bool>((ref) => false);

/// 应用是否准备就绪
final appReadyProvider = FutureProvider<bool>((ref) async {
  await ref.watch(initializationProvider.future);
  return true;
});
