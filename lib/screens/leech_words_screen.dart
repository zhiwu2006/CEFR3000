import 'package:flutter/material.dart';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../session/base_providers.dart';
import '../session/session_models.dart';
import '../models/word.dart';
import '../models/word_status.dart';
import '../features/memory/domain/leech_intervention.dart';
import '../data/word_preference_repository.dart';

import '../theme/theme_manager.dart';
import '../theme/theme_style.dart';

class LeechWordsScreen extends ConsumerStatefulWidget {
  const LeechWordsScreen({super.key});

  @override
  ConsumerState<LeechWordsScreen> createState() => _LeechWordsScreenState();
}

class _LeechWordsScreenState extends ConsumerState<LeechWordsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String _sortOption = 'recent_review';

  final Set<int> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(int wordId) {
    setState(() {
      if (_selectedIds.contains(wordId)) {
        _selectedIds.remove(wordId);
      } else {
        _selectedIds.add(wordId);
      }
    });
  }

  void _selectAll(List<WordStudyStatus> words) {
    setState(() {
      _selectedIds.clear();
      _selectedIds.addAll(words.map((w) => w.word.id));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  Future<void> _suspendSelected() async {
    if (_selectedIds.isEmpty) return;
    final repository = ref.read(progressRepositoryProvider);
    if (repository is! WordPreferenceRepository) return;
    final preferenceRepository = repository as WordPreferenceRepository;
    final now = DateTime.now();
    for (final wordId in _selectedIds) {
      await preferenceRepository.saveWordPreference(
        UserWordPreference(
          lexemeId: 'legacy:$wordId',
          suspended: true,
          updatedAt: now,
        ),
      );
    }
    if (!mounted) return;
    setState(() => _selectedIds.clear());
    ref.invalidate(todayStudyPlanProvider);
    ref.invalidate(todayRecognitionPlanProvider);
    ref.invalidate(todayProductionPlanProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已暂不学习，之后可在词库中恢复')));
  }

  Future<void> _restoreSelected() async {
    if (_selectedIds.isEmpty) return;
    final repository = ref.read(progressRepositoryProvider);
    if (repository is! WordPreferenceRepository) return;
    final preferenceRepository = repository as WordPreferenceRepository;
    for (final wordId in _selectedIds) {
      await preferenceRepository.clearWordPreference('legacy:$wordId');
    }
    if (!mounted) return;
    setState(() => _selectedIds.clear());
    ref.invalidate(todayStudyPlanProvider);
    ref.invalidate(todayRecognitionPlanProvider);
    ref.invalidate(todayProductionPlanProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已恢复到学习计划')));
  }

  String _formatDate(DateTime date, {bool includeTime = false}) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    if (!includeTime) {
      return '$m-$d';
    }
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final currentThemeStyle = ThemeStyle.values.firstWhere(
      (e) => e.name == settings.themeStyle,
      orElse: () => ThemeStyle.standard,
    );

    final leechStatusesAsync = ref.watch(leechWordStatusesProvider);

    return Scaffold(
      appBar: _buildAppBar(theme, leechStatusesAsync.valueOrNull ?? []),
      body: Column(
        children: [
          _buildHeader(theme),
          _buildControls(theme),
          Expanded(
            child: leechStatusesAsync.when(
              data: (statuses) =>
                  _buildWordsList(statuses, theme, currentThemeStyle),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text('加载失败', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(leechWordStatusesProvider);
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? FloatingActionButton.extended(
              onPressed: _practiceSelected,
              icon: const Icon(Icons.play_arrow),
              label: const Text('仅练选中'),
              backgroundColor: theme.colorScheme.tertiary,
              foregroundColor: theme.colorScheme.onTertiary,
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(
    ThemeData theme,
    List<WordStudyStatus> allWords,
  ) {
    if (_isSelectionMode) {
      return AppBar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _clearSelection,
        ),
        title: Text('${_selectedIds.length} 已选择'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: '全选',
            onPressed: () {
              final filtered = _getFilteredAndSortedWords(allWords);
              _selectAll(filtered);
            },
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: '清除选择',
            onPressed: _clearSelection,
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: '标记已掌握',
            onPressed: _markSelectedKnown,
          ),
          IconButton(
            icon: const Icon(Icons.pause_circle_outline),
            tooltip: '暂不学习',
            onPressed: _suspendSelected,
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: '恢复学习',
            onPressed: _restoreSelected,
          ),
        ],
      );
    }

    return AppBar(
      title: const Text('不熟悉单词'),
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.invalidate(leechWordStatusesProvider);
            _clearSelection();
          },
          tooltip: '刷新',
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final leechStatusesAsync = ref.watch(leechWordStatusesProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          leechStatusesAsync.when(
            data: (statuses) {
              final filteredWords = _getFilteredAndSortedWords(statuses);
              return Column(
                children: [
                  Text(
                    '${filteredWords.length}',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '个不熟悉单词',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  if (statuses.isNotEmpty && !_isSelectionMode) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _startLeechTest(filteredWords),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('开始测试 (全部)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
            loading: () => Column(
              children: [
                Text(
                  '加载中...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            error: (_, __) => Text(
              '加载失败',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索单词...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.sort, size: 20),
              const SizedBox(width: 8),
              Text('排序:', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _sortOption,
                  isExpanded: true,
                  underline: Container(
                    height: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _sortOption = newValue;
                      });
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 'recent_review',
                      child: Text('最近复习 (最久优先)'),
                    ),
                    DropdownMenuItem(
                      value: 'lapses_desc',
                      child: Text('错误次数 (从高到低)'),
                    ),
                    DropdownMenuItem(
                      value: 'stability_asc',
                      child: Text('稳定度 (从低到高)'),
                    ),
                    DropdownMenuItem(
                      value: 'attempts_desc',
                      child: Text('练习次数 (从高到低)'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWordsList(
    List<WordStudyStatus> statuses,
    ThemeData theme,
    ThemeStyle themeStyle,
  ) {
    final filteredStatuses = _getFilteredAndSortedWords(statuses);

    if (filteredStatuses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.celebration,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? '没有找到匹配的单词' : '太棒了！没有不熟悉的单词',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filteredStatuses.length,
      itemBuilder: (context, index) {
        final status = filteredStatuses[index];
        return _buildWordCard(status, theme, themeStyle);
      },
    );
  }

  Widget _buildWordCard(
    WordStudyStatus status,
    ThemeData theme,
    ThemeStyle themeStyle,
  ) {
    final word = status.word;
    final isSelected = _selectedIds.contains(word.id);
    final isMarkedDifficult = status.state?.isMarkedDifficult ?? false;
    final warningColor = ThemeManager.getWarningColor(themeStyle);
    final wrongColor = ThemeManager.getWrongColor(themeStyle);
    final intervention = status.state == null
        ? null
        : const LeechInterventionPolicy().plan(status.state!);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      elevation: isSelected ? 4 : 1,
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(word.id);
          } else {
            _showWordDetails(status);
          }
        },
        onLongPress: () => _toggleSelection(word.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              word.headword,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (word.pos.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  word.pos,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          word.primaryDefinition,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isMarkedDifficult
                          ? warningColor.withValues(alpha: 0.1)
                          : wrongColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isMarkedDifficult
                            ? warningColor.withValues(alpha: 0.5)
                            : wrongColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      isMarkedDifficult ? '标记疑难' : '多次失忆',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isMarkedDifficult ? warningColor : wrongColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem(
                    theme,
                    '复习',
                    status.lastReview != null
                        ? _formatDate(status.lastReview!)
                        : '从未',
                  ),
                  _buildStatItem(theme, '错误', '${status.state?.lapses ?? 0}次'),
                  _buildStatItem(
                    theme,
                    '稳定度',
                    (status.state?.stability ?? 0).toStringAsFixed(1),
                  ),
                  _buildStatItem(theme, '练习', '${status.attemptCount}次'),
                ],
              ),
              if (intervention != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.route_outlined, size: 18, color: warningColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '建议：${intervention.reason}（本轮最多 ${intervention.suggestedAttempts} 次）',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (!_isSelectionMode) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _showDetailedExplanation(context, word),
                    icon: const Icon(Icons.auto_stories, size: 18),
                    label: const Text('详细释义'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(ThemeData theme, String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  List<WordStudyStatus> _getFilteredAndSortedWords(
    List<WordStudyStatus> statuses,
  ) {
    List<WordStudyStatus> filtered = statuses;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = statuses.where((status) {
        final word = status.word;
        return word.headword.toLowerCase().contains(query) ||
            word.primaryDefinition.toLowerCase().contains(query) ||
            word.pos.toLowerCase().contains(query);
      }).toList();
    }

    filtered.sort((a, b) {
      switch (_sortOption) {
        case 'lapses_desc':
          return (b.state?.lapses ?? 0).compareTo(a.state?.lapses ?? 0);
        case 'stability_asc':
          return (a.state?.stability ?? 0).compareTo(b.state?.stability ?? 0);
        case 'attempts_desc':
          return b.attemptCount.compareTo(a.attemptCount);
        case 'recent_review':
        default:
          final dateA = a.lastReview;
          final dateB = b.lastReview;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateA.compareTo(dateB);
      }
    });

    return filtered;
  }

  void _startLeechTest(List<WordStudyStatus> statuses) {
    if (statuses.isEmpty) {
      final settings = ref.read(appSettingsProvider);
      final themeStyle = ThemeStyle.values.firstWhere(
        (e) => e.name == settings.themeStyle,
        orElse: () => ThemeStyle.standard,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('没有可测试的单词'),
          backgroundColor: ThemeManager.getWarningColor(themeStyle),
        ),
      );
      return;
    }

    final words = statuses.map((s) => s.word).toList();
    final settings = ref.read(appSettingsProvider);

    // 统一从 SessionConfig.fromAppSettings 派生，再覆盖 leech 专属字段。
    // 手工构造 SessionConfig 会漏掉 srsConfig / maxRetriesPerWord /
    // maxTotalAttempts / cooldownWindow / plannedWordIds，也绕过时间上限与
    // 灵敏度等钳制，导致 leech 会话与普通会话的调度参数静默不一致。
    final config = SessionConfig.fromAppSettings(settings).copyWith(
      wordsPerSession: min(
        words.length,
        settings.leechWordsPerSession.clamp(5, 100),
      ),
      orderPolicy: 'random',
      onlyLeeches: true,
    );

    Navigator.of(context).pushNamed('/test', arguments: config);
  }

  Future<void> _practiceSelected() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择单词')));
      return;
    }

    try {
      final sessionId = await ref
          .read(appSettingsProvider.notifier)
          .stageCustomSession(_selectedIds.toList());

      if (!mounted) return;

      if (sessionId.isNotEmpty) {
        final settings = ref.read(appSettingsProvider);

        final config = SessionConfig.fromAppSettings(settings).copyWith(
          wordsPerSession: _selectedIds.length,
          orderPolicy: 'random',
          onlyLeeches: true,
        );

        Navigator.of(context).pushNamed('/test', arguments: config);
        _clearSelection();
      }
    } catch (e) {
      if (mounted) {
        final settings = ref.read(appSettingsProvider);
        final themeStyle = ThemeStyle.values.firstWhere(
          (e) => e.name == settings.themeStyle,
          orElse: () => ThemeStyle.standard,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('启动失败: $e'),
            backgroundColor: ThemeManager.getWrongColor(themeStyle),
          ),
        );
      }
    }
  }

  Future<void> _markSelectedKnown() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('标记为已掌握'),
        content: Text(
          '确定要将选中的 ${_selectedIds.length} 个单词标记为已掌握吗？\n这将清除它们的"不熟悉"状态。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final repo = ref.read(progressRepositoryProvider);
        await Future.wait(_selectedIds.map((id) => repo.markWordKnown(id)));

        ref.invalidate(leechWordStatusesProvider);
        _clearSelection();

        if (mounted) {
          final settings = ref.read(appSettingsProvider);
          final themeStyle = ThemeStyle.values.firstWhere(
            (e) => e.name == settings.themeStyle,
            orElse: () => ThemeStyle.standard,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('已标记为已掌握'),
              backgroundColor: ThemeManager.getCorrectColor(themeStyle),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final settings = ref.read(appSettingsProvider);
          final themeStyle = ThemeStyle.values.firstWhere(
            (e) => e.name == settings.themeStyle,
            orElse: () => ThemeStyle.standard,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('操作失败: $e'),
              backgroundColor: ThemeManager.getWrongColor(themeStyle),
            ),
          );
        }
      }
    }
  }

  void _showWordDetails(WordStudyStatus status) {
    final word = status.word;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(word.headword)),
            IconButton(
              icon: const Icon(Icons.volume_up),
              onPressed: () {
                ref.read(ttsServiceProvider).speak(word.headword);
              },
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (word.pos.isNotEmpty) ...[
                Text(
                  '词性',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(word.pos),
                const SizedBox(height: 12),
              ],
              Text(
                '释义',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(word.primaryDefinition),
              const SizedBox(height: 12),
              Text(
                '数据统计',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '上次复习: ${status.lastReview != null ? _formatDate(status.lastReview!, includeTime: true) : '从未'}',
              ),
              Text('失忆次数: ${status.state?.lapses ?? 0}'),
              Text(
                '稳定度: ${status.state?.stability.toStringAsFixed(2) ?? '0.00'}',
              ),
              Text('练习次数: ${status.attemptCount}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _practiceSingle(word);
            },
            child: const Text('立即练习'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _markSingleKnown(word);
            },
            child: const Text('标记已掌握'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _practiceSingle(Word word) async {
    try {
      final sessionId = await ref
          .read(appSettingsProvider.notifier)
          .stageCustomSession([word.id]);

      if (!mounted) return;

      if (sessionId.isNotEmpty) {
        final settings = ref.read(appSettingsProvider);

        final config = SessionConfig.fromAppSettings(settings).copyWith(
          wordsPerSession: 1,
          orderPolicy: 'random',
          onlyLeeches: true,
        );

        Navigator.of(context).pushNamed('/test', arguments: config);
      }
    } catch (e) {
      if (mounted) {
        final settings = ref.read(appSettingsProvider);
        final themeStyle = ThemeStyle.values.firstWhere(
          (e) => e.name == settings.themeStyle,
          orElse: () => ThemeStyle.standard,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('启动失败: $e'),
            backgroundColor: ThemeManager.getWrongColor(themeStyle),
          ),
        );
      }
    }
  }

  Future<void> _markSingleKnown(Word word) async {
    try {
      final repo = ref.read(progressRepositoryProvider);
      await repo.markWordKnown(word.id);

      ref.invalidate(leechWordStatusesProvider);

      if (mounted) {
        final settings = ref.read(appSettingsProvider);
        final themeStyle = ThemeStyle.values.firstWhere(
          (e) => e.name == settings.themeStyle,
          orElse: () => ThemeStyle.standard,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已将 "${word.headword}" 标记为已掌握'),
            backgroundColor: ThemeManager.getCorrectColor(themeStyle),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final settings = ref.read(appSettingsProvider);
        final themeStyle = ThemeStyle.values.firstWhere(
          (e) => e.name == settings.themeStyle,
          orElse: () => ThemeStyle.standard,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: ThemeManager.getWrongColor(themeStyle),
          ),
        );
      }
    }
  }

  void _showDetailedExplanation(BuildContext context, Word word) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetailedExplanationSheet(word: word),
    );
  }
}

class _DetailedExplanationSheet extends ConsumerWidget {
  final Word word;

  const _DetailedExplanationSheet({required this.word});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final explanationAsync = ref.watch(wordDetailedExplanationProvider(word));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        word.headword,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: explanationAsync.when(
                  data: (data) {
                    if (data.error != null) {
                      return _buildErrorState(
                        theme,
                        data.error!,
                        ref,
                        scrollController,
                      );
                    }
                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      children: [
                        if (data.shortMeaning.isNotEmpty)
                          _buildSection(theme, '核心含义', data.shortMeaning),
                        if (data.ipa.isNotEmpty)
                          _buildSection(theme, '音标', data.ipa),
                        if (data.definitionEn.isNotEmpty)
                          _buildSection(theme, '英文释义', data.definitionEn),
                        if (data.exampleEn.isNotEmpty ||
                            data.exampleCn.isNotEmpty)
                          _buildExampleSection(
                            theme,
                            data.exampleEn,
                            data.exampleCn,
                          ),
                        if (data.morphologyRoot.isNotEmpty)
                          _buildSection(theme, '词根', data.morphologyRoot),
                        if (data.morphologyAffixes.isNotEmpty)
                          _buildSection(theme, '词缀分析', data.morphologyAffixes),
                        if (data.wordFamily.isNotEmpty)
                          _buildListSection(theme, '词族', data.wordFamily),
                        if (data.synonyms.isNotEmpty)
                          _buildListSection(theme, '同义词', data.synonyms),
                        if (data.antonyms.isNotEmpty)
                          _buildListSection(theme, '反义词', data.antonyms),
                        if (data.nuance.isNotEmpty)
                          _buildSection(theme, '细微差别', data.nuance),
                        if (data.collocations.isNotEmpty)
                          _buildListSection(theme, '常见搭配', data.collocations),
                        if (data.mnemonic.isNotEmpty)
                          _buildSection(theme, '记忆法', data.mnemonic),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => _buildErrorState(
                    theme,
                    error.toString(),
                    ref,
                    scrollController,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// AI 释义拿不到时仍展示词库自带的释义，只用一条提示说明原因。
  Widget _buildErrorState(
    ThemeData theme,
    String errorMsg,
    WidgetRef ref,
    ScrollController scrollController,
  ) {
    final missingKey = errorMsg.contains('missing_api_key');
    final String displayMsg;
    if (missingKey) {
      displayMsg = '在设置中填写 API Key 后，可查看例句、词根和记忆法';
    } else if (errorMsg.startsWith('http_')) {
      displayMsg = 'AI 释义请求失败，下面是词库自带的释义';
    } else if (errorMsg == 'request_failed') {
      displayMsg = '网络请求失败，下面是词库自带的释义';
    } else {
      displayMsg = 'AI 释义暂不可用：$errorMsg';
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      children: [
        _buildSection(theme, '中文释义', word.cnDefs.join('；')),
        _buildSection(
          theme,
          '词性 · 级别',
          [word.pos, word.level].where((v) => v.isNotEmpty).join(' · '),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                missingKey ? Icons.key_outlined : Icons.cloud_off_outlined,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayMsg,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (!missingKey)
                TextButton(
                  onPressed: () =>
                      ref.invalidate(wordDetailedExplanationProvider(word)),
                  child: const Text('重试'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(ThemeData theme, String title, String content) {
    if (content.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildListSection(ThemeData theme, String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(item, style: theme.textTheme.bodyMedium),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleSection(ThemeData theme, String en, String cn) {
    if (en.isEmpty && cn.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '例句',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (en.isNotEmpty)
            Text(en, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          if (cn.isNotEmpty)
            Text(
              cn,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: theme.colorScheme.outline,
              ),
            ),
        ],
      ),
    );
  }
}
