import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'user_config.dart';

part 'app_settings.g.dart';

/// 用于 copyWith 方法区分"未传参"和"传了null"的哨兵值
const _sentinel = Object();

/// 延迟强度配置枚举 (保留为了兼容部分逻辑，实际存为String)
enum DelayProfile { gentle, standard, aggressive }

/// 学习模式枚举 (保留为了兼容部分逻辑，实际存为String)
enum LearningMode { relaxed, balanced, review, fast, custom }

/// 应用设置模型类
/// 重构后：作为聚合根，代理各子配置对象
@HiveType(typeId: 6)
@JsonSerializable()
class AppSettings {
  @HiveField(0)
  final SessionSettings session;

  @HiveField(1)
  final ThemeSettings theme;

  @HiveField(2)
  final TtsSettings tts;

  @HiveField(3)
  final SrsSettings srs;

  @HiveField(4)
  final AlgorithmSettings algorithm;

  @HiveField(5)
  final AiSettings ai;

  // --- 顶层状态 (Session State) ---

  @HiveField(10)
  final String? currentSessionId;

  @HiveField(11)
  final int currentProgress;

  @HiveField(12)
  final int totalWords;

  @HiveField(13)
  final List<int> remainingWordIds;

  @HiveField(14)
  final String dailyNewDate;

  @HiveField(15)
  final int dailyNewUsed;

  const AppSettings({
    required this.session,
    required this.theme,
    required this.tts,
    required this.srs,
    required this.algorithm,
    required this.ai,
    this.currentSessionId,
    this.currentProgress = 0,
    this.totalWords = 0,
    this.remainingWordIds = const [],
    this.dailyNewDate = '',
    this.dailyNewUsed = 0,
  });

  /// 默认设置
  static AppSettings get defaultSettings => const AppSettings(
    session: SessionSettings(),
    theme: ThemeSettings(),
    tts: TtsSettings(),
    srs: SrsSettings(),
    algorithm: AlgorithmSettings(),
    ai: AiSettings(),
  );

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);

  // ========================================================================
  // 兼容性 Getters - 桥接到子对象
  // ========================================================================

  // Session
  List<String> get selectedLevels => session.selectedLevels;
  Set<String> get selectedLevelsSet => session.selectedLevelsSet;
  int get wordsPerSession => session.wordsPerSession;
  int get timeLimitMs => session.timeLimitMs;
  String get orderPolicy => session.orderPolicy;
  bool get onlyLeeches => session.onlyLeeches;
  LearningMode get learningMode => _parseLearningMode(session.learningMode);

  // Theme
  String get themeStyle => theme.themeStyle;
  bool get highContrast => theme.highContrast;
  String get uiLocale => theme.uiLocale;

  // TTS
  String get ttsLocale => tts.locale;
  double get ttsRate => tts.rate;
  double get ttsPitch => tts.pitch;
  bool get ttsAutoPlay => tts.autoPlay;
  bool get ttsOnWrong => tts.onWrong;

  // SRS
  double get srsAlphaStability => srs.alphaStability;
  double get srsBetaFailure => srs.betaFailure;
  double get srsGammaInterval => srs.gammaInterval;
  int get srsMaxIntervalDays => srs.maxIntervalDays;
  DelayProfile get delayProfile => _parseDelayProfile(srs.delayProfile);
  double get slowThreshold => srs.slowThreshold;

  // Algorithm
  int get leechWordsPerSession => algorithm.leechWordsPerSession;
  double get newCardRatio => algorithm.newCardRatio;
  int get dailyNewLimit => algorithm.dailyNewLimit;
  int get leechLapsesThreshold => algorithm.leechLapsesThreshold;
  bool get leechIncludeMarked => algorithm.leechIncludeMarked;

  // AI
  String get aiProvider => ai.provider;
  String get aiDefaultModel => ai.defaultModel;
  String get openRouterApiKey => ai.openRouterApiKey;
  String get openRouterDefaultModel => ai.openRouterDefaultModel;
  String get aiStudioApiKey => ai.aiStudioApiKey;
  String get aiStudioDefaultModel => ai.aiStudioDefaultModel;

  // ========================================================================
  // 辅助逻辑
  // ========================================================================

  LearningMode _parseLearningMode(String val) {
    return LearningMode.values.firstWhere(
      (e) => e.name == val,
      orElse: () => LearningMode.balanced,
    );
  }

  DelayProfile _parseDelayProfile(String val) {
    return DelayProfile.values.firstWhere(
      (e) => e.name == val,
      orElse: () => DelayProfile.standard,
    );
  }

  /// 获取延迟配置
  ({int wrongDelay, int slowDelay}) get delayConfig {
    switch (delayProfile) {
      case DelayProfile.gentle:
        return (wrongDelay: 3, slowDelay: 4);
      case DelayProfile.standard:
        return (wrongDelay: 3, slowDelay: 5);
      case DelayProfile.aggressive:
        return (wrongDelay: 5, slowDelay: 7);
    }
  }

  // 说明：原先的 `hasActiveSession` 与 `progressPercentage` 两个 getter 已移除。
  // 它们以 `currentSessionId` 判断「是否有进行中的会话」，但该字段只由
  // `stageCustomSession` 写入 —— 首页「开始学习」从不写它，会漏报主路径；
  // 而进度更新入口（原 `updateTestProgress`）零调用，对自定义会话恒为 0 进度。
  // 口径本身就不成立，留着还会被误当作恢复门槛（这正是 4.1 的成因）。
  //
  // 现在「是否存在未完成会话」的唯一来源是 `SessionCheckpoint.isResumable`，
  // 消费方为 `learningStatsProvider`（统计页「当前会话」卡片）与
  // `test_screen.dart` 的恢复判据。
  //
  // 下列字段仍由 `stageCustomSession` 写入、`clearTestProgress` 清除，仅为
  // 兼容既有持久化数据而保留，不再作为会话权威；彻底删除需要改持久化 schema。

  // ========================================================================
  // 获取兼容的 copyWith
  // ========================================================================

  AppSettings copyWith({
    // Sub-settings
    SessionSettings? session,
    ThemeSettings? theme,
    TtsSettings? tts,
    SrsSettings? srs,
    AlgorithmSettings? algorithm,
    AiSettings? ai,

    // Session (Compatibility)
    List<String>? selectedLevels,
    int? wordsPerSession,
    int? timeLimitMs,
    String? orderPolicy,
    bool? onlyLeeches,
    LearningMode? learningMode,

    // Theme (Compatibility)
    String? themeStyle,
    bool? highContrast,
    String? uiLocale,

    // TTS (Compatibility)
    String? ttsLocale,
    double? ttsRate,
    double? ttsPitch,
    bool? ttsAutoPlay,
    bool? ttsOnWrong,

    // SRS (Compatibility)
    double? srsAlphaStability,
    double? srsBetaFailure,
    double? srsGammaInterval,
    int? srsMaxIntervalDays,
    DelayProfile? delayProfile,
    double? slowThreshold,

    // Algorithm (Compatibility)
    int? leechWordsPerSession,
    double? newCardRatio,
    int? dailyNewLimit,
    int? leechLapsesThreshold,
    bool? leechIncludeMarked,

    // AI (Compatibility)
    String? aiProvider,
    String? aiDefaultModel,
    String? openRouterApiKey,
    String? openRouterDefaultModel,
    String? aiStudioApiKey,
    String? aiStudioDefaultModel,

    // State
    Object? currentSessionId = _sentinel,
    int? currentProgress,
    int? totalWords,
    List<int>? remainingWordIds,
    String? dailyNewDate,
    int? dailyNewUsed,
  }) {
    return AppSettings(
      session:
          session ??
          this.session.copyWith(
            selectedLevels: selectedLevels,
            wordsPerSession: wordsPerSession,
            timeLimitMs: timeLimitMs,
            orderPolicy: orderPolicy,
            onlyLeeches: onlyLeeches,
            learningMode: learningMode?.name,
          ),
      theme:
          theme ??
          this.theme.copyWith(
            themeStyle: themeStyle,
            highContrast: highContrast,
            uiLocale: uiLocale,
          ),
      tts:
          tts ??
          this.tts.copyWith(
            locale: ttsLocale,
            rate: ttsRate,
            pitch: ttsPitch,
            autoPlay: ttsAutoPlay,
            onWrong: ttsOnWrong,
          ),
      srs:
          srs ??
          this.srs.copyWith(
            alphaStability: srsAlphaStability,
            betaFailure: srsBetaFailure,
            gammaInterval: srsGammaInterval,
            maxIntervalDays: srsMaxIntervalDays,
            delayProfile: delayProfile?.name,
            slowThreshold: slowThreshold,
          ),
      algorithm:
          algorithm ??
          this.algorithm.copyWith(
            leechWordsPerSession: leechWordsPerSession,
            newCardRatio: newCardRatio,
            dailyNewLimit: dailyNewLimit,
            leechLapsesThreshold: leechLapsesThreshold,
            leechIncludeMarked: leechIncludeMarked,
          ),
      ai:
          ai ??
          this.ai.copyWith(
            provider: aiProvider,
            defaultModel: aiDefaultModel,
            openRouterApiKey: openRouterApiKey,
            openRouterDefaultModel: openRouterDefaultModel,
            aiStudioApiKey: aiStudioApiKey,
            aiStudioDefaultModel: aiStudioDefaultModel,
          ),
      currentSessionId: currentSessionId == _sentinel
          ? this.currentSessionId
          : currentSessionId as String?,
      currentProgress: currentProgress ?? this.currentProgress,
      totalWords: totalWords ?? this.totalWords,
      remainingWordIds: remainingWordIds ?? this.remainingWordIds,
      dailyNewDate: dailyNewDate ?? this.dailyNewDate,
      dailyNewUsed: dailyNewUsed ?? this.dailyNewUsed,
    );
  }

  /// 清除测试进度
  AppSettings clearProgress() {
    return copyWith(
      currentSessionId: null,
      currentProgress: 0,
      totalWords: 0,
      remainingWordIds: [],
    );
  }
}
