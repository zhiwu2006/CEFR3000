import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_config.g.dart';

/// 学习会话配置
@HiveType(typeId: 10)
@JsonSerializable()
class SessionSettings {
  @HiveField(0)
  final List<String> selectedLevels;

  @HiveField(1)
  final int wordsPerSession;

  @HiveField(2)
  final int timeLimitMs;

  @HiveField(3)
  final String orderPolicy; // 'random', 'level'

  @HiveField(4)
  final bool onlyLeeches;

  @HiveField(5)
  final String learningMode;

  /// 新词第一次出现先看学习卡，隔几题再考。
  @HiveField(6, defaultValue: true)
  @JsonKey(defaultValue: true)
  final bool studyNewWords;

  const SessionSettings({
    this.selectedLevels = const ['A1'],
    this.wordsPerSession = 100,
    this.timeLimitMs = 2000,
    this.orderPolicy = 'random',
    this.onlyLeeches = false,
    this.learningMode = 'standard',
    this.studyNewWords = true,
  });

  Set<String> get selectedLevelsSet => selectedLevels.toSet();

  SessionSettings copyWith({
    List<String>? selectedLevels,
    int? wordsPerSession,
    int? timeLimitMs,
    String? orderPolicy,
    bool? onlyLeeches,
    String? learningMode,
    bool? studyNewWords,
  }) {
    return SessionSettings(
      selectedLevels: selectedLevels ?? this.selectedLevels,
      wordsPerSession: wordsPerSession ?? this.wordsPerSession,
      timeLimitMs: timeLimitMs ?? this.timeLimitMs,
      orderPolicy: orderPolicy ?? this.orderPolicy,
      onlyLeeches: onlyLeeches ?? this.onlyLeeches,
      learningMode: learningMode ?? this.learningMode,
      studyNewWords: studyNewWords ?? this.studyNewWords,
    );
  }

  factory SessionSettings.fromJson(Map<String, dynamic> json) =>
      _$SessionSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$SessionSettingsToJson(this);
}

/// 主题与UI配置
@HiveType(typeId: 11)
@JsonSerializable()
class ThemeSettings {
  @HiveField(0)
  final String themeStyle;

  @HiveField(1)
  final bool highContrast;

  @HiveField(2)
  final String uiLocale;

  const ThemeSettings({
    this.themeStyle = 'digitalism',
    this.highContrast = false,
    this.uiLocale = 'zh_CN',
  });

  ThemeSettings copyWith({
    String? themeStyle,
    bool? highContrast,
    String? uiLocale,
  }) {
    return ThemeSettings(
      themeStyle: themeStyle ?? this.themeStyle,
      highContrast: highContrast ?? this.highContrast,
      uiLocale: uiLocale ?? this.uiLocale,
    );
  }

  factory ThemeSettings.fromJson(Map<String, dynamic> json) =>
      _$ThemeSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$ThemeSettingsToJson(this);
}

/// 语音合成配置
@HiveType(typeId: 12)
@JsonSerializable()
class TtsSettings {
  @HiveField(0)
  final String locale;

  @HiveField(1)
  final double rate;

  @HiveField(2)
  final double pitch;

  @HiveField(3)
  final bool autoPlay;

  @HiveField(4)
  final bool onWrong;

  const TtsSettings({
    this.locale = 'en-US',
    this.rate = 0.5,
    this.pitch = 1.0,
    this.autoPlay = true,
    this.onWrong = true,
  });

  TtsSettings copyWith({
    String? locale,
    double? rate,
    double? pitch,
    bool? autoPlay,
    bool? onWrong,
  }) {
    return TtsSettings(
      locale: locale ?? this.locale,
      rate: rate ?? this.rate,
      pitch: pitch ?? this.pitch,
      autoPlay: autoPlay ?? this.autoPlay,
      onWrong: onWrong ?? this.onWrong,
    );
  }

  factory TtsSettings.fromJson(Map<String, dynamic> json) =>
      _$TtsSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$TtsSettingsToJson(this);
}

/// 记忆算法配置
@HiveType(typeId: 13)
@JsonSerializable()
class SrsSettings {
  @HiveField(0)
  final double alphaStability;

  @HiveField(1)
  final double betaFailure;

  @HiveField(2)
  final double gammaInterval;

  @HiveField(3)
  final int maxIntervalDays;

  // 延迟策略配置 (简单起见存为字符串或枚举索引，这里直接存配置名)
  @HiveField(4)
  final String delayProfile;

  @HiveField(5)
  final double slowThreshold;

  const SrsSettings({
    this.alphaStability = 0.18,
    this.betaFailure = 1.2,
    this.gammaInterval = 1.0,
    this.maxIntervalDays = 90,
    this.delayProfile = 'standard',
    this.slowThreshold = 1.5,
  });

  SrsSettings copyWith({
    double? alphaStability,
    double? betaFailure,
    double? gammaInterval,
    int? maxIntervalDays,
    String? delayProfile,
    double? slowThreshold,
  }) {
    return SrsSettings(
      alphaStability: alphaStability ?? this.alphaStability,
      betaFailure: betaFailure ?? this.betaFailure,
      gammaInterval: gammaInterval ?? this.gammaInterval,
      maxIntervalDays: maxIntervalDays ?? this.maxIntervalDays,
      delayProfile: delayProfile ?? this.delayProfile,
      slowThreshold: slowThreshold ?? this.slowThreshold,
    );
  }

  factory SrsSettings.fromJson(Map<String, dynamic> json) =>
      _$SrsSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$SrsSettingsToJson(this);
}

/// 难词与新词策略配置
@HiveType(typeId: 14)
@JsonSerializable()
class AlgorithmSettings {
  @HiveField(0)
  final int leechWordsPerSession;

  @HiveField(1)
  final double newCardRatio;

  @HiveField(2)
  final int dailyNewLimit;

  @HiveField(3)
  final int leechLapsesThreshold;

  @HiveField(4)
  final bool leechIncludeMarked;

  const AlgorithmSettings({
    this.leechWordsPerSession = 5,
    this.newCardRatio = 0.3,
    this.dailyNewLimit = 100,
    this.leechLapsesThreshold = 2,
    this.leechIncludeMarked = true,
  });

  AlgorithmSettings copyWith({
    int? leechWordsPerSession,
    double? newCardRatio,
    int? dailyNewLimit,
    int? leechLapsesThreshold,
    bool? leechIncludeMarked,
  }) {
    return AlgorithmSettings(
      leechWordsPerSession: leechWordsPerSession ?? this.leechWordsPerSession,
      newCardRatio: newCardRatio ?? this.newCardRatio,
      dailyNewLimit: dailyNewLimit ?? this.dailyNewLimit,
      leechLapsesThreshold: leechLapsesThreshold ?? this.leechLapsesThreshold,
      leechIncludeMarked: leechIncludeMarked ?? this.leechIncludeMarked,
    );
  }

  factory AlgorithmSettings.fromJson(Map<String, dynamic> json) =>
      _$AlgorithmSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$AlgorithmSettingsToJson(this);
}

/// AI API 配置
@HiveType(typeId: 15)
@JsonSerializable()
class AiSettings {
  @HiveField(0)
  final String provider; // 'openrouter', 'aistudio'

  @HiveField(1)
  final String defaultModel;

  @HiveField(2)
  final String openRouterApiKey;

  @HiveField(3)
  final String openRouterDefaultModel;

  @HiveField(4)
  final String aiStudioApiKey;

  @HiveField(5)
  final String aiStudioDefaultModel;

  const AiSettings({
    this.provider = 'openrouter',
    this.defaultModel = '',
    this.openRouterApiKey = '',
    this.openRouterDefaultModel = '',
    this.aiStudioApiKey = '',
    this.aiStudioDefaultModel = '',
  });

  AiSettings copyWith({
    String? provider,
    String? defaultModel,
    String? openRouterApiKey,
    String? openRouterDefaultModel,
    String? aiStudioApiKey,
    String? aiStudioDefaultModel,
  }) {
    return AiSettings(
      provider: provider ?? this.provider,
      defaultModel: defaultModel ?? this.defaultModel,
      openRouterApiKey: openRouterApiKey ?? this.openRouterApiKey,
      openRouterDefaultModel:
          openRouterDefaultModel ?? this.openRouterDefaultModel,
      aiStudioApiKey: aiStudioApiKey ?? this.aiStudioApiKey,
      aiStudioDefaultModel: aiStudioDefaultModel ?? this.aiStudioDefaultModel,
    );
  }

  factory AiSettings.fromJson(Map<String, dynamic> json) =>
      _$AiSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$AiSettingsToJson(this);
}
