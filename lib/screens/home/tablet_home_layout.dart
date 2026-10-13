import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/progress/domain/daily_records.dart';
import '../../session/base_providers.dart';
import '../../session/session_models.dart';
import '../../theme/theme_manager.dart';
import '../../theme/theme_style.dart';
import 'learning_record_widgets.dart';

/// 平板首页：左侧导航栏 + 学习记录主区域 + 今日行动栏。
///
/// 横屏（宽度 ≥ [wideMinWidth]）三栏；竖屏把行动栏移到主区域顶部。
/// 启动学习的逻辑仍由 HomeScreen 提供，这里只负责布局。
class TabletHomeLayout extends ConsumerWidget {
  static const double wideMinWidth = 1000;
  static const double actionPanelWidth = 300;

  final ThemeStyle themeStyle;
  final int wordCount;
  final VoidCallback onStartTest;
  final VoidCallback onStartProduction;
  final void Function(List<int> wordIds) onStartPlan;

  const TabletHomeLayout({
    super.key,
    required this.themeStyle,
    required this.wordCount,
    required this.onStartTest,
    required this.onStartProduction,
    required this.onStartPlan,
  });

  static const _destinations = [
    (icon: Icons.home_outlined, selected: Icons.home, label: '首页', route: ''),
    (
      icon: Icons.bookmark_outline,
      selected: Icons.bookmark,
      label: '疑难词',
      route: '/leech_words',
    ),
    (
      icon: Icons.analytics_outlined,
      selected: Icons.analytics,
      label: '统计',
      route: '/stats',
    ),
    (
      icon: Icons.calendar_month_outlined,
      selected: Icons.calendar_month,
      label: '每日记录',
      route: '/daily_history',
    ),
    (
      icon: Icons.settings_outlined,
      selected: Icons.settings,
      label: '设置',
      route: '/settings',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textColor = ThemeManager.getTextColor(themeStyle);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideMinWidth;
        final main = _RecordArea(themeStyle: themeStyle);
        final actions = _ActionPanel(
          themeStyle: themeStyle,
          wordCount: wordCount,
          horizontal: !wide,
          onStartTest: onStartTest,
          onStartProduction: onStartProduction,
          onStartPlan: onStartPlan,
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NavigationRail(
              backgroundColor: Colors.transparent,
              selectedIndex: 0,
              labelType: NavigationRailLabelType.all,
              selectedLabelTextStyle: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: ThemeManager.getSecondaryTextColor(themeStyle),
              ),
              unselectedIconTheme: IconThemeData(
                color: ThemeManager.getSecondaryTextColor(themeStyle),
              ),
              selectedIconTheme: IconThemeData(color: textColor),
              // 其它页面仍是独立路由，保持手机端已有的页面与返回行为。
              onDestinationSelected: (index) {
                final route = _destinations[index].route;
                if (route.isNotEmpty) Navigator.of(context).pushNamed(route);
              },
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: Text(d.label),
                  ),
              ],
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                decoration: ThemeManager.getContentAreaDecoration(themeStyle),
                clipBehavior: Clip.antiAlias,
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: main),
                          VerticalDivider(
                            width: 1,
                            color: ThemeManager.getBorderColor(
                              themeStyle,
                            ).withValues(alpha: 0.2),
                          ),
                          SizedBox(width: actionPanelWidth, child: actions),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          actions,
                          Expanded(child: main),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 学习记录主区域：打卡指标、打卡日历、每日趋势、作答构成与每日明细。
class _RecordArea extends ConsumerWidget {
  final ThemeStyle themeStyle;

  const _RecordArea({required this.themeStyle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textColor = ThemeManager.getTextColor(themeStyle);
    final stats = ref.watch(learningStatsProvider).asData?.value ?? const {};
    int value(String key) => (stats[key] as num?)?.toInt() ?? 0;
    final checkedIn = stats['checkedInToday'] == true;
    final records = ref.watch(dailyRecordsProvider);

    final metrics = [
      (
        label: '连续打卡',
        value: '${value('streakDays')}',
        unit: '天',
        hint: checkedIn ? '今日已打卡' : '今天还没完成一轮',
        icon: Icons.local_fire_department,
        color: ThemeManager.getWarningColor(themeStyle),
      ),
      (
        label: '最长连续',
        value: '${value('longestStreakDays')}',
        unit: '天',
        hint: '历史最佳',
        icon: Icons.emoji_events_outlined,
        color: ThemeManager.getPrimaryColor(themeStyle),
      ),
      (
        label: '累计打卡',
        value: '${value('totalStudyDays')}',
        unit: '天',
        hint: '完成至少一轮的天数',
        icon: Icons.event_available,
        color: ThemeManager.getCorrectColor(themeStyle),
      ),
      (
        label: '已学单词',
        value: '${value('levelCards')}',
        unit: '个',
        hint: '当前级别待复习 ${value('levelDueCards')}',
        icon: Icons.menu_book_outlined,
        color: ThemeManager.getProductionColor(themeStyle),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          '学习记录',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final columns = constraints.maxWidth >= 640 ? 4 : 2;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final m in metrics)
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      themeStyle: themeStyle,
                      label: m.label,
                      value: m.value,
                      unit: m.unit,
                      hint: m.hint,
                      icon: m.icon,
                      color: m.color,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        ...switch (records) {
          AsyncData(:final value) => _recordSections(context, value),
          AsyncError(:final error) => [
            Text(
              '学习记录加载失败：$error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: ThemeManager.getWrongColor(themeStyle),
              ),
            ),
          ],
          _ => [
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        },
      ],
    );
  }

  List<Widget> _recordSections(BuildContext context, List<DailyRecord> list) {
    const gap = SizedBox(height: 16);
    // 异常天只保留在打卡日历里，不参与趋势、构成和明细。
    final normal = list.where((r) => !r.anomalous).toList();
    final excluded = list.where((r) => r.anomalous).toList();
    final secondary = ThemeManager.getSecondaryTextColor(themeStyle);
    return [
      RecordSection(
        themeStyle: themeStyle,
        title: '打卡日历',
        child: StudyHeatmap(themeStyle: themeStyle, records: list),
      ),
      gap,
      LayoutBuilder(
        builder: (context, constraints) {
          final trend = DailyTrendChart(
            themeStyle: themeStyle,
            records: normal,
          );
          final mix = AnswerCompositionCard(
            themeStyle: themeStyle,
            records: normal,
          );
          if (constraints.maxWidth < 720) {
            return Column(children: [trend, gap, mix]);
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: trend),
                const SizedBox(width: 16),
                SizedBox(width: 260, child: mix),
              ],
            ),
          );
        },
      ),
      if (excluded.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          '已排除 ${excluded.length} 个异常天：'
          '${excluded.map((r) => '${r.day.month}/${r.day.day}').join('、')}'
          '（题量或准确率明显偏离日常，仍计入打卡）',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: secondary),
        ),
      ],
      gap,
      DailyRecordTable(
        themeStyle: themeStyle,
        records: normal,
        onOpenDetail: () => Navigator.of(context).pushNamed('/daily_history'),
      ),
    ];
  }
}

class _MetricCard extends StatelessWidget {
  final ThemeStyle themeStyle;
  final String label;
  final String value;
  final String unit;
  final String hint;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.themeStyle,
    required this.label,
    required this.value,
    required this.unit,
    required this.hint,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = ThemeManager.getTextColor(themeStyle);
    final secondary = ThemeManager.getSecondaryTextColor(themeStyle);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ThemeManager.getCardDecoration(themeStyle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(color: secondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}

/// 今日行动栏：横屏时为右侧竖栏，竖屏时为顶部横排卡片。
class _ActionPanel extends ConsumerWidget {
  final ThemeStyle themeStyle;
  final int wordCount;
  final bool horizontal;
  final VoidCallback onStartTest;
  final VoidCallback onStartProduction;
  final void Function(List<int> wordIds) onStartPlan;

  const _ActionPanel({
    required this.themeStyle,
    required this.wordCount,
    required this.horizontal,
    required this.onStartTest,
    required this.onStartProduction,
    required this.onStartPlan,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textColor = ThemeManager.getTextColor(themeStyle);
    final secondary = ThemeManager.getSecondaryTextColor(themeStyle);
    final session = ref.watch(sessionControllerProvider);
    final hasPausedTest =
        session.sessionId.isNotEmpty &&
        (session.state == SessionState.waiting ||
            session.state == SessionState.resolved ||
            session.state == SessionState.saveFailed);
    final plan = ref.watch(todayStudyPlanProvider).asData?.value;
    final stats = ref.watch(learningStatsProvider).asData?.value ?? const {};
    final leech = (stats['levelLeechCards'] as num?)?.toInt() ?? 0;

    final planCard = _PanelCard(
      themeStyle: themeStyle,
      title: '今日计划',
      subtitle: plan == null
          ? '计算中…'
          : plan.items.isEmpty
          ? '今天没有到期任务'
          : '${plan.items.length} 项 · 新词 ${plan.newItemCount} · '
                '约 ${(plan.estimatedSeconds / 60).ceil()} 分钟',
      buttonLabel: '主动回忆',
      icon: Icons.today_outlined,
      onPressed: plan == null ? null : () => onStartPlan(plan.wordIds.toList()),
    );
    final testCard = _PanelCard(
      themeStyle: themeStyle,
      title: hasPausedTest ? '未完成的测试' : '闪测',
      subtitle: hasPausedTest
          ? '已测 ${session.testedWordCount} / ${session.totalWords}'
          : '$wordCount 个单词可练习',
      buttonLabel: hasPausedTest ? '继续测试' : '开始学习',
      icon: Icons.play_circle_fill,
      primary: true,
      onPressed: onStartTest,
    );
    final productionCard = _PanelCard(
      themeStyle: themeStyle,
      title: '看义拼词',
      subtitle: '疑难词 $leech 个',
      buttonLabel: '开始拼写',
      icon: Icons.spellcheck_rounded,
      onPressed: onStartProduction,
    );
    final cards = [testCard, planCard, productionCard];

    if (horizontal) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '今日',
          style: theme.textTheme.titleLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          _today(),
          style: theme.textTheme.bodySmall?.copyWith(color: secondary),
        ),
        const SizedBox(height: 16),
        for (final card in cards) ...[card, const SizedBox(height: 12)],
      ],
    );
  }

  static String _today() {
    final now = DateTime.now();
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return '${now.month}月${now.day}日 星期${weekdays[now.weekday - 1]}';
  }
}

class _PanelCard extends StatelessWidget {
  final ThemeStyle themeStyle;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final IconData icon;
  final bool primary;
  final VoidCallback? onPressed;

  const _PanelCard({
    required this.themeStyle,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = ThemeManager.getTextColor(themeStyle);
    final secondary = ThemeManager.getSecondaryTextColor(themeStyle);
    final accent = ThemeManager.getPrimaryColor(themeStyle);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ThemeManager.getCardDecoration(themeStyle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: secondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: primary
                ? FilledButton(onPressed: onPressed, child: Text(buttonLabel))
                : OutlinedButton(
                    onPressed: onPressed,
                    child: Text(buttonLabel),
                  ),
          ),
        ],
      ),
    );
  }
}
