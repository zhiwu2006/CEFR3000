import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../session/base_providers.dart';
import '../data/progress_repository.dart';
import '../models/models.dart';
import '../models/word_status.dart';
import '../theme/app_theme.dart';
import '../theme/theme_style.dart';
import '../utils/responsive_layout.dart';
import '../data/hive_word_repository.dart';

/// 设置页面
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showChangelog(context),
          ),
        ],
      ),
      body: ResponsiveLayout.buildCenteredContainer(
        context: context,
        child: ResponsiveLayout.buildResponsive(
          context: context,
          mobile: _buildMobileLayout(context, theme, ref, settings),
          tablet: _buildTabletLayout(context, theme, ref, settings),
        ),
      ),
    );
  }

  Widget _buildWordStatusSection(BuildContext context, ThemeData theme, WidgetRef ref, AppSettings settings) {
    final repo = ref.read(progressRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      child: FutureBuilder<List<WordStudyStatus>>(
        future: repo.getWordStatuses(settings.selectedLevelsSet),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox();
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox();
          }

          final statuses = snapshot.data!;
          final byLevel = <String, List<WordStudyStatus>>{};
          for (final s in statuses) {
            byLevel.putIfAbsent(s.word.level, () => []).add(s);
          }

          final levels = byLevel.keys.toList()..sort();
          final tiles = <Widget>[];
          for (final level in levels) {
            final list = byLevel[level]!;
            final learned = list.where((s) => s.isLearned).length;
            final mastered = list.where((s) => s.isMastered).length;
            tiles.add(
              ExpansionTile(
                title: Text('等级 $level'),
                subtitle: Text('总数 ${list.length} · 已学习 $learned · 已掌握 $mastered'),
                children: list.take(100).map((s) => _buildWordStatusRow(context, s)).toList(),
              ),
            );
            tiles.add(const Divider(height: 8));
          }

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('单词学习状态', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...tiles,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWordStatusRow(BuildContext context, WordStudyStatus status) {
    final theme = Theme.of(context);
    final state = status.state;
    final isMastered = status.isMastered;
    final isLearned = status.isLearned;

    Color dotColor;
    String label;
    if (isMastered) {
      dotColor = Colors.green;
      label = '已掌握';
    } else if (isLearned) {
      dotColor = Colors.blue;
      label = '学习中';
    } else {
      dotColor = Colors.grey;
      label = '未开始';
    }

    final lastReview = state?.lastReview != null
        ? '${state!.lastReview.year}-${state.lastReview.month}-${state.lastReview.day}'
        : '—';

    return ListTile(
      dense: true,
      leading: CircleAvatar(radius: 6, backgroundColor: dotColor),
      title: Text(status.word.headword),
      subtitle: Text('${status.word.level} ${status.word.pos} · $label · 复习次数 ${status.attemptCount} · 上次 ${lastReview}'),
      trailing: isMastered ? const Icon(Icons.check_circle, color: Colors.green) : null,
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppTheme.paddingMedium),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildLevelSelector(BuildContext context, WidgetRef ref, AppSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('选择级别'),
        const SizedBox(height: AppTheme.paddingSmall),
        Wrap(
          spacing: AppTheme.paddingSmall,
          children: ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'].map((level) {
            final isSelected = settings.selectedLevelsSet.contains(level);
            return FilterChip(
              label: Text(level),
              selected: isSelected,
              selectedColor: AppTheme.getLevelBadgeColor(level).withOpacity(0.2),
              onSelected: (selected) {
                final newLevels = Set<String>.from(settings.selectedLevelsSet);
                if (selected) {
                  newLevels.add(level);
                } else {
                  newLevels.remove(level);
                }
                if (newLevels.isNotEmpty) {
                  ref.read(appSettingsProvider.notifier).updateSelectedLevels(newLevels);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWordsPerSessionSlider(BuildContext context, WidgetRef ref, AppSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('每轮词数: ${settings.wordsPerSession}'),
        Slider(
          value: settings.wordsPerSession.toDouble(),
          min: 10,
          max: 200,
          divisions: 19,
          label: '${settings.wordsPerSession}',
          onChanged: (value) {
            ref.read(appSettingsProvider.notifier).updateWordsPerSession(value.round());
          },
        ),
      ],
    );
  }

  Widget _buildTimeLimitSlider(BuildContext context, WidgetRef ref, AppSettings settings) {
    final seconds = settings.timeLimitMs / 1000;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('时间限制: ${seconds.toStringAsFixed(1)}s'),
        Slider(
          value: settings.timeLimitMs.toDouble(),
          min: 1500,
          max: 6000,
          divisions: 9,
          label: '${seconds.toStringAsFixed(1)}s',
          onChanged: (value) {
            ref.read(appSettingsProvider.notifier).updateTimeLimitMs(value.round());
          },
        ),
      ],
    );
  }

  Widget _buildOrderPolicySelector(BuildContext context, WidgetRef ref, AppSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('出题顺序'),
        RadioListTile<String>(
          title: const Text('按级别'),
          subtitle: const Text('A1 → A2 → B1 → B2'),
          value: 'by_level',
          groupValue: settings.orderPolicy,
          onChanged: (value) {
            if (value != null) {
              ref.read(appSettingsProvider.notifier).updateOrderPolicy(value);
            }
          },
        ),
        RadioListTile<String>(
          title: const Text('随机'),
          subtitle: const Text('完全随机顺序'),
          value: 'random',
          groupValue: settings.orderPolicy,
          onChanged: (value) {
            if (value != null) {
              ref.read(appSettingsProvider.notifier).updateOrderPolicy(value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildDelayProfileSelector(BuildContext context, WidgetRef ref, AppSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('延迟回放强度'),
        ...DelayProfile.values.map((profile) {
          String title, subtitle;
          switch (profile) {
            case DelayProfile.gentle:
              title = '温和';
              subtitle = '错题延迟2题，勉强正确延迟4题';
              break;
            case DelayProfile.standard:
              title = '标准';
              subtitle = '错题延迟3题，勉强正确延迟5题';
              break;
            case DelayProfile.aggressive:
              title = '激进';
              subtitle = '错题延迟5题，勉强正确延迟7题';
              break;
          }
          
          return RadioListTile<DelayProfile>(
            title: Text(title),
            subtitle: Text(subtitle),
            value: profile,
            groupValue: settings.delayProfile,
            onChanged: (value) {
              if (value != null) {
                ref.read(appSettingsProvider.notifier).updateDelayProfile(value);
              }
            },
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTtsLocaleSelector(BuildContext context, WidgetRef ref, AppSettings settings) {
    const locales = {
      'en-US': '美式英语',
      'en-GB': '英式英语',
    };
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('语音语言'),
        DropdownButton<String>(
          value: settings.ttsLocale,
          isExpanded: true,
          items: locales.entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              ref.read(appSettingsProvider.notifier).updateTtsSettings(locale: value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildTtsRateSlider(BuildContext context, WidgetRef ref, AppSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('语速: ${settings.ttsRate.toStringAsFixed(2)}'),
        Slider(
          value: settings.ttsRate,
          min: 0.2,
          max: 1.0,
          divisions: 8,
          label: settings.ttsRate.toStringAsFixed(2),
          onChanged: (value) {
            ref.read(appSettingsProvider.notifier).updateTtsSettings(rate: value);
          },
        ),
      ],
    );
  }

  Widget _buildTtsPitchSlider(BuildContext context, WidgetRef ref, AppSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('音调: ${settings.ttsPitch.toStringAsFixed(2)}'),
        Slider(
          value: settings.ttsPitch,
          min: 0.5,
          max: 2.0,
          divisions: 15,
          label: settings.ttsPitch.toStringAsFixed(2),
          onChanged: (value) {
            ref.read(appSettingsProvider.notifier).updateTtsSettings(pitch: value);
          },
        ),
      ],
    );
  }

  Widget _buildHighContrastSwitch(BuildContext context, WidgetRef ref, AppSettings settings) {
    return _buildThemeSelector(context, ref, settings);
  }

  /// 主题风格选择器
  Widget _buildThemeSelector(BuildContext context, WidgetRef ref, AppSettings settings) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '主题风格',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: availableThemes.map((themeInfo) {
            final isSelected = settings.themeStyle == themeInfo.style.name;
            return _buildThemeCard(
              context: context,
              ref: ref,
              themeInfo: themeInfo,
              isSelected: isSelected,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildThemeCard({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeStyleInfo themeInfo,
    required bool isSelected,
  }) {
    final theme = Theme.of(context);
    final colors = _getThemePreviewColors(themeInfo.style);
    
    return GestureDetector(
      onTap: () {
        ref.read(appSettingsProvider.notifier).updateThemeStyle(themeInfo.style.name);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Column(
          children: [
            // 主题预览色块
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: colors[0],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: colors[1],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: colors[2],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 主题图标
            Text(
              themeInfo.icon,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 4),
            // 主题名称
            Text(
              themeInfo.name,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 获取主题预览颜色
  List<Color> _getThemePreviewColors(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.standard:
        return [
          const Color(0xFF2E3A59),
          const Color(0xFF4A5F7A),
          const Color(0xFF4CAF50),
        ];
      case ThemeStyle.highContrast:
        return [
          const Color(0xFF000000),
          const Color(0xFFFFFFFF),
          const Color(0xFF00FF00),
        ];
      case ThemeStyle.bauhaus:
        return [
          const Color(0xFFD02020),
          const Color(0xFF1040C0),
          const Color(0xFFF0C020),
        ];
      case ThemeStyle.minimal:
        return [
          const Color(0xFF1A1A1A),
          const Color(0xFFFAFAFA),
          const Color(0xFF0066FF),
        ];
      case ThemeStyle.nature:
        return [
          const Color(0xFF2D5A27),
          const Color(0xFF4A7C43),
          const Color(0xFF8B5E3C),
        ];
      case ThemeStyle.cyberpunk:
        return [
          const Color(0xFF0A0A0F),
          const Color(0xFF00FF88),
          const Color(0xFFFF00FF),
        ];
    }
  }

  Widget _buildUiLocaleSelector(BuildContext context, WidgetRef ref, AppSettings settings) {
    const locales = {
      'zh-CN': '简体中文',
      'zh-TW': '繁体中文',
      'en-US': 'English',
    };
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('界面语言'),
        DropdownButton<String>(
          value: settings.uiLocale,
          isExpanded: true,
          items: locales.entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              ref.read(appSettingsProvider.notifier).updateAccessibility(uiLocale: value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildResetButton(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.refresh),
      title: const Text('重置设置'),
      subtitle: const Text('恢复所有设置到默认值'),
      onTap: () {
        _showResetDialog(context, ref);
      },
    );
  }

  Widget _buildClearProgressButton(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.clear_all, color: AppTheme.wrongColor),
      title: const Text('清除学习进度'),
      subtitle: const Text('删除所有学习记录和卡片状态'),
      onTap: () {
        _showClearProgressDialog(context, ref);
      },
    );
  }

  /// 构建重新加载词库按钮
  Widget _buildReloadWordsButton(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.sync, color: AppTheme.primaryColor),
      title: const Text('重新加载词库'),
      subtitle: const Text('从 assets/words.json 强制重新加载词汇数据'),
      onTap: () {
        _showReloadWordsDialog(context, ref);
      },
    );
  }

  Widget _buildExportProgressButton(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.file_download, color: AppTheme.correctColor),
      title: const Text('导出进度'),
      subtitle: const Text('保存学习进度为 JSON 文件'),
      onTap: () async {
        await _exportProgress(context, ref);
      },
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置设置'),
        content: const Text('确定要将所有设置重置为默认值吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(appSettingsProvider.notifier).resetToDefaults();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('设置已重置')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showClearProgressDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除学习进度'),
        content: const Text('确定要删除所有学习记录吗？这将清除您的学习进度、SRS状态和测试历史。此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final progressRepo = ref.read(progressRepositoryProvider);
                await progressRepo.clearAllProgress();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('学习进度已清除')),
                );
                // 刷新相关数据
                ref.invalidate(learningStatsProvider);
                ref.invalidate(todayDeckProvider);
              } catch (e) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('清除失败: $e')),
                );
              }
            },
            child: const Text('确定', style: TextStyle(color: AppTheme.wrongColor)),
          ),
        ],
      ),
    );
  }

  void _showReloadWordsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新加载词库'),
        content: const Text('确定要从 assets/words.json 重新加载词汇数据吗？这将清除现有的词库缓存并重新加载。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              // 显示加载指示器
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const AlertDialog(
                  content: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 20),
                      Text('正在重新加载词库...'),
                    ],
                  ),
                ),
              );
              
              try {
                final wordRepo = ref.read(wordRepositoryProvider) as HiveWordRepository;
                await wordRepo.forceReload();
                
                // 关闭加载指示器
                Navigator.of(context).pop();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('词库重新加载成功！')),
                );
                
                // 刷新相关数据
                ref.invalidate(wordsProvider);
                ref.invalidate(todayDeckProvider);
                ref.invalidate(learningStatsProvider);
                ref.invalidate(wordStatsProvider);
              } catch (e) {
                // 关闭加载指示器
                Navigator.of(context).pop();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('重新加载失败: $e')),
                );
              }
            },
            child: const Text('重新加载'),
          ),
        ],
      ),
    );
  }

  /// 词库统计卡片
  Widget _buildWordStatsSection(BuildContext context, ThemeData theme, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: ref.watch(wordStatsProvider).when(
          data: (stats) {
            final total = stats['total'] ?? 0;
            final a1 = stats['level_A1'] ?? 0;
            final a2 = stats['level_A2'] ?? 0;
            final b1 = stats['level_B1'] ?? 0;
            final b2 = stats['level_B2'] ?? 0;
            final c1 = stats['level_C1'] ?? 0;
            final c2 = stats['level_C2'] ?? 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '词库统计',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppTheme.paddingMedium),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('总词数'),
                    Text('$total'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('A1'),
                    Text('$a1'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('A2'),
                    Text('$a2'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('B1'),
                    Text('$b1'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('B2'),
                    Text('$b2'),
                  ],
                ),
                if (c1 > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('C1'),
                      Text('$c1'),
                    ],
                  ),
                ],
                if (c2 > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('C2'),
                      Text('$c2'),
                    ],
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppTheme.paddingSmall),
            child: CircularProgressIndicator(),
          )),
          error: (_, __) => const Text('统计信息加载失败'),
        ),
      ),
    );
  }

  /// 移动端布局
  Widget _buildMobileLayout(BuildContext context, ThemeData theme, WidgetRef ref, AppSettings settings) {
    return ListView(
      padding: ResponsiveLayout.getPagePadding(context),
      children: [
        // 词库统计
        _buildWordStatsSection(context, theme, ref),
        SizedBox(height: AppTheme.getResponsivePadding(context, AppTheme.paddingLarge)),

        // 测试配置
        _buildSection(
          context,
          '测试配置',
          [
            _buildLevelSelector(context, ref, settings),
            _buildWordsPerSessionSlider(context, ref, settings),
            _buildTimeLimitSlider(context, ref, settings),
            _buildOrderPolicySelector(context, ref, settings),
            _buildDelayProfileSelector(context, ref, settings),
          ],
        ),
        
        SizedBox(height: AppTheme.getResponsivePadding(context, AppTheme.paddingLarge)),
        
        // TTS配置
        _buildSection(
          context,
          'TTS 语音',
          [
            _buildTtsLocaleSelector(context, ref, settings),
            _buildTtsRateSlider(context, ref, settings),
            _buildTtsPitchSlider(context, ref, settings),
          ],
        ),
        
        SizedBox(height: AppTheme.getResponsivePadding(context, AppTheme.paddingLarge)),
        
        // 可访问性
        _buildSection(
          context,
          '可访问性',
          [
            _buildHighContrastSwitch(context, ref, settings),
            _buildUiLocaleSelector(context, ref, settings),
          ],
        ),
        
        SizedBox(height: AppTheme.getResponsivePadding(context, AppTheme.paddingLarge)),
        
        // 数据管理
        _buildSection(
          context,
          '数据管理',
          [
            _buildLeechWordsButton(context, ref),
            _buildReloadWordsButton(context, ref),
            _buildResetButton(context, ref),
            _buildClearProgressButton(context, ref),
            _buildExportProgressButton(context, ref),
          ],
        ),

        SizedBox(height: AppTheme.getResponsivePadding(context, AppTheme.paddingLarge)),

        _buildWordStatusSection(context, theme, ref, settings),
      ],
    );
  }

  /// 平板布局（双栏分组）
  Widget _buildTabletLayout(BuildContext context, ThemeData theme, WidgetRef ref, AppSettings settings) {
    return SingleChildScrollView(
      padding: ResponsiveLayout.getPagePadding(context),
      child: ResponsiveLayout.buildTwoColumnLayout(
        context: context,
        leftFlex: 1,
        rightFlex: 1,
        spacing: AppTheme.getResponsivePadding(context, AppTheme.paddingXLarge),
        left: Column(
          children: [
            // 词库统计
            _buildWordStatsSection(context, theme, ref),

            // 第一列：测试配置和TTS配置
            _buildSection(
              context,
              '测试配置',
              [
                _buildLevelSelector(context, ref, settings),
                _buildWordsPerSessionSlider(context, ref, settings),
                _buildTimeLimitSlider(context, ref, settings),
                _buildOrderPolicySelector(context, ref, settings),
                _buildDelayProfileSelector(context, ref, settings),
              ],
            ),
            
            SizedBox(height: AppTheme.getResponsivePadding(context, AppTheme.paddingLarge)),
            
            _buildSection(
              context,
              'TTS 语音',
              [
                _buildTtsLocaleSelector(context, ref, settings),
                _buildTtsRateSlider(context, ref, settings),
                _buildTtsPitchSlider(context, ref, settings),
              ],
            ),
          ],
        ),
        right: Column(
          children: [
            // 第二列：可访问性和数据管理
            _buildSection(
              context,
              '可访问性',
              [
                _buildHighContrastSwitch(context, ref, settings),
                _buildUiLocaleSelector(context, ref, settings),
              ],
            ),
            
            SizedBox(height: AppTheme.getResponsivePadding(context, AppTheme.paddingLarge)),
            
            _buildSection(
              context,
              '数据管理',
              [
                _buildLeechWordsButton(context, ref),
                _buildReloadWordsButton(context, ref),
                _buildResetButton(context, ref),
                _buildClearProgressButton(context, ref),
              ],
            ),
            
            SizedBox(height: AppTheme.getResponsivePadding(context, AppTheme.paddingLarge)),
            
            // 平板独有：详细信息卡片
            _buildInfoCard(context, theme),

            SizedBox(height: AppTheme.getResponsivePadding(context, AppTheme.paddingLarge)),

            _buildWordStatusSection(context, theme, ref, settings),
          ],
        ),
      ),
    );
  }

  /// 构建信息卡片（平板专用）
  Widget _buildInfoCard(BuildContext context, ThemeData theme) {
    return Card(
      margin: ResponsiveLayout.getCardMargin(context),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.getResponsivePadding(context, AppTheme.paddingMedium)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                SizedBox(width: AppTheme.getResponsivePadding(context, AppTheme.paddingSmall)),
                Text(
                  '应用信息',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppTheme.getResponsivePadding(context, AppTheme.paddingMedium)),
            
            // 功能介绍
            _buildInfoItem(
              context,
              theme,
              '闪测功能',
              '2秒精准计时，快速测试单词熟练度',
              Icons.timer,
            ),
            
            SizedBox(height: AppTheme.getResponsivePadding(context, AppTheme.paddingSmall)),
            
            _buildInfoItem(
              context,
              theme,
              '智能复习',
              '基于SRS算法，优化记忆效果',
              Icons.psychology,
            ),
            
            SizedBox(height: AppTheme.getResponsivePadding(context, AppTheme.paddingSmall)),
            
            _buildInfoItem(
              context,
              theme,
              '不熟回放',
              '错误单词自动加入延迟队列',
              Icons.replay,
            ),
            
            SizedBox(height: AppTheme.getResponsivePadding(context, AppTheme.paddingMedium)),
            
            Divider(color: theme.colorScheme.outline.withOpacity(0.3)),
            
            SizedBox(height: AppTheme.getResponsivePadding(context, AppTheme.paddingMedium)),
            
            // 版本信息
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '版本',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '1.0.0',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: AppTheme.getResponsivePadding(context, AppTheme.paddingSmall)),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '词库',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Oxford 3000',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建信息项
  Widget _buildInfoItem(
    BuildContext context,
    ThemeData theme,
    String title,
    String description,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: ResponsiveLayout.isTablet(context) ? 20 : 16,
          color: theme.colorScheme.primary.withOpacity(0.7),
        ),
        SizedBox(width: AppTheme.getResponsivePadding(context, AppTheme.paddingSmall)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeechWordsButton(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, child) {
        final leechWordsAsync = ref.watch(leechWordsProvider);
        return leechWordsAsync.when(
          data: (words) {
            return ListTile(
              leading: Icon(
                Icons.priority_high,
                color: words.isNotEmpty ? Colors.orange : Colors.grey,
              ),
              title: const Text('不熟悉单词'),
              subtitle: Text('管理和测试不熟悉的单词 (${words.length} 个)'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.of(context).pushNamed('/leech_words');
              },
            );
          },
          loading: () => const ListTile(
            leading: Icon(Icons.priority_high, color: Colors.grey),
            title: Text('不熟悉单词'),
            subtitle: Text('加载中...'),
            trailing: Icon(Icons.arrow_forward_ios),
          ),
          error: (_, __) => ListTile(
            leading: const Icon(Icons.priority_high, color: Colors.grey),
            title: const Text('不熟悉单词'),
            subtitle: const Text('加载失败'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).pushNamed('/leech_words');
            },
          ),
        );
      },
    );
  }

  Future<void> _exportProgress(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(progressRepositoryProvider);
      final data = await repo.exportProgress();

      // 优先使用公共 Download 目录
      Directory dir;
      try {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        }
      } catch (_) {
        dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      }

      final path = '${dir.path}/progress_export.json';
      final file = File(path);
      await file.writeAsString(jsonEncode(data));

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出成功: $path')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }

  void _showChangelog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('版本日志'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('v0.1.0'),
              SizedBox(height: 8),
              Text('· 新增选词策略：到期>难词>新词>填充，按最近复习排序，减少重复、强化错题。'),
              Text('· 支持跨轮保留错/慢词，并冷却上一轮的已掌握词。'),
              Text('· SRS 调整：稳定度增长系数提升，掌握阈值放宽到 16 天。'),
              Text('· 设置页新增“单词学习状态”视图，按级别查看学习/掌握情况。'),
              Text('· 新增进度导出按钮，保存到下载目录。'),
              SizedBox(height: 12),
              Text('后续可根据学习数据继续微调复习算法。'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
