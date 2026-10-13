import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../session/session_models.dart';
import '../session/base_providers.dart';
import '../models/models.dart';
import '../theme/theme_style.dart';
import '../theme/theme_manager.dart';
import 'home_screen.dart';
import 'test_screen.dart';

/// 总结/复盘页面
class SummaryScreen extends ConsumerWidget {
  final SessionData sessionData;

  const SummaryScreen({super.key, required this.sessionData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final style = ThemeStyle.fromString(settings.themeStyle);
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final wrongAttempts = sessionData.firstWrongAttempts;

    final summary = [
      _Header(sessionData: sessionData, style: style),
      const SizedBox(height: 20),
      _HeroCard(sessionData: sessionData, style: style),
      const SizedBox(height: 16),
      _StatGrid(sessionData: sessionData, style: style),
      if (sessionData.unresolvedWordIds.isNotEmpty) ...[
        const SizedBox(height: 16),
        _ConsolidationNotice(
          count: sessionData.unresolvedWordIds.length,
          style: style,
        ),
      ],
    ];
    final actions = _Actions(
      wrongCount: sessionData.firstWrongWordIds.length,
      style: style,
      onPracticeWrong: () => _practiceWrongWords(context, ref, sessionData),
      onNext: () => _startNewTest(context, ref, sessionData),
      onHistory: () {
        ref.invalidate(dailyHistorySummariesProvider);
        Navigator.of(context).pushNamed('/daily_history');
      },
      onHome: () => _goHome(context, ref),
    );
    final review = wrongAttempts.isEmpty
        ? _AllCorrect(style: style)
        : _WrongList(attempts: wrongAttempts, style: style);

    final Widget body;
    if (isTablet && MediaQuery.sizeOf(context).width > 900) {
      // 平板：左侧成绩与操作固定，右侧错题单独滚动。
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 460,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(32, 24, 16, 32),
              children: [...summary, const SizedBox(height: 24), actions],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 32, 32),
              children: [review],
            ),
          ),
        ],
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          ...summary,
          const SizedBox(height: 20),
          review,
          const SizedBox(height: 24),
          actions,
        ],
      );
    }

    return Scaffold(
      backgroundColor: ThemeManager.getBackgroundColor(style),
      body: SafeArea(child: body),
    );
  }

  Future<void> _goHome(BuildContext context, WidgetRef ref) async {
    await ref.read(appSettingsProvider.notifier).clearTestProgress();
    ref.invalidate(learningStatsProvider);
    ref.invalidate(dailyHistorySummariesProvider);
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _practiceWrongWords(
    BuildContext context,
    WidgetRef ref,
    SessionData sessionData,
  ) async {
    final wrongWordIds = sessionData.firstWrongAttempts
        .map((a) => a.wordId)
        .toSet()
        .toList();
    if (wrongWordIds.isEmpty) return;

    final sessionId = await ref
        .read(appSettingsProvider.notifier)
        .stageCustomSession(wrongWordIds);
    if (!context.mounted) return;

    if (sessionId.isNotEmpty) {
      final config = sessionData.config.copyWith(
        onlyLeeches: true,
        wordsPerSession: wrongWordIds.length,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TestScreen(config: config)),
      );
    }
  }

  Future<void> _startNewTest(
    BuildContext context,
    WidgetRef ref,
    SessionData sessionData,
  ) async {
    // 清除之前的测试进度
    await ref.read(appSettingsProvider.notifier).clearTestProgress();
    if (!context.mounted) return;

    try {
      final plan = await ref.refresh(todayRecognitionPlanProvider.future);
      if (!context.mounted) return;
      if (plan.items.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前范围没有符合条件的复习任务')));
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TestScreen(
            config: SessionConfig.fromAppSettings(
              ref.read(appSettingsProvider),
            ).copyWith(plannedWordIds: plan.wordIds.toList()),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('生成下一组失败，请重试')));
    }
  }
}

class _WrongAttemptItem extends ConsumerStatefulWidget {
  final Attempt attempt;
  final Word word;
  final ThemeStyle style;

  const _WrongAttemptItem({
    required this.attempt,
    required this.word,
    required this.style,
  });

  @override
  ConsumerState<_WrongAttemptItem> createState() => _WrongAttemptItemState();
}

class _WrongAttemptItemState extends ConsumerState<_WrongAttemptItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attempt = widget.attempt;
    final word = widget.word;
    final style = widget.style;
    final wrongColor = ThemeManager.getWrongColor(style);
    final warningColor = ThemeManager.getWarningColor(style);
    final correctColor = ThemeManager.getCorrectColor(style);
    final secondary = ThemeManager.getSecondaryTextColor(style);
    final radius = ThemeManager.getBorderRadius(style);
    final accent = attempt.isTimeout ? warningColor : wrongColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ThemeManager.getSurfaceColor(style),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: ThemeManager.getBorderColor(style)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            word.headword,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _Chip(
                          label: word.level,
                          color: ThemeManager.getLevelBadgeColor(
                            style,
                            word.level,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _Chip(
                          label: attempt.isTimeout
                              ? '超时'
                              : '选错 · ${(attempt.rtMs / 1000).toStringAsFixed(1)}s',
                          color: accent,
                        ),
                      ],
                    ),
                    if (word.pos.isNotEmpty)
                      Text(
                        word.pos,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 18, color: correctColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            word.primaryDefinition,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: correctColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _isExpanded = !_isExpanded),
                          icon: Icon(
                            _isExpanded
                                ? Icons.expand_less
                                : Icons.auto_awesome_outlined,
                            size: 16,
                          ),
                          label: Text(_isExpanded ? '收起' : 'AI 助记'),
                        ),
                      ],
                    ),
                    if (_isExpanded) ...[
                      const SizedBox(height: 8),
                      _ExplanationContent(word: word),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

/// 顶部：标题与完成时间。
class _Header extends StatelessWidget {
  final SessionData sessionData;
  final ThemeStyle style;

  const _Header({required this.sessionData, required this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final time =
        '${now.month}月${now.day}日 ${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '本轮完成',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: ThemeManager.getTextColor(style),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$time · 限时 ${(sessionData.config.timeLimitMs / 1000).toStringAsFixed(1)} 秒',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: ThemeManager.getSecondaryTextColor(style),
          ),
        ),
      ],
    );
  }
}

/// 首答准确率：大圆环 + 一句评价。
class _HeroCard extends StatelessWidget {
  final SessionData sessionData;
  final ThemeStyle style;

  const _HeroCard({required this.sessionData, required this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accuracy = sessionData.firstAccuracy;
    final total = sessionData.firstAttempts.length;
    final correct = sessionData.firstAttempts.where((a) => a.isCorrect).length;
    final color = accuracy >= 0.8
        ? ThemeManager.getCorrectColor(style)
        : accuracy >= 0.6
        ? ThemeManager.getWarningColor(style)
        : ThemeManager.getWrongColor(style);
    final verdict = accuracy >= 0.9
        ? '很稳，继续保持'
        : accuracy >= 0.75
        ? '不错，错题再过一遍就更牢了'
        : accuracy >= 0.5
        ? '有一半以上记住了，错题值得马上再练'
        : '这组偏难，先把错题练熟再继续';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: ThemeManager.getCardDecoration(style),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 12,
                  color: ThemeManager.getProgressBackgroundColor(style),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: accuracy),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 12,
                    strokeCap: StrokeCap.round,
                    color: color,
                  ),
                ),
                Center(
                  child: Text(
                    '${(accuracy * 100).round()}%',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '首答正确率',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: ThemeManager.getSecondaryTextColor(style),
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$correct',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: ThemeManager.getTextColor(style),
                        ),
                      ),
                      TextSpan(
                        text: ' / $total 词',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: ThemeManager.getSecondaryTextColor(style),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  verdict,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ThemeManager.getTextColor(style),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 细分指标：等宽小卡片，两列或三列排布。
class _StatGrid extends StatelessWidget {
  final SessionData sessionData;
  final ThemeStyle style;

  const _StatGrid({required this.sessionData, required this.style});

  @override
  Widget build(BuildContext context) {
    final correct = ThemeManager.getCorrectColor(style);
    final wrong = ThemeManager.getWrongColor(style);
    final warning = ThemeManager.getWarningColor(style);
    final primary = ThemeManager.getPrimaryColor(style);
    final total = sessionData.firstAttempts.length;
    final attempts = sessionData.attempts.length;
    final tiles = [
      (
        '答错',
        '${sessionData.firstWrongWordIds.length}',
        Icons.close_rounded,
        wrong,
      ),
      (
        '勉强正确',
        '${sessionData.firstSlowCorrectAttempts.length}',
        Icons.hourglass_bottom_rounded,
        warning,
      ),
      (
        '纠错成功',
        '${sessionData.correctedWordIds.length}',
        Icons.auto_fix_high_rounded,
        correct,
      ),
      (
        '平均用时',
        '${(sessionData.avgReactionTime / 1000).toStringAsFixed(1)}s',
        Icons.timer_outlined,
        primary,
      ),
      if (attempts > total) ('总作答', '$attempts', Icons.repeat_rounded, primary),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth >= 520 ? 3 : 2;
        const gap = 12.0;
        final width = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (label, value, icon, color) in tiles)
              SizedBox(
                width: width,
                child: _StatTile(
                  label: label,
                  value: value,
                  icon: icon,
                  color: color,
                  style: style,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final ThemeStyle style;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ThemeManager.getSurfaceColor(style),
        borderRadius: BorderRadius.circular(
          ThemeManager.getBorderRadius(style),
        ),
        border: Border.all(color: ThemeManager.getBorderColor(style)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: ThemeManager.getTextColor(style),
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ThemeManager.getSecondaryTextColor(style),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 待巩固提示：一句话说明，详细规则点开再看。
class _ConsolidationNotice extends StatelessWidget {
  final int count;
  final ThemeStyle style;

  const _ConsolidationNotice({required this.count, required this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = ThemeManager.getWarningColor(style);
    // 用 Material 承载底色，展开时的水波纹才不会被遮住。
    return Material(
      color: color.withValues(alpha: 0.10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          ThemeManager.getBorderRadius(style),
        ),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.bookmark_added_outlined, color: color),
          title: Text(
            '$count 词待巩固，已排到下一组优先复习',
            style: theme.textTheme.titleSmall,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            Text(
              '巩固标准是隔几题后连续两次答对。本轮末尾间隔不够、或达到重测上限时，'
              '这些词会留到下一组继续，而不是在本轮无限重复。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: ThemeManager.getSecondaryTextColor(style),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 错题回顾列表。
class _WrongList extends ConsumerWidget {
  final List<Attempt> attempts;
  final ThemeStyle style;

  const _WrongList({required this.attempts, required this.style});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final wordRepo = ref.read(wordRepositoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 2),
          child: Text(
            '错题回顾 · ${attempts.length}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: ThemeManager.getTextColor(style),
            ),
          ),
        ),
        for (final attempt in attempts)
          FutureBuilder<Word?>(
            future: wordRepo.getById(attempt.wordId),
            builder: (context, snapshot) {
              final word = snapshot.data;
              if (word == null) return const SizedBox.shrink();
              return _WrongAttemptItem(
                attempt: attempt,
                word: word,
                style: style,
              );
            },
          ),
      ],
    );
  }
}

class _AllCorrect extends StatelessWidget {
  final ThemeStyle style;

  const _AllCorrect({required this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = ThemeManager.getCorrectColor(style);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: ThemeManager.getCardDecoration(style),
      child: Column(
        children: [
          Icon(Icons.emoji_events_outlined, size: 56, color: color),
          const SizedBox(height: 12),
          Text(
            '全部首答正确',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '没有需要回顾的错题',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: ThemeManager.getSecondaryTextColor(style),
            ),
          ),
        ],
      ),
    );
  }
}

/// 操作区：一个主按钮，其余为次要操作。
class _Actions extends StatelessWidget {
  final int wrongCount;
  final ThemeStyle style;
  final VoidCallback onPracticeWrong;
  final VoidCallback onNext;
  final VoidCallback onHistory;
  final VoidCallback onHome;

  const _Actions({
    required this.wrongCount,
    required this.style,
    required this.onPracticeWrong,
    required this.onNext,
    required this.onHistory,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    const height = 56.0;
    final wrong = ThemeManager.getWrongColor(style);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wrongCount > 0) ...[
          SizedBox(
            height: height,
            child: FilledButton.icon(
              onPressed: onPracticeWrong,
              style: FilledButton.styleFrom(
                backgroundColor: wrong,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.replay_rounded),
              label: Text('只练错题 · $wrongCount 词'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: height,
          child: wrongCount > 0
              ? OutlinedButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('继续下一组'),
                )
              : FilledButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('继续下一组'),
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: onHistory,
                icon: const Icon(Icons.insights_outlined),
                label: const Text('每日档案'),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: onHome,
                icon: const Icon(Icons.home_outlined),
                label: const Text('回到首页'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ExplanationContent extends ConsumerWidget {
  final Word word;

  const _ExplanationContent({required this.word});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final explanationAsync = ref.watch(wordExplanationProvider(word));

    return explanationAsync.when(
      data: (explanation) {
        if (explanation.error != null) {
          String msg = '加载失败';
          if (explanation.error == 'missing_api_key') {
            msg = '未设置 API Key';
          } else if (explanation.error!.startsWith('http_')) {
            msg = '请求失败 (${explanation.error})';
          } else if (explanation.error == 'empty_response') {
            msg = '无响应内容';
          } else if (explanation.error == 'request_failed') {
            msg = '网络请求失败';
          }
          return _buildError(context, msg);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (explanation.shortMeaning.isNotEmpty) ...[
              _buildSection(
                context,
                '核心含义',
                explanation.ipa.isNotEmpty
                    ? '[${explanation.ipa}] ${explanation.shortMeaning}'
                    : explanation.shortMeaning,
              ),
              const SizedBox(height: 8),
            ],
            if (explanation.definitionEn.isNotEmpty) ...[
              _buildSection(context, '英文释义', explanation.definitionEn),
              const SizedBox(height: 8),
            ],
            if (explanation.exampleEn.isNotEmpty ||
                explanation.exampleCn.isNotEmpty) ...[
              _buildExampleSection(
                context,
                explanation.exampleEn,
                explanation.exampleCn,
              ),
              const SizedBox(height: 8),
            ],
            if (explanation.nuance.isNotEmpty) ...[
              _buildSection(context, '细微差别', explanation.nuance),
              const SizedBox(height: 8),
            ],
            if (explanation.collocations.isNotEmpty)
              _buildSection(
                context,
                '常见搭配',
                explanation.collocations.join(', '),
              ),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (err, stack) => _buildError(context, '加载出错: $err'),
    );
  }

  Widget _buildError(BuildContext context, String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(content, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildExampleSection(BuildContext context, String en, String cn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '例句',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        if (en.isNotEmpty) Text(en, style: const TextStyle(fontSize: 13)),
        if (cn.isNotEmpty)
          Text(cn, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }
}
