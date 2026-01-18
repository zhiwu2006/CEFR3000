import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'app_settings.g.dart';

/// 用于 copyWith 方法区分"未传参"和"传了null"的哨兵值
const _sentinel = Object();

/// 延迟强度配置枚举
@HiveType(typeId: 5)
enum DelayProfile {
  @HiveField(0)
  gentle, // 温和：错题延迟+2，勉强+4

  @HiveField(1)
  standard, // 标准：错题延迟+3，勉强+5

  @HiveField(2)
  aggressive, // 激进：错题延迟+5，勉强+7
}

/// 应用设置模型类
@HiveType(typeId: 6)
@JsonSerializable()
class AppSettings {
  @HiveField(0)
  final List<String> selectedLevels; // 选中的级别

  @HiveField(1)
  final int wordsPerSession; // 每轮词数

  @HiveField(2)
  final int timeLimitMs; // 每词时限（毫秒）

  @HiveField(3)
  final String orderPolicy; // 顺序策略：'by_level' 或 'random'

  @HiveField(4)
  final bool onlyLeeches; // 只练不熟开关

  @HiveField(5)
  final DelayProfile delayProfile; // 延迟强度

  @HiveField(6)
  final String ttsLocale; // TTS语言

  @HiveField(7)
  final double ttsRate; // TTS语速

  @HiveField(8)
  final double ttsPitch; // TTS音调

  @HiveField(9)
  final bool highContrast; // 高对比度主题（保留兼容）

  @HiveField(10)
  final String uiLocale; // UI语言

  @HiveField(11)
  final String? currentSessionId; // 当前测试会话ID

  @HiveField(12)
  final int currentProgress; // 当前测试进度

  @HiveField(13)
  final int totalWords; // 总词数

  @HiveField(14)
  final List<int> remainingWordIds; // 剩余单词ID列表

  @HiveField(15)
  final String themeStyle; // 主题风格：standard, highContrast, bauhaus, minimal, nature

  const AppSettings({
    required this.selectedLevels,
    required this.wordsPerSession,
    required this.timeLimitMs,
    required this.orderPolicy,
    required this.onlyLeeches,
    required this.delayProfile,
    required this.ttsLocale,
    required this.ttsRate,
    required this.ttsPitch,
    required this.highContrast,
    required this.uiLocale,
    this.currentSessionId,
    this.currentProgress = 0,
    this.totalWords = 0,
    this.remainingWordIds = const [],
    this.themeStyle = 'standard',
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => _$AppSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);

  /// 默认设置
  static AppSettings get defaultSettings => const AppSettings(
        selectedLevels: ['A1'], // 默认A1级别
        wordsPerSession: 100,
        timeLimitMs: 2000, // 2秒
        orderPolicy: 'by_level',
        onlyLeeches: false,
        delayProfile: DelayProfile.standard,
        ttsLocale: 'en-US',
        ttsRate: 0.44,
        ttsPitch: 1.0,
        highContrast: false,
        uiLocale: 'zh-CN',
        currentSessionId: null,
        currentProgress: 0,
        totalWords: 0,
        remainingWordIds: [],
        themeStyle: 'standard',
      );

  /// 获取延迟配置
  ({int wrongDelay, int slowDelay}) get delayConfig {
    switch (delayProfile) {
      case DelayProfile.gentle:
        return (wrongDelay: 2, slowDelay: 4);
      case DelayProfile.standard:
        return (wrongDelay: 3, slowDelay: 5);
      case DelayProfile.aggressive:
        return (wrongDelay: 5, slowDelay: 7);
    }
  }

  /// 获取勉强正确的时间阈值（倍数）
  double get slowThreshold => 1.5;

  /// 是否为可访问性模式（延长时限）
  bool get isAccessibilityMode => timeLimitMs >= 6000;

  /// 复制并修改指定字段
  /// 注意：对于可空字段，使用特殊的包装类来区分"未传参"和"传了null"
  AppSettings copyWith({
    Set<String>? selectedLevels,
    int? wordsPerSession,
    int? timeLimitMs,
    String? orderPolicy,
    bool? onlyLeeches,
    DelayProfile? delayProfile,
    String? ttsLocale,
    double? ttsRate,
    double? ttsPitch,
    bool? highContrast,
    String? uiLocale,
    Object? currentSessionId = _sentinel,
    int? currentProgress,
    int? totalWords,
    List<int>? remainingWordIds,
    String? themeStyle,
  }) =>
      AppSettings(
        selectedLevels: selectedLevels?.toList() ?? this.selectedLevels,
        wordsPerSession: wordsPerSession ?? this.wordsPerSession,
        timeLimitMs: timeLimitMs ?? this.timeLimitMs,
        orderPolicy: orderPolicy ?? this.orderPolicy,
        onlyLeeches: onlyLeeches ?? this.onlyLeeches,
        delayProfile: delayProfile ?? this.delayProfile,
        ttsLocale: ttsLocale ?? this.ttsLocale,
        ttsRate: ttsRate ?? this.ttsRate,
        ttsPitch: ttsPitch ?? this.ttsPitch,
        highContrast: highContrast ?? this.highContrast,
        uiLocale: uiLocale ?? this.uiLocale,
        currentSessionId: currentSessionId == _sentinel 
            ? this.currentSessionId 
            : currentSessionId as String?,
        currentProgress: currentProgress ?? this.currentProgress,
        totalWords: totalWords ?? this.totalWords,
        remainingWordIds: remainingWordIds ?? this.remainingWordIds,
        themeStyle: themeStyle ?? this.themeStyle,
      );

  @override
  String toString() => 'AppSettings(levels: $selectedLevels, words: $wordsPerSession, timeLimit: ${timeLimitMs}ms)';

  /// 获取级别集合
  Set<String> get selectedLevelsSet => selectedLevels.toSet();

  /// 是否有进行中的测试
  bool get hasActiveSession => currentSessionId != null && remainingWordIds.isNotEmpty;

  /// 获取测试进度百分比
  double get progressPercentage {
    if (totalWords == 0) return 0.0;
    return currentProgress / totalWords;
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

  /// 更新测试进度
  AppSettings updateProgress({
    String? sessionId,
    int? progress,
    int? total,
    List<int>? remaining,
  }) {
    return copyWith(
      currentSessionId: sessionId ?? currentSessionId,
      currentProgress: progress ?? currentProgress,
      totalWords: total ?? totalWords,
      remainingWordIds: remaining ?? remainingWordIds,
    );
  }
}

/// AppSettings 扩展方法
extension AppSettingsExtensions on AppSettings {
  /// 使用Set创建AppSettings
  static AppSettings withLevels(Set<String> levels) {
    return AppSettings.defaultSettings.copyWith(selectedLevels: levels);
  }
}
