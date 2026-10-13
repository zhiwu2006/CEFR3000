import 'app_settings.dart';

/// 学习模式预设方案配置
class LearningModePreset {
  final LearningMode mode;
  final String name;
  final String description;
  final String icon; // emoji 图标
  final int wordsPerSession;
  final double newCardRatio;
  final int dailyNewLimit;
  final int timeLimitMs;

  const LearningModePreset({
    required this.mode,
    required this.name,
    required this.description,
    required this.icon,
    required this.wordsPerSession,
    required this.newCardRatio,
    required this.dailyNewLimit,
    required this.timeLimitMs,
  });

  /// 获取所有预设方案
  static const Map<LearningMode, LearningModePreset> presets = {
    LearningMode.relaxed: LearningModePreset(
      mode: LearningMode.relaxed,
      name: '轻松模式',
      description: '适合学习初期，复习压力小，每天约25个新词',
      icon: '😊',
      wordsPerSession: 100,
      newCardRatio: 0.25,
      dailyNewLimit: 100,
      timeLimitMs: 2000,
    ),
    LearningMode.balanced: LearningModePreset(
      mode: LearningMode.balanced,
      name: '平衡模式',
      description: '平衡新词和复习，每天约15个新词，可持续学习（推荐）',
      icon: '⚖️',
      wordsPerSession: 100,
      newCardRatio: 0.15,
      dailyNewLimit: 100,
      timeLimitMs: 2000,
    ),
    LearningMode.review: LearningModePreset(
      mode: LearningMode.review,
      name: '复习模式',
      description: '重点复习已学单词，每天约12个新词，适合复习压力大的阶段',
      icon: '📚',
      wordsPerSession: 100,
      newCardRatio: 0.10,
      dailyNewLimit: 100,
      timeLimitMs: 2000,
    ),
    LearningMode.fast: LearningModePreset(
      mode: LearningMode.fast,
      name: '快速模式',
      description: '快速学习新词，每天约45个新词，适合短期冲刺',
      icon: '⚡',
      wordsPerSession: 150,
      newCardRatio: 0.30,
      dailyNewLimit: 150,
      timeLimitMs: 1500,
    ),
  };

  /// 获取预设方案
  static LearningModePreset? getPreset(LearningMode mode) {
    return presets[mode];
  }

  /// 获取新词数量（每天）
  int get dailyNewWords => (wordsPerSession * newCardRatio).round();
}
