import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

import '../models/models.dart';
import '../data/secure_credential_store.dart';
import '../features/study/data/session_checkpoint_store.dart';

/// App Settings Notifier
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  Timer? _saveDebounceTimer;
  final AsyncValue<SharedPreferences> _prefsAsync;
  final CredentialStore _credentialStore;

  static const _openRouterCredential = 'vocab_flash.openrouter.api_key';
  static const _aiStudioCredential = 'vocab_flash.aistudio.api_key';

  AppSettingsNotifier(this._prefsAsync, {CredentialStore? credentialStore})
    : _credentialStore = credentialStore ?? FlutterCredentialStore(),
      super(AppSettings.defaultSettings) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefsAsync = _prefsAsync;
    if (prefsAsync is AsyncData<SharedPreferences>) {
      final prefs = prefsAsync.value;

      try {
        // --- 1. 加载子配置对象 ---

        SessionSettings session;
        if (prefs.containsKey('session_config')) {
          session = SessionSettings.fromJson(
            jsonDecode(prefs.getString('session_config')!)
                as Map<String, dynamic>,
          );
        } else {
          // 尝试从旧数据迁移
          List<String> levels;
          try {
            // 优先尝试读取 StringList
            levels = prefs.getStringList('selectedLevels') ?? ['A1'];
          } catch (_) {
            // 如果失败（可能是存为了 String），则尝试读取 String 并分割
            final str = prefs.getString('selectedLevels') ?? 'A1';
            levels = str.split(',');
          }

          final words = prefs.getInt('wordsPerSession') ?? 100;

          session = SessionSettings(
            selectedLevels: levels,
            wordsPerSession: words,
            timeLimitMs:
                (prefs.getInt('timeLimitMs') != null &&
                    prefs.getInt('timeLimitMs')! > 0)
                ? prefs.getInt('timeLimitMs')!
                : 2000,
            orderPolicy: prefs.getString('orderPolicy') ?? 'random',
            onlyLeeches: prefs.getBool('onlyLeeches') ?? false,
          );
        }

        ThemeSettings theme;
        if (prefs.containsKey('theme_config')) {
          theme = ThemeSettings.fromJson(
            jsonDecode(prefs.getString('theme_config')!)
                as Map<String, dynamic>,
          );
        } else {
          theme = ThemeSettings(
            themeStyle: prefs.getString('themeStyle') ?? 'digitalism',
            highContrast: prefs.getBool('highContrast') ?? false,
            uiLocale: prefs.getString('uiLocale') ?? 'zh_CN',
          );
        }

        TtsSettings tts;
        if (prefs.containsKey('tts_config')) {
          tts = TtsSettings.fromJson(
            jsonDecode(prefs.getString('tts_config')!) as Map<String, dynamic>,
          );
        } else {
          tts = TtsSettings(
            locale: prefs.getString('ttsLocale') ?? 'en-US',
            rate: prefs.getDouble('ttsRate') ?? 0.5,
            pitch: prefs.getDouble('ttsPitch') ?? 1.0,
            autoPlay: prefs.getBool('ttsAutoPlay') ?? true,
            onWrong: prefs.getBool('ttsOnWrong') ?? true,
          );
        }

        SrsSettings srs;
        if (prefs.containsKey('srs_config')) {
          srs = SrsSettings.fromJson(
            jsonDecode(prefs.getString('srs_config')!) as Map<String, dynamic>,
          );
        } else {
          srs = SrsSettings(
            alphaStability: prefs.getDouble('srsAlphaStability') ?? 0.18,
            betaFailure: prefs.getDouble('srsBetaFailure') ?? 1.2,
            gammaInterval: prefs.getDouble('srsGammaInterval') ?? 1.0,
            maxIntervalDays: prefs.getInt('srsMaxIntervalDays') ?? 90,
            delayProfile: prefs.getString('delayProfile') ?? 'standard',
            slowThreshold: prefs.getDouble('slowThreshold') ?? 1.5,
          );
        }

        AlgorithmSettings algorithm;
        if (prefs.containsKey('algorithm_config')) {
          algorithm = AlgorithmSettings.fromJson(
            jsonDecode(prefs.getString('algorithm_config')!)
                as Map<String, dynamic>,
          );
        } else {
          algorithm = AlgorithmSettings(
            leechWordsPerSession: prefs.getInt('leechWordsPerSession') ?? 5,
            newCardRatio: prefs.getDouble('newCardRatio') ?? 0.3,
            dailyNewLimit: prefs.getInt('dailyNewLimit') ?? 100,
            leechLapsesThreshold: prefs.getInt('leechLapsesThreshold') ?? 2,
            leechIncludeMarked: prefs.getBool('leechIncludeMarked') ?? true,
          );
        }

        AiSettings ai;
        if (prefs.containsKey('ai_config')) {
          ai = AiSettings.fromJson(
            jsonDecode(prefs.getString('ai_config')!) as Map<String, dynamic>,
          );
        } else {
          ai = AiSettings(
            provider: prefs.getString('aiProvider') ?? 'openrouter',
            defaultModel: prefs.getString('aiDefaultModel') ?? '',
            openRouterApiKey: prefs.getString('openRouterApiKey') ?? '',
            openRouterDefaultModel:
                prefs.getString('openRouterDefaultModel') ?? '',
            aiStudioApiKey: prefs.getString('aiStudioApiKey') ?? '',
            aiStudioDefaultModel: prefs.getString('aiStudioDefaultModel') ?? '',
          );
        }
        ai = await _loadSecureCredentials(ai, prefs);

        // --- 2. 加载状态数据 (保持顶层存储) ---

        final currentSessionId = prefs.getString('currentSessionId');
        final currentProgress = prefs.getInt('currentProgress') ?? 0;
        final totalWords = prefs.getInt('totalWords') ?? 0;
        final remainingIdsString = prefs.getString('remainingWordIds') ?? '';
        final remainingWordIds = remainingIdsString.isEmpty
            ? <int>[]
            : remainingIdsString
                  .split(',')
                  .map((e) => int.tryParse(e) ?? 0)
                  .where((e) => e > 0)
                  .toList();

        final dailyNewDate = prefs.getString('dailyNewDate') ?? '';
        final dailyNewUsed = prefs.getInt('dailyNewUsed') ?? 0;

        state = AppSettings(
          session: session,
          theme: theme,
          tts: tts,
          srs: srs,
          algorithm: algorithm,
          ai: ai,
          currentSessionId: currentSessionId,
          currentProgress: currentProgress,
          totalWords: totalWords,
          remainingWordIds: remainingWordIds,
          dailyNewDate: dailyNewDate,
          dailyNewUsed: dailyNewUsed,
        );
        debugPrint('Settings loaded successfully');
      } catch (e) {
        debugPrint('Error loading settings: $e');
        // 加载失败时使用默认设置，避免应用崩溃
        state = AppSettings.defaultSettings;
      }
    }
  }

  Future<AiSettings> _loadSecureCredentials(
    AiSettings legacy,
    SharedPreferences prefs,
  ) async {
    var openRouterKey = legacy.openRouterApiKey;
    var aiStudioKey = legacy.aiStudioApiKey;
    try {
      final storedOpenRouter = await _credentialStore.read(
        _openRouterCredential,
      );
      final storedAiStudio = await _credentialStore.read(_aiStudioCredential);
      if (storedOpenRouter != null) {
        openRouterKey = storedOpenRouter;
      } else if (openRouterKey.isNotEmpty) {
        await _credentialStore.write(_openRouterCredential, openRouterKey);
      }
      if (storedAiStudio != null) {
        aiStudioKey = storedAiStudio;
      } else if (aiStudioKey.isNotEmpty) {
        await _credentialStore.write(_aiStudioCredential, aiStudioKey);
      }
      // Remove the pre-secure-storage top-level keys after a successful
      // migration. The nested config is rewritten without secrets on save.
      await prefs.remove('openRouterApiKey');
      await prefs.remove('aiStudioApiKey');
    } catch (error) {
      // Desktop/host unit tests may not register the platform plugin. Keep
      // the legacy value in memory for that run; supported app platforms use
      // the secure store and never persist it in preferences.
      debugPrint('Secure credential store unavailable: $error');
    }
    return legacy.copyWith(
      openRouterApiKey: openRouterKey,
      aiStudioApiKey: aiStudioKey,
    );
  }

  double _clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  // --- 更新方法 (Delegators) ---

  Future<void> updateSelectedLevels(Set<String> levels) async {
    state = state.copyWith(selectedLevels: levels.toList());
    _debouncedSave();
  }

  Future<void> updateWordsPerSession(int count) async {
    final nextState = _maybeSetCustomMode(
      state.copyWith(wordsPerSession: count),
    );
    if (nextState == state) return;
    state = nextState;
    _debouncedSave();
  }

  Future<void> updateTimeLimitMs(int timeMs) async {
    state = _maybeSetCustomMode(state.copyWith(timeLimitMs: timeMs));
    _debouncedSave();
  }

  Future<void> updateOrderPolicy(String policy) async {
    state = state.copyWith(orderPolicy: policy);
    _debouncedSave();
  }

  Future<void> updateStudyNewWords(bool enabled) async {
    state = state.copyWith(
      session: state.session.copyWith(studyNewWords: enabled),
    );
    _debouncedSave();
  }

  Future<void> updateDelayProfile(DelayProfile profile) async {
    state = state.copyWith(delayProfile: profile);
    _debouncedSave();
  }

  Future<void> updateSlowThreshold(double threshold) async {
    state = state.copyWith(slowThreshold: threshold);
    _debouncedSave();
  }

  Future<void> updateLeechWordsPerSession(int count) async {
    state = state.copyWith(leechWordsPerSession: count);
    _debouncedSave();
  }

  Future<void> updateNewCardRatio(double ratio) async {
    state = _maybeSetCustomMode(state.copyWith(newCardRatio: ratio));
    _debouncedSave();
  }

  Future<void> updateDailyNewLimit(int limit) async {
    state = _maybeSetCustomMode(state.copyWith(dailyNewLimit: limit));
    _debouncedSave();
  }

  Future<void> updateLearningMode(LearningMode mode) async {
    state = state.copyWith(learningMode: mode);
    _debouncedSave();
  }

  /// 应用预设学习模式
  Future<void> applyPreset(LearningMode mode) async {
    if (mode == LearningMode.custom) {
      await updateLearningMode(mode);
      return;
    }

    final preset = LearningModePreset.getPreset(mode);
    if (preset == null) return;

    state = state.copyWith(
      wordsPerSession: preset.wordsPerSession,
      newCardRatio: preset.newCardRatio,
      dailyNewLimit: preset.dailyNewLimit,
      timeLimitMs: preset.timeLimitMs,
      learningMode: mode,
    );
    _debouncedSave();
  }

  AppSettings _maybeSetCustomMode(AppSettings settings) {
    if (settings.learningMode == LearningMode.custom) return settings;
    final preset = LearningModePreset.getPreset(settings.learningMode);
    if (preset == null) return settings;
    final matchesPreset =
        settings.wordsPerSession == preset.wordsPerSession &&
        settings.newCardRatio == preset.newCardRatio &&
        settings.dailyNewLimit == preset.dailyNewLimit &&
        settings.timeLimitMs == preset.timeLimitMs;
    if (matchesPreset) return settings;
    return settings.copyWith(learningMode: LearningMode.custom);
  }

  Future<void> updateLeechPolicy({
    int? lapsesThreshold,
    bool? includeMarked,
  }) async {
    state = state.copyWith(
      leechLapsesThreshold: lapsesThreshold ?? state.leechLapsesThreshold,
      leechIncludeMarked: includeMarked ?? state.leechIncludeMarked,
    );
    _debouncedSave();
  }

  Future<void> updateTtsSettings({
    String? locale,
    double? rate,
    double? pitch,
    bool? autoPlay,
    bool? onWrong,
  }) async {
    state = state.copyWith(
      ttsLocale: locale ?? state.ttsLocale,
      ttsRate: rate ?? state.ttsRate,
      ttsPitch: pitch ?? state.ttsPitch,
      ttsAutoPlay: autoPlay ?? state.ttsAutoPlay,
      ttsOnWrong: onWrong ?? state.ttsOnWrong,
    );
    _debouncedSave();
  }

  Future<void> updateSrsConfig({
    double? alphaStability,
    double? betaFailure,
    double? gammaInterval,
    int? maxIntervalDays,
  }) async {
    final nextAlpha = alphaStability != null
        ? _clampDouble(alphaStability, 0.05, 1.0)
        : state.srsAlphaStability;
    final nextBeta = betaFailure != null
        ? _clampDouble(betaFailure, 0.5, 5.0)
        : state.srsBetaFailure;
    final nextGamma = gammaInterval != null
        ? _clampDouble(gammaInterval, 0.2, 5.0)
        : state.srsGammaInterval;
    final nextMaxInterval = maxIntervalDays != null
        ? _clampInt(maxIntervalDays, 1, 365)
        : state.srsMaxIntervalDays;

    state = state.copyWith(
      srsAlphaStability: nextAlpha,
      srsBetaFailure: nextBeta,
      srsGammaInterval: nextGamma,
      srsMaxIntervalDays: nextMaxInterval,
    );
    _debouncedSave();
  }

  Future<void> updateAccessibility({
    bool? highContrast,
    String? uiLocale,
  }) async {
    state = state.copyWith(
      highContrast: highContrast ?? state.highContrast,
      uiLocale: uiLocale ?? state.uiLocale,
    );
    _debouncedSave();
  }

  Future<void> updateOpenRouterSettings({
    String? apiKey,
    String? defaultModel,
  }) async {
    final nextDefault = defaultModel ?? state.openRouterDefaultModel;
    state = state.copyWith(
      openRouterApiKey: apiKey ?? state.openRouterApiKey,
      openRouterDefaultModel: nextDefault,
      aiDefaultModel: state.aiProvider == 'openrouter'
          ? nextDefault
          : state.aiDefaultModel,
    );
    _debouncedSave();
  }

  Future<void> updateAiStudioSettings({
    String? apiKey,
    String? defaultModel,
  }) async {
    final nextDefault = defaultModel ?? state.aiStudioDefaultModel;
    state = state.copyWith(
      aiStudioApiKey: apiKey ?? state.aiStudioApiKey,
      aiStudioDefaultModel: nextDefault,
      aiDefaultModel: state.aiProvider == 'aistudio'
          ? nextDefault
          : state.aiDefaultModel,
    );
    _debouncedSave();
  }

  Future<void> updateAiProvider({
    required String provider,
    String? defaultModel,
  }) async {
    final nextDefault =
        defaultModel ??
        (provider == 'aistudio'
            ? state.aiStudioDefaultModel
            : state.openRouterDefaultModel);
    state = state.copyWith(aiProvider: provider, aiDefaultModel: nextDefault);
    _debouncedSave();
  }

  Future<void> updateThemeStyle(String themeStyle) async {
    final isHighContrast = themeStyle == 'highContrast';
    state = state.copyWith(
      themeStyle: themeStyle,
      highContrast: isHighContrast,
    );
    _debouncedSave();
  }

  Future<void> resetToDefaults() async {
    state = AppSettings.defaultSettings;
    _debouncedSave();
  }

  int getDailyNewRemaining() {
    final updated = _ensureDailyNewFresh(state);
    if (updated != state) {
      state = updated;
      _debouncedSave();
    }
    final limit = updated.algorithm.dailyNewLimit;
    final remaining = limit - updated.dailyNewUsed;
    return remaining.clamp(0, limit);
  }

  Future<void> consumeDailyNew(int count) async {
    final updated = _ensureDailyNewFresh(state);
    final newUsed = (updated.dailyNewUsed + count).clamp(
      0,
      updated.algorithm.dailyNewLimit,
    );
    state = updated.copyWith(dailyNewUsed: newUsed);
    _debouncedSave();
  }

  AppSettings _ensureDailyNewFresh(AppSettings settings) {
    final today = _todayKey();
    if (settings.dailyNewDate != today) {
      return settings.copyWith(dailyNewDate: today, dailyNewUsed: 0);
    }
    return settings;
  }

  String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<String> stageCustomSession(List<int> wordIds) async {
    if (wordIds.isEmpty) return '';
    final sessionId = 'custom_${DateTime.now().microsecondsSinceEpoch}';
    state = state.copyWith(
      currentSessionId: sessionId,
      currentProgress: 0,
      totalWords: wordIds.length,
      remainingWordIds: wordIds,
    );
    // 显式编排的新会话必须让旧的进行中检查点失效。
    // TestScreen 的恢复判据是「检查点是否可恢复」，若此处不清理，用户从
    // 日历/疑难词/错题入口新选的词会被旧检查点顶掉，恢复成上一轮会话。
    await _discardSessionCheckpoint();
    _debouncedSave();
    return sessionId;
  }

  Future<void> clearTestProgress() async {
    debugPrint('=== clearTestProgress called ===');
    state = state.clearProgress();
    await _discardSessionCheckpoint();
    _debouncedSave();
    debugPrint('Settings saved');
  }

  /// 删除持久化的会话检查点（与 [SessionCheckpointStore] 共用同一个 key）。
  Future<void> _discardSessionCheckpoint() async {
    final prefsAsync = _prefsAsync;
    if (prefsAsync is AsyncData<SharedPreferences>) {
      await prefsAsync.value.remove(SessionCheckpointStore.storageKey);
    }
  }

  @override
  set state(AppSettings value) {
    super.state = value;
  }

  @override
  void dispose() {
    _saveDebounceTimer?.cancel();
    final snapshot = mounted ? state : null;
    super.dispose();
    if (snapshot != null) {
      _saveSettings(snapshot: snapshot);
    }
  }

  void _debouncedSave() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        _saveSettings();
      }
    });
  }

  Future<void> _saveSettings({AppSettings? snapshot}) async {
    final prefsAsync = _prefsAsync;
    if (prefsAsync is AsyncData<SharedPreferences>) {
      final prefs = prefsAsync.value;
      final currentSettings = snapshot ?? (mounted ? state : null);
      if (currentSettings == null) return;

      try {
        await prefs.setString(
          'session_config',
          jsonEncode(currentSettings.session.toJson()),
        );
        await prefs.setString(
          'theme_config',
          jsonEncode(currentSettings.theme.toJson()),
        );
        await prefs.setString(
          'tts_config',
          jsonEncode(currentSettings.tts.toJson()),
        );
        await prefs.setString(
          'srs_config',
          jsonEncode(currentSettings.srs.toJson()),
        );
        await prefs.setString(
          'algorithm_config',
          jsonEncode(currentSettings.algorithm.toJson()),
        );
        final aiConfig = Map<String, dynamic>.from(currentSettings.ai.toJson())
          ..remove('openRouterApiKey')
          ..remove('aiStudioApiKey');
        await prefs.setString('ai_config', jsonEncode(aiConfig));

        try {
          if (currentSettings.openRouterApiKey.trim().isEmpty) {
            await _credentialStore.delete(_openRouterCredential);
          } else {
            await _credentialStore.write(
              _openRouterCredential,
              currentSettings.openRouterApiKey.trim(),
            );
          }
          if (currentSettings.aiStudioApiKey.trim().isEmpty) {
            await _credentialStore.delete(_aiStudioCredential);
          } else {
            await _credentialStore.write(
              _aiStudioCredential,
              currentSettings.aiStudioApiKey.trim(),
            );
          }
        } catch (error) {
          debugPrint('Secure credential save unavailable: $error');
        }

        if (currentSettings.currentSessionId != null) {
          await prefs.setString(
            'currentSessionId',
            currentSettings.currentSessionId!,
          );
        } else {
          await prefs.remove('currentSessionId');
        }
        await prefs.setInt('currentProgress', state.currentProgress);
        await prefs.setInt('totalWords', state.totalWords);
        await prefs.setString(
          'remainingWordIds',
          state.remainingWordIds.join(','),
        );
        await prefs.setString('dailyNewDate', state.dailyNewDate);
        await prefs.setInt('dailyNewUsed', state.dailyNewUsed);
      } catch (e) {
        debugPrint('Error saving settings: $e');
      }
    }
  }
}
