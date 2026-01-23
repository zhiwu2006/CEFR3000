// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../session/base_providers.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/theme_style.dart';
import '../utils/responsive_layout.dart';
import '../utils/openrouter_models.dart';
import '../utils/ai_studio_models.dart';
import '../data/hive_word_repository.dart';

/// 设置页面
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _wordStatusQuery = '';
  String _wordStatusSort = 'recent_review';
  final TextEditingController _wordStatusSearchController =
      TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _aiStudioApiKeyController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    // 初始化 API Key
    final settings = ref.read(appSettingsProvider);
    _apiKeyController.text = settings.openRouterApiKey;
    _aiStudioApiKeyController.text = settings.aiStudioApiKey;
  }

  @override
  void dispose() {
    _wordStatusSearchController.dispose();
    _apiKeyController.dispose();
    _aiStudioApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);

    // 监听设置变化同步 API Key (处理重置等外部变更)
    ref.listen(appSettingsProvider, (previous, next) {
      if (next.openRouterApiKey != _apiKeyController.text) {
        _apiKeyController.text = next.openRouterApiKey;
        // 保持光标在末尾，避免跳动
        _apiKeyController.selection = TextSelection.fromPosition(
          TextPosition(offset: _apiKeyController.text.length),
        );
      }
      if (next.aiStudioApiKey != _aiStudioApiKeyController.text) {
        _aiStudioApiKeyController.text = next.aiStudioApiKey;
        // 保持光标在末尾，避免跳动
        _aiStudioApiKeyController.selection = TextSelection.fromPosition(
          TextPosition(offset: _aiStudioApiKeyController.text.length),
        );
      }
    });

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

  Widget _buildWordStatusSection(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
    AppSettings settings,
  ) {
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
          final query = _wordStatusQuery.trim().toLowerCase();
          final filteredStatuses = query.isEmpty
              ? statuses
              : statuses
                    .where((s) => s.word.headword.toLowerCase().contains(query))
                    .toList();
          final byLevel = <String, List<WordStudyStatus>>{};
          for (final s in filteredStatuses) {
            byLevel.putIfAbsent(s.word.level, () => []).add(s);
          }

          final levels = byLevel.keys.toList()..sort();
          final tiles = <Widget>[];
          for (final level in levels) {
            final list = byLevel[level]!;
            list.sort((a, b) {
              switch (_wordStatusSort) {
                case 'stability_desc':
                  return (b.state?.stability ?? 0).compareTo(
                    a.state?.stability ?? 0,
                  );
                case 'attempts_desc':
                  return b.attemptCount.compareTo(a.attemptCount);
                case 'recent_review':
                default:
                  final da = a.lastReview;
                  final db = b.lastReview;
                  if (da == null && db == null) return 0;
                  if (da == null) return 1;
                  if (db == null) return -1;
                  return db.compareTo(da);
              }
            });
            final learned = list.where((s) => s.isLearned).length;
            final mastered = list.where((s) => s.isMastered).length;
            tiles.add(
              ExpansionTile(
                title: Text('等级 $level'),
                subtitle: Text(
                  '总数 ${list.length} · 已学习 $learned · 已掌握 $mastered',
                ),
                children: list
                    .take(100)
                    .map((s) => _buildWordStatusRow(context, ref, s))
                    .toList(),
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
                  Text(
                    '单词学习状态',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _wordStatusSearchController,
                    decoration: InputDecoration(
                      hintText: '搜索单词...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _wordStatusQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _wordStatusSearchController.clear();
                                setState(() {
                                  _wordStatusQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _wordStatusQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.sort, size: 18),
                      const SizedBox(width: 8),
                      Text('排序:', style: theme.textTheme.bodyMedium),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _wordStatusSort,
                          isExpanded: true,
                          underline: Container(
                            height: 1,
                            color: theme.colorScheme.outlineVariant,
                          ),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _wordStatusSort = value;
                            });
                          },
                          items: const [
                            DropdownMenuItem(
                              value: 'recent_review',
                              child: Text('最近复习'),
                            ),
                            DropdownMenuItem(
                              value: 'stability_desc',
                              child: Text('稳定度 (高到低)'),
                            ),
                            DropdownMenuItem(
                              value: 'attempts_desc',
                              child: Text('复习次数 (高到低)'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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

  Widget _buildWordStatusRow(
    BuildContext context,
    WidgetRef ref,
    WordStudyStatus status,
  ) {
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
      subtitle: Text(
        '${status.word.level} ${status.word.pos} · $label · 复习次数 ${status.attemptCount} · 上次 $lastReview',
      ),
      trailing: IconButton(
        icon: Icon(
          isMastered ? Icons.check_circle : Icons.check_circle_outline,
          color: isMastered ? Colors.green : theme.colorScheme.outline,
        ),
        onPressed: () async {
          try {
            final repo = ref.read(progressRepositoryProvider);
            await repo.markWordKnown(status.word.id);
            if (!context.mounted) return;
            setState(() {});
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
          }
        },
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
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

  Widget _buildLevelSelector(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
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
              selectedColor: AppTheme.getLevelBadgeColor(
                level,
              ).withValues(alpha: 0.2),
              onSelected: (selected) {
                final newLevels = Set<String>.from(settings.selectedLevelsSet);
                if (selected) {
                  newLevels.add(level);
                } else {
                  newLevels.remove(level);
                }
                if (newLevels.isNotEmpty) {
                  ref
                      .read(appSettingsProvider.notifier)
                      .updateSelectedLevels(newLevels);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWordsPerSessionSlider(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
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
            ref
                .read(appSettingsProvider.notifier)
                .updateWordsPerSession(value.round());
          },
        ),
      ],
    );
  }

  Widget _buildTimeLimitSlider(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
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
            ref
                .read(appSettingsProvider.notifier)
                .updateTimeLimitMs(value.round());
          },
        ),
      ],
    );
  }

  Widget _buildSlowThresholdSlider(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('勉强正确阈值: ${settings.slowThreshold.toStringAsFixed(1)}x'),
        Slider(
          value: settings.slowThreshold,
          min: 1.0,
          max: 2.5,
          divisions: 15,
          label: '${settings.slowThreshold.toStringAsFixed(1)}x',
          onChanged: (value) {
            ref.read(appSettingsProvider.notifier).updateSlowThreshold(value);
          },
        ),
      ],
    );
  }

  Widget _buildNewCardRatioSlider(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final percent = (settings.newCardRatio * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('新卡比例: $percent%'),
        Slider(
          value: settings.newCardRatio,
          min: 0.0,
          max: 0.6,
          divisions: 12,
          label: '$percent%',
          onChanged: (value) {
            ref.read(appSettingsProvider.notifier).updateNewCardRatio(value);
          },
        ),
      ],
    );
  }

  Widget _buildDailyNewLimitSlider(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('每日新卡上限: ${settings.dailyNewLimit}'),
        Slider(
          value: settings.dailyNewLimit.toDouble(),
          min: 0,
          max: 200,
          divisions: 20,
          label: '${settings.dailyNewLimit}',
          onChanged: (value) {
            ref
                .read(appSettingsProvider.notifier)
                .updateDailyNewLimit(value.round());
          },
        ),
      ],
    );
  }

  Widget _buildOrderPolicySelector(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
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

  Widget _buildDelayProfileSelector(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
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
                ref
                    .read(appSettingsProvider.notifier)
                    .updateDelayProfile(value);
              }
            },
          );
        }),
      ],
    );
  }

  Widget _buildLeechWordsPerSessionSlider(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('默认每轮词数: ${settings.leechWordsPerSession}'),
        Slider(
          value: settings.leechWordsPerSession.toDouble(),
          min: 5,
          max: 100,
          divisions: 19,
          label: '${settings.leechWordsPerSession}',
          onChanged: (value) {
            ref
                .read(appSettingsProvider.notifier)
                .updateLeechWordsPerSession(value.round());
          },
        ),
      ],
    );
  }

  Widget _buildLeechLapsesThresholdSlider(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('失忆阈值: ${settings.leechLapsesThreshold}次'),
        Slider(
          value: settings.leechLapsesThreshold.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: '${settings.leechLapsesThreshold}',
          onChanged: (value) {
            ref
                .read(appSettingsProvider.notifier)
                .updateLeechPolicy(lapsesThreshold: value.round());
          },
        ),
      ],
    );
  }

  Widget _buildLeechIncludeMarkedSwitch(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return SwitchListTile(
      title: const Text('包含手动标记疑难'),
      subtitle: const Text('将手动标记的疑难词纳入不熟悉列表'),
      value: settings.leechIncludeMarked,
      onChanged: (value) {
        ref
            .read(appSettingsProvider.notifier)
            .updateLeechPolicy(includeMarked: value);
      },
    );
  }

  Widget _buildTtsLocaleSelector(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    const locales = {'en-US': '美式英语', 'en-GB': '英式英语'};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('语音语言'),
        DropdownButton<String>(
          value: settings.ttsLocale,
          isExpanded: true,
          items: locales.entries.map((entry) {
            return DropdownMenuItem(value: entry.key, child: Text(entry.value));
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              ref
                  .read(appSettingsProvider.notifier)
                  .updateTtsSettings(locale: value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildTtsAutoPlaySwitch(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return SwitchListTile(
      title: const Text('自动发音'),
      subtitle: const Text('出题后自动朗读单词'),
      value: settings.ttsAutoPlay,
      onChanged: (value) {
        ref
            .read(appSettingsProvider.notifier)
            .updateTtsSettings(autoPlay: value);
      },
    );
  }

  Widget _buildTtsOnWrongSwitch(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return SwitchListTile(
      title: const Text('错题回放发音'),
      subtitle: const Text('答错或超时时自动朗读单词'),
      value: settings.ttsOnWrong,
      onChanged: (value) {
        ref
            .read(appSettingsProvider.notifier)
            .updateTtsSettings(onWrong: value);
      },
    );
  }

  Widget _buildTtsRateSlider(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
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
            ref
                .read(appSettingsProvider.notifier)
                .updateTtsSettings(rate: value);
          },
        ),
      ],
    );
  }

  Widget _buildTtsPitchSlider(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
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
            ref
                .read(appSettingsProvider.notifier)
                .updateTtsSettings(pitch: value);
          },
        ),
      ],
    );
  }

  Widget _buildOpenRouterApiKeyField(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('OpenRouter API Key'),
        const SizedBox(height: 8),
        TextField(
          controller: _apiKeyController,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'sk-or-v1-...',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.all(12),
          ),
          onChanged: (value) {
            ref
                .read(appSettingsProvider.notifier)
                .updateOpenRouterSettings(apiKey: value);
          },
        ),
      ],
    );
  }

  Widget _buildOpenRouterModelSelector(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final modelsAsync = ref.watch(openRouterFreeModelsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('默认模型'),
        const SizedBox(height: 8),
        modelsAsync.when(
          data: (models) {
            var validModels = models.toList();
            // 确保当前选中值在列表中
            if (settings.openRouterDefaultModel.isNotEmpty &&
                !validModels.any(
                  (m) => m.id == settings.openRouterDefaultModel,
                )) {
              // 如果当前值不在列表中，添加一个占位项
              validModels = [
                OpenRouterModel(
                  id: settings.openRouterDefaultModel,
                  name: settings.openRouterDefaultModel,
                  promptPrice: '?',
                  completionPrice: '?',
                ),
                ...validModels,
              ];
            }

            if (validModels.isEmpty) {
              return const Text('无可用模型');
            }

            return DropdownButtonFormField<String>(
              value: settings.openRouterDefaultModel,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: validModels.map((model) {
                return DropdownMenuItem(
                  value: model.id,
                  child: Text(model.id, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(appSettingsProvider.notifier)
                      .updateOpenRouterSettings(defaultModel: value);
                }
              },
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (err, stack) => Text(
            '加载失败',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }

  Widget _buildAiSettingsSection(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return _buildSection(context, 'OpenRouter 设置', [
      _buildOpenRouterApiKeyField(context, ref, settings),
      const SizedBox(height: 16),
      _buildOpenRouterModelSelector(context, ref, settings),
    ]);
  }

  Widget _buildAiStudioApiKeyField(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AI Studio API Key'),
        const SizedBox(height: 8),
        TextField(
          controller: _aiStudioApiKeyController,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'AI Studio API Key',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.all(12),
          ),
          onChanged: (value) {
            ref
                .read(appSettingsProvider.notifier)
                .updateAiStudioSettings(apiKey: value);
          },
        ),
      ],
    );
  }

  Widget _buildAiStudioModelSelector(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final modelsAsync = ref.watch(aiStudioModelsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('默认模型'),
        const SizedBox(height: 8),
        modelsAsync.when(
          data: (models) {
            var validModels = models.toList();
            // 确保当前选中值在列表中
            if (settings.aiStudioDefaultModel.isNotEmpty &&
                !validModels.any(
                  (m) => m.name == settings.aiStudioDefaultModel,
                )) {
              // 如果当前值不在列表中，添加一个占位项
              validModels = [
                AiStudioModel(
                  name: settings.aiStudioDefaultModel,
                  displayName: settings.aiStudioDefaultModel,
                  supportedGenerationMethods: ['generateContent'],
                ),
                ...validModels,
              ];
            }

            if (validModels.isEmpty) {
              return const Text('无可用模型');
            }

            return DropdownButtonFormField<String>(
              value: settings.aiStudioDefaultModel,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: validModels.map((model) {
                return DropdownMenuItem(
                  value: model.name,
                  child: Text(model.name, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(appSettingsProvider.notifier)
                      .updateAiStudioSettings(defaultModel: value);
                }
              },
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (err, stack) => Text(
            '加载失败',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }

  Widget _buildAiStudioSettingsSection(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return _buildSection(context, 'AI Studio 设置', [
      _buildAiStudioApiKeyField(context, ref, settings),
      const SizedBox(height: 16),
      _buildAiStudioModelSelector(context, ref, settings),
    ]);
  }

  Widget _buildSrsAlphaSlider(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('稳定度增长系数: ${settings.srsAlphaStability.toStringAsFixed(2)}'),
        Slider(
          value: settings.srsAlphaStability,
          min: 0.05,
          max: 0.4,
          divisions: 7,
          label: settings.srsAlphaStability.toStringAsFixed(2),
          onChanged: (value) {
            ref
                .read(appSettingsProvider.notifier)
                .updateSrsConfig(alphaStability: value);
          },
        ),
      ],
    );
  }

  Widget _buildSrsBetaSlider(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('失败稳定度下限: ${settings.srsBetaFailure.toStringAsFixed(2)}'),
        Slider(
          value: settings.srsBetaFailure,
          min: 0.8,
          max: 2.0,
          divisions: 12,
          label: settings.srsBetaFailure.toStringAsFixed(2),
          onChanged: (value) {
            ref
                .read(appSettingsProvider.notifier)
                .updateSrsConfig(betaFailure: value);
          },
        ),
      ],
    );
  }

  Widget _buildSrsGammaSlider(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('间隔系数: ${settings.srsGammaInterval.toStringAsFixed(2)}'),
        Slider(
          value: settings.srsGammaInterval,
          min: 0.6,
          max: 1.6,
          divisions: 10,
          label: settings.srsGammaInterval.toStringAsFixed(2),
          onChanged: (value) {
            ref
                .read(appSettingsProvider.notifier)
                .updateSrsConfig(gammaInterval: value);
          },
        ),
      ],
    );
  }

  Widget _buildSrsMaxIntervalSlider(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('最大间隔天数: ${settings.srsMaxIntervalDays}天'),
        Slider(
          value: settings.srsMaxIntervalDays.toDouble(),
          min: 30,
          max: 180,
          divisions: 15,
          label: '${settings.srsMaxIntervalDays}天',
          onChanged: (value) {
            ref
                .read(appSettingsProvider.notifier)
                .updateSrsConfig(maxIntervalDays: value.round());
          },
        ),
      ],
    );
  }

  Widget _buildHighContrastSwitch(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return _buildThemeSelector(context, ref, settings);
  }

  /// 主题风格选择器
  Widget _buildThemeSelector(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('主题风格', style: theme.textTheme.titleMedium),
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
        ref
            .read(appSettingsProvider.notifier)
            .updateThemeStyle(themeInfo.style.name);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
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
            Text(themeInfo.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            // 主题名称
            Text(
              themeInfo.name,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
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

  Widget _buildUiLocaleSelector(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    const locales = {'zh-CN': '简体中文', 'zh-TW': '繁体中文', 'en-US': 'English'};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('界面语言'),
        DropdownButton<String>(
          value: settings.uiLocale,
          isExpanded: true,
          items: locales.entries.map((entry) {
            return DropdownMenuItem(value: entry.key, child: Text(entry.value));
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              ref
                  .read(appSettingsProvider.notifier)
                  .updateAccessibility(uiLocale: value);
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

  Widget _buildImportProgressButton(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.file_upload, color: AppTheme.primaryColor),
      title: const Text('导入进度'),
      subtitle: const Text('从 progress_export.json 导入学习进度'),
      onTap: () async {
        await _importProgress(context, ref);
      },
    );
  }

  Widget _buildClearTestRunsButton(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.playlist_remove, color: AppTheme.wrongColor),
      title: const Text('清除测试记录'),
      subtitle: const Text('删除所有测试会话记录'),
      onTap: () {
        _showClearTestRunsDialog(context, ref);
      },
    );
  }

  Widget _buildClearAttemptsButton(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(
        Icons.remove_circle_outline,
        color: AppTheme.wrongColor,
      ),
      title: const Text('清除答题记录'),
      subtitle: const Text('删除所有答题明细记录'),
      onTap: () {
        _showClearAttemptsDialog(context, ref);
      },
    );
  }

  Widget _buildClearCardStatesButton(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.layers_clear, color: AppTheme.wrongColor),
      title: const Text('清除卡片状态'),
      subtitle: const Text('删除所有 SRS 卡片状态'),
      onTap: () {
        _showClearCardStatesDialog(context, ref);
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('设置已重置')));
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
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('学习进度已清除')));
                // 刷新相关数据
                ref.invalidate(learningStatsProvider);
                ref.invalidate(todayDeckProvider);
              } catch (e) {
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('清除失败: $e')));
              }
            },
            child: const Text(
              '确定',
              style: TextStyle(color: AppTheme.wrongColor),
            ),
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
        content: const Text(
          '确定要从 assets/words.json 重新加载词汇数据吗？这将清除现有的词库缓存并重新加载。',
        ),
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
                final wordRepo =
                    ref.read(wordRepositoryProvider) as HiveWordRepository;
                await wordRepo.forceReload();
                if (!context.mounted) return;

                // 关闭加载指示器
                Navigator.of(context).pop();

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('词库重新加载成功！')));

                // 刷新相关数据
                ref.invalidate(wordsProvider);
                ref.invalidate(todayDeckProvider);
                ref.invalidate(learningStatsProvider);
                ref.invalidate(wordStatsProvider);
              } catch (e) {
                if (!context.mounted) return;
                // 关闭加载指示器
                Navigator.of(context).pop();

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('重新加载失败: $e')));
              }
            },
            child: const Text('重新加载'),
          ),
        ],
      ),
    );
  }

  /// 词库统计卡片
  Widget _buildWordStatsSection(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: ref
            .watch(wordStatsProvider)
            .when(
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
                      children: [const Text('总词数'), Text('$total')],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [const Text('A1'), Text('$a1')],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [const Text('A2'), Text('$a2')],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [const Text('B1'), Text('$b1')],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [const Text('B2'), Text('$b2')],
                    ),
                    if (c1 > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [const Text('C1'), Text('$c1')],
                      ),
                    ],
                    if (c2 > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [const Text('C2'), Text('$c2')],
                      ),
                    ],
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: AppTheme.paddingSmall,
                  ),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, __) => const Text('统计信息加载失败'),
            ),
      ),
    );
  }

  /// 移动端布局
  Widget _buildMobileLayout(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return ListView(
      padding: ResponsiveLayout.getPagePadding(context),
      children: [
        // 词库统计
        _buildWordStatsSection(context, theme, ref),
        SizedBox(
          height: AppTheme.getResponsivePadding(context, AppTheme.paddingLarge),
        ),

        // 测试配置
        _buildSection(context, '测试配置', [
          _buildLevelSelector(context, ref, settings),
          _buildWordsPerSessionSlider(context, ref, settings),
          _buildTimeLimitSlider(context, ref, settings),
          _buildSlowThresholdSlider(context, ref, settings),
          _buildNewCardRatioSlider(context, ref, settings),
          _buildDailyNewLimitSlider(context, ref, settings),
          _buildOrderPolicySelector(context, ref, settings),
          _buildDelayProfileSelector(context, ref, settings),
        ]),

        SizedBox(
          height: AppTheme.getResponsivePadding(context, AppTheme.paddingLarge),
        ),

        _buildSection(context, '不熟悉单词', [
          _buildLeechWordsPerSessionSlider(context, ref, settings),
          _buildLeechLapsesThresholdSlider(context, ref, settings),
          _buildLeechIncludeMarkedSwitch(context, ref, settings),
        ]),

        SizedBox(
          height: AppTheme.getResponsivePadding(context, AppTheme.paddingLarge),
        ),

        _buildSection(context, 'SRS 参数', [
          _buildSrsAlphaSlider(context, ref, settings),
          _buildSrsBetaSlider(context, ref, settings),
          _buildSrsGammaSlider(context, ref, settings),
          _buildSrsMaxIntervalSlider(context, ref, settings),
        ]),

        SizedBox(
          height: AppTheme.getResponsivePadding(context, AppTheme.paddingLarge),
        ),

        // TTS配置
        _buildSection(context, 'TTS 语音', [
          _buildTtsAutoPlaySwitch(context, ref, settings),
          _buildTtsOnWrongSwitch(context, ref, settings),
          _buildTtsLocaleSelector(context, ref, settings),
          _buildTtsRateSlider(context, ref, settings),
          _buildTtsPitchSlider(context, ref, settings),
        ]),

        SizedBox(
          height: AppTheme.getResponsivePadding(context, AppTheme.paddingLarge),
        ),

        // AI 设置
        _buildAiSettingsSection(context, ref, settings),

        SizedBox(
          height: AppTheme.getResponsivePadding(context, AppTheme.paddingLarge),
        ),

        // AI Studio 设置
        _buildAiStudioSettingsSection(context, ref, settings),

        SizedBox(
          height: AppTheme.getResponsivePadding(context, AppTheme.paddingLarge),
        ),

        // 可访问性
        _buildSection(context, '可访问性', [
          _buildHighContrastSwitch(context, ref, settings),
          _buildUiLocaleSelector(context, ref, settings),
        ]),

        SizedBox(
          height: AppTheme.getResponsivePadding(context, AppTheme.paddingLarge),
        ),

        // 数据管理
        _buildSection(context, '数据管理', [
          _buildLeechWordsButton(context, ref),
          _buildReloadWordsButton(context, ref),
          _buildResetButton(context, ref),
          _buildClearProgressButton(context, ref),
          _buildClearTestRunsButton(context, ref),
          _buildClearAttemptsButton(context, ref),
          _buildClearCardStatesButton(context, ref),
          _buildExportProgressButton(context, ref),
          _buildImportProgressButton(context, ref),
        ]),

        SizedBox(
          height: AppTheme.getResponsivePadding(context, AppTheme.paddingLarge),
        ),

        _buildWordStatusSection(context, theme, ref, settings),
      ],
    );
  }

  /// 平板布局（双栏分组）
  Widget _buildTabletLayout(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
    AppSettings settings,
  ) {
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
            _buildSection(context, '测试配置', [
              _buildLevelSelector(context, ref, settings),
              _buildWordsPerSessionSlider(context, ref, settings),
              _buildTimeLimitSlider(context, ref, settings),
              _buildSlowThresholdSlider(context, ref, settings),
              _buildNewCardRatioSlider(context, ref, settings),
              _buildDailyNewLimitSlider(context, ref, settings),
              _buildOrderPolicySelector(context, ref, settings),
              _buildDelayProfileSelector(context, ref, settings),
            ]),

            SizedBox(
              height: AppTheme.getResponsivePadding(
                context,
                AppTheme.paddingLarge,
              ),
            ),

            _buildSection(context, 'TTS 语音', [
              _buildTtsAutoPlaySwitch(context, ref, settings),
              _buildTtsOnWrongSwitch(context, ref, settings),
              _buildTtsLocaleSelector(context, ref, settings),
              _buildTtsRateSlider(context, ref, settings),
              _buildTtsPitchSlider(context, ref, settings),
            ]),

            SizedBox(
              height: AppTheme.getResponsivePadding(
                context,
                AppTheme.paddingLarge,
              ),
            ),

            // AI 设置
            _buildAiSettingsSection(context, ref, settings),

            SizedBox(
              height: AppTheme.getResponsivePadding(
                context,
                AppTheme.paddingLarge,
              ),
            ),

            // AI Studio 设置
            _buildAiStudioSettingsSection(context, ref, settings),
          ],
        ),
        right: Column(
          children: [
            _buildSection(context, '不熟悉单词', [
              _buildLeechWordsPerSessionSlider(context, ref, settings),
              _buildLeechLapsesThresholdSlider(context, ref, settings),
              _buildLeechIncludeMarkedSwitch(context, ref, settings),
            ]),

            SizedBox(
              height: AppTheme.getResponsivePadding(
                context,
                AppTheme.paddingLarge,
              ),
            ),

            _buildSection(context, 'SRS 参数', [
              _buildSrsAlphaSlider(context, ref, settings),
              _buildSrsBetaSlider(context, ref, settings),
              _buildSrsGammaSlider(context, ref, settings),
              _buildSrsMaxIntervalSlider(context, ref, settings),
            ]),

            SizedBox(
              height: AppTheme.getResponsivePadding(
                context,
                AppTheme.paddingLarge,
              ),
            ),

            // 第二列：可访问性和数据管理
            _buildSection(context, '可访问性', [
              _buildHighContrastSwitch(context, ref, settings),
              _buildUiLocaleSelector(context, ref, settings),
            ]),

            SizedBox(
              height: AppTheme.getResponsivePadding(
                context,
                AppTheme.paddingLarge,
              ),
            ),

            _buildSection(context, '数据管理', [
              _buildLeechWordsButton(context, ref),
              _buildReloadWordsButton(context, ref),
              _buildResetButton(context, ref),
              _buildClearProgressButton(context, ref),
              _buildClearTestRunsButton(context, ref),
              _buildClearAttemptsButton(context, ref),
              _buildClearCardStatesButton(context, ref),
              _buildExportProgressButton(context, ref),
              _buildImportProgressButton(context, ref),
            ]),

            SizedBox(
              height: AppTheme.getResponsivePadding(
                context,
                AppTheme.paddingLarge,
              ),
            ),

            // 平板独有：详细信息卡片
            _buildInfoCard(context, theme),

            SizedBox(
              height: AppTheme.getResponsivePadding(
                context,
                AppTheme.paddingLarge,
              ),
            ),

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
        padding: EdgeInsets.all(
          AppTheme.getResponsivePadding(context, AppTheme.paddingMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                SizedBox(
                  width: AppTheme.getResponsivePadding(
                    context,
                    AppTheme.paddingSmall,
                  ),
                ),
                Text(
                  '应用信息',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            SizedBox(
              height: AppTheme.getResponsivePadding(
                context,
                AppTheme.paddingMedium,
              ),
            ),

            // 功能介绍
            _buildInfoItem(
              context,
              theme,
              '闪测功能',
              '2秒精准计时，快速测试单词熟练度',
              Icons.timer,
            ),

            SizedBox(
              height: AppTheme.getResponsivePadding(
                context,
                AppTheme.paddingSmall,
              ),
            ),

            _buildInfoItem(
              context,
              theme,
              '智能复习',
              '基于SRS算法，优化记忆效果',
              Icons.psychology,
            ),

            SizedBox(
              height: AppTheme.getResponsivePadding(
                context,
                AppTheme.paddingSmall,
              ),
            ),

            _buildInfoItem(
              context,
              theme,
              '不熟回放',
              '错误单词自动加入延迟队列',
              Icons.replay,
            ),

            SizedBox(
              height: AppTheme.getResponsivePadding(
                context,
                AppTheme.paddingMedium,
              ),
            ),

            Divider(color: theme.colorScheme.outline.withValues(alpha: 0.3)),

            SizedBox(
              height: AppTheme.getResponsivePadding(
                context,
                AppTheme.paddingMedium,
              ),
            ),

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
                  '0.3.2',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),

            SizedBox(
              height: AppTheme.getResponsivePadding(
                context,
                AppTheme.paddingSmall,
              ),
            ),

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
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
          color: theme.colorScheme.primary.withValues(alpha: 0.7),
        ),
        SizedBox(
          width: AppTheme.getResponsivePadding(context, AppTheme.paddingSmall),
        ),
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
          dir =
              await getDownloadsDirectory() ??
              await getApplicationDocumentsDirectory();
        }
      } catch (_) {
        dir =
            await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
      }

      final path = '${dir.path}/progress_export.json';
      final file = File(path);
      await file.writeAsString(jsonEncode(data));

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出成功: $path')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
  }

  Future<void> _importProgress(BuildContext context, WidgetRef ref) async {
    try {
      Directory dir;
      try {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir =
              await getDownloadsDirectory() ??
              await getApplicationDocumentsDirectory();
        }
      } catch (_) {
        dir =
            await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
      }

      final path = '${dir.path}/progress_export.json';
      final file = File(path);
      if (!await file.exists()) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('未找到文件: $path')));
        return;
      }

      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      final repo = ref.read(progressRepositoryProvider);
      await repo.importProgress(data);

      ref.invalidate(learningStatsProvider);
      ref.invalidate(todayDeckProvider);
      ref.invalidate(wordStatsProvider);
      ref.invalidate(leechWordStatusesProvider);

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入成功: $path')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入失败: $e')));
    }
  }

  void _showClearTestRunsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除测试记录'),
        content: const Text('确定要删除所有测试会话记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final repo = ref.read(progressRepositoryProvider);
                await repo.clearTestRuns();
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('测试记录已清除')));
                ref.invalidate(learningStatsProvider);
              } catch (e) {
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('清除失败: $e')));
              }
            },
            child: const Text(
              '确定',
              style: TextStyle(color: AppTheme.wrongColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearAttemptsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除答题记录'),
        content: const Text('确定要删除所有答题明细记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final repo = ref.read(progressRepositoryProvider);
                await repo.clearAttempts();
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('答题记录已清除')));
                ref.invalidate(learningStatsProvider);
              } catch (e) {
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('清除失败: $e')));
              }
            },
            child: const Text(
              '确定',
              style: TextStyle(color: AppTheme.wrongColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCardStatesDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除卡片状态'),
        content: const Text('确定要删除所有 SRS 卡片状态吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final repo = ref.read(progressRepositoryProvider);
                await repo.clearCardStates();
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('卡片状态已清除')));
                ref.invalidate(learningStatsProvider);
                ref.invalidate(todayDeckProvider);
                ref.invalidate(leechWordStatusesProvider);
              } catch (e) {
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('清除失败: $e')));
              }
            },
            child: const Text(
              '确定',
              style: TextStyle(color: AppTheme.wrongColor),
            ),
          ),
        ],
      ),
    );
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
              Text('v0.3.2'),
              SizedBox(height: 8),
              Text('· 响应式布局升级：移动/平板/桌面断点适配，设置页支持双栏分组布局。'),
              Text('· 主页与测试界面重构为大屏优化版式，信息密度更合理。'),
              Text('· 新增学习统计图表：活跃度柱状图+正确率折线、等级进度环形图。'),
              Text('· 选词策略优化：到期优先、难词补位、新词按日配额、填充词按最近复习排序。'),
              Text('· 错/慢词延迟回放机制，跨轮保留并动态调整回放间隔。'),
              Text('· 主题系统与可访问性细节优化，提升整体一致性。'),
              SizedBox(height: 12),
              Text('欢迎反馈使用体验，我们会持续优化学习流程。'),
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
