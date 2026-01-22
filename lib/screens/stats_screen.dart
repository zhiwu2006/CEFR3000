import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../session/base_providers.dart';
import '../theme/theme_manager.dart';
import '../theme/theme_style.dart';
import '../widgets/charts/activity_chart.dart';
import '../widgets/charts/level_progress_chart.dart';

/// 学习统计详情页
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final themeStyle = _parseThemeStyle(settings.themeStyle);
    final statsAsync = ref.watch(learningStatsProvider);

    final textColor = ThemeManager.getTextColor(themeStyle);
    final surfaceColor = ThemeManager.getSurfaceColor(themeStyle);
    final gradientColors = ThemeManager.getGradientColors(themeStyle);

    return Scaffold(
      backgroundColor: ThemeManager.getBackgroundColor(themeStyle),
      appBar: AppBar(
        title: Text(
          '学习数据分析',
          style: TextStyle(
            color: ThemeManager.getHeaderTextColor(themeStyle),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: ThemeManager.getHeaderTextColor(themeStyle),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            ),
          ),
        ),
      ),
      body: statsAsync.when(
        data: (stats) {
          final levelTotal = stats['levelTotal'] as int? ?? 1;
          final levelLearned = stats['levelLearned'] as int? ?? 0;
          final levelMastered = stats['levelMastered'] as int? ?? 0;
          final dailyStats =
              (stats['dailyStats'] as List<dynamic>?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [];

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 核心指标概览
                _buildSectionHeader(context, '核心指标', textColor),
                const SizedBox(height: 16),
                _buildDetailGrid(context, theme, themeStyle, stats),

                const SizedBox(height: 32),

                // 2. 词库进度概览
                _buildSectionHeader(
                  context,
                  '词库掌握进度',
                  textColor,
                  subtitle: settings.selectedLevelsSet.join(' + '),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: ThemeManager.getCardDecoration(
                    themeStyle,
                    elevated: true,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 20,
                  ),
                  child: LevelProgressChart(
                    total: levelTotal,
                    learned: levelLearned,
                    mastered: levelMastered,
                    themeStyle: themeStyle,
                  ),
                ),

                const SizedBox(height: 32),

                // 3. 30天学习趋势
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader(context, '近30天学习趋势', textColor),
                    // Legend for Activity Chart
                    Row(
                      children: [
                        _buildChartLegend(
                          color: ThemeManager.getCorrectColor(themeStyle),
                          label: '正确率',
                          textColor: ThemeManager.getSecondaryTextColor(
                            themeStyle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildChartLegend(
                          color: ThemeManager.getPrimaryColor(themeStyle),
                          label: '练习量',
                          textColor: ThemeManager.getSecondaryTextColor(
                            themeStyle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 260,
                  decoration: ThemeManager.getCardDecoration(
                    themeStyle,
                    elevated: true,
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: ActivityChart(
                    dailyStats: dailyStats,
                    themeStyle: themeStyle,
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(
            color: ThemeManager.getPrimaryColor(themeStyle),
          ),
        ),
        error: (err, stack) => Center(
          child: Text('加载失败', style: TextStyle(color: textColor)),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    Color color, {
    String? subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChartLegend({
    required Color color,
    required String label,
    required Color textColor,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: textColor, fontSize: 11)),
      ],
    );
  }

  /// 构建详细数据网格
  Widget _buildDetailGrid(
    BuildContext context,
    ThemeData theme,
    ThemeStyle style,
    Map<String, dynamic> stats,
  ) {
    // 累计时长显示优化
    final totalMinutes = stats['totalDurationMinutes'] as int? ?? 0;
    String timeDisplay;
    String timeUnit;

    if (totalMinutes < 60) {
      timeDisplay = '$totalMinutes';
      timeUnit = '分钟';
    } else {
      timeDisplay = (totalMinutes / 60).toStringAsFixed(1);
      timeUnit = '小时';
    }

    // 留存率
    final retention = ((stats['retentionRate'] ?? 0) * 100).toInt();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use 2 columns on mobile, maybe 4 on tablet?
        // Simple GridView is fine.
        final double itemWidth = (constraints.maxWidth - 16) / 2;
        final double itemHeight = 100; // Fixed height for cards

        // Calculate aspect ratio
        final double childAspectRatio = itemWidth / itemHeight;

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: childAspectRatio,
          children: [
            _buildStatItem(
              theme,
              style,
              '累计学习',
              timeDisplay,
              unit: timeUnit,
              icon: Icons.timer_outlined,
              color: ThemeManager.getPrimaryColor(style),
            ),
            _buildStatItem(
              theme,
              style,
              '连续打卡',
              '${stats['streakDays'] ?? 0}',
              unit: '天',
              icon: Icons.local_fire_department_rounded,
              color: ThemeManager.getWarningColor(style),
            ),
            _buildStatItem(
              theme,
              style,
              '今日复习',
              '${stats['todayTests'] ?? 0}',
              unit: '次',
              icon: Icons.refresh_rounded,
              color: ThemeManager.getCorrectColor(
                style,
              ), // Using correct color for "good" action
            ),
            _buildStatItem(
              theme,
              style,
              '记忆留存',
              '$retention',
              unit: '%',
              icon: Icons.psychology_outlined,
              color: ThemeManager.getPrimaryColor(style),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(
    ThemeData theme,
    ThemeStyle style,
    String label,
    String value, {
    String? unit,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: ThemeManager.getCardDecoration(style, elevated: false),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: ThemeManager.getSecondaryTextColor(style),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: ThemeManager.getTextColor(style),
                  fontSize: 28,
                  height: 1.0,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    color: ThemeManager.getSecondaryTextColor(style),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  ThemeStyle _parseThemeStyle(String value) {
    switch (value) {
      case 'highContrast':
        return ThemeStyle.highContrast;
      case 'bauhaus':
        return ThemeStyle.bauhaus;
      case 'minimal':
        return ThemeStyle.minimal;
      case 'nature':
        return ThemeStyle.nature;
      case 'cyberpunk':
        return ThemeStyle.cyberpunk;
      default:
        return ThemeStyle.standard;
    }
  }
}
