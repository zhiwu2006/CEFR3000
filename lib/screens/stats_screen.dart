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

                const SizedBox(height: 24),
                _buildSectionDivider(themeStyle),
                const SizedBox(height: 24),

                // 1.5 当前会话 (如果有)
                if (stats['hasActiveSession'] == true) ...[
                  _buildSectionHeader(context, '当前会话', textColor),
                  const SizedBox(height: 16),
                  _buildActiveSessionCard(context, themeStyle, stats),
                  const SizedBox(height: 24),
                  _buildSectionDivider(themeStyle),
                  const SizedBox(height: 24),
                ],

                // 1.6 词库状态
                _buildSectionHeader(context, '词库状态', textColor),
                const SizedBox(height: 16),
                _buildCardStatusSection(context, themeStyle, stats),

                const SizedBox(height: 24),
                _buildSectionDivider(themeStyle),
                const SizedBox(height: 24),

                // 1.7 准确率分析
                _buildSectionHeader(context, '准确率分析', textColor),
                const SizedBox(height: 16),
                _buildPerformanceSection(context, themeStyle, stats),

                const SizedBox(height: 24),
                _buildSectionDivider(themeStyle),
                const SizedBox(height: 24),

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

                const SizedBox(height: 24),
                _buildSectionDivider(themeStyle),
                const SizedBox(height: 24),

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

                // 4. Summary Footer
                _buildSummaryFooter(context, themeStyle, stats),
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

  Widget _buildSectionDivider(ThemeStyle style) {
    return Divider(
      height: 1,
      thickness: 1,
      color: ThemeManager.getBorderColor(style).withValues(alpha: 0.1),
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
              color: color.withValues(alpha: 0.1),
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

  /// 构建当前会话进度卡片
  Widget _buildActiveSessionCard(
    BuildContext context,
    ThemeStyle style,
    Map<String, dynamic> stats,
  ) {
    final current = stats['currentSessionProgress'] as int? ?? 0;
    final total = stats['currentSessionTotal'] as int? ?? 0;
    final progress = total > 0 ? current / total : 0.0;
    final primaryColor = ThemeManager.getPrimaryColor(style);
    final remaining = total - current;
    final percentInt = (progress * 100).toInt();

    return Container(
      decoration: ThemeManager.getCardDecoration(style, elevated: false),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '进行中',
                    style: TextStyle(
                      color: ThemeManager.getSecondaryTextColor(style),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '剩余 $remaining',
                        style: TextStyle(
                          color: ThemeManager.getTextColor(style),
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '题',
                        style: TextStyle(
                          color: ThemeManager.getSecondaryTextColor(style),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _buildPill(style, '已完成 $percentInt%', primaryColor),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: ThemeManager.getProgressBackgroundColor(style),
              color: primaryColor,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$current / $total',
                style: TextStyle(
                  color: ThemeManager.getSecondaryTextColor(style),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                remaining > 0 ? '加油！保持专注' : '即将完成！',
                style: TextStyle(
                  color: ThemeManager.getSecondaryTextColor(
                    style,
                  ).withValues(alpha: 0.7),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建词库状态部分 (Total, Due, Leech)
  Widget _buildCardStatusSection(
    BuildContext context,
    ThemeStyle style,
    Map<String, dynamic> stats,
  ) {
    final totalCards = stats['totalCards'] as int? ?? 0;
    final dueCards = stats['dueCards'] as int? ?? 0;
    final leechCards = stats['leechCards'] as int? ?? 0;
    final pending = dueCards + leechCards;

    final duePercent = totalCards > 0
        ? (dueCards / totalCards * 100).toStringAsFixed(0)
        : '0';
    final leechPercent = totalCards > 0
        ? (leechCards / totalCards * 100).toStringAsFixed(0)
        : '0';
    final completionRate = totalCards > 0
        ? ((totalCards - pending) / totalCards * 100).clamp(0.0, 100.0)
        : 100.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSingleStatCard(
                style,
                '总词汇',
                '$totalCards',
                Icons.style_outlined,
                ThemeManager.getPrimaryColor(style),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSingleStatCard(
                style,
                '待复习',
                '$dueCards',
                Icons.schedule_rounded,
                ThemeManager.getWarningColor(style),
                badge: '$duePercent%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSingleStatCard(
                style,
                '疑难词',
                '$leechCards',
                Icons.error_outline_rounded,
                ThemeManager.getWrongColor(style),
                badge: '$leechPercent%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Workload Indicator (Due + Leech vs Total)
        if (totalCards > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: ThemeManager.getCardDecoration(style, elevated: false),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '待处理任务',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ThemeManager.getSecondaryTextColor(style),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildPressureTag(style, pending, totalCards),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '达成度 ${completionRate.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 10,
                            color: ThemeManager.getSecondaryTextColor(style),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: ThemeManager.getWarningColor(style),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$pending / $totalCards',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: ThemeManager.getTextColor(style),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pending / totalCards,
                    backgroundColor: ThemeManager.getProgressBackgroundColor(
                      style,
                    ),
                    color: ThemeManager.getWarningColor(style),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '待复习/疑难占比',
                      style: TextStyle(
                        fontSize: 10,
                        color: ThemeManager.getSecondaryTextColor(style),
                      ),
                    ),
                    Text(
                      '$duePercent% / $leechPercent%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: ThemeManager.getTextColor(style),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        _buildStatusRatioBar(style, totalCards, dueCards, leechCards),
      ],
    );
  }

  /// 构建准确率与测试分析部分
  Widget _buildPerformanceSection(
    BuildContext context,
    ThemeStyle style,
    Map<String, dynamic> stats,
  ) {
    final avgAccuracy = (stats['averageAccuracy'] as double? ?? 0.0) * 100;
    final todayAccuracy = (stats['todayAccuracy'] as double? ?? 0.0) * 100;
    final totalTests = stats['totalTests'] as int? ?? 0;
    final retention = (stats['retentionRate'] as double? ?? 0.0) * 100;
    final accuracyDiff = todayAccuracy - avgAccuracy;

    // Sparkline data (last 7 days accuracy)
    final dailyStats =
        (stats['dailyStats'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];
    final recentAccuracy = dailyStats
        .map((e) => (e['accuracy'] as double? ?? 0.0))
        .toList();
    final sparklineData = recentAccuracy.length > 7
        ? recentAccuracy.sublist(recentAccuracy.length - 7)
        : recentAccuracy;

    double volatility = 0.0;
    if (sparklineData.isNotEmpty) {
      final minVal = sparklineData.reduce(
        (curr, next) => curr < next ? curr : next,
      );
      final maxVal = sparklineData.reduce(
        (curr, next) => curr > next ? curr : next,
      );
      volatility = (maxVal - minVal) * 100;
    }

    // Calculate 7-day median and mean
    double medianVal = 0.0;
    double meanVal = 0.0;
    if (sparklineData.isNotEmpty) {
      final sorted = List<double>.from(sparklineData)..sort();
      final mid = sorted.length ~/ 2;
      medianVal = (sorted.length % 2 == 1)
          ? sorted[mid]
          : (sorted[mid - 1] + sorted[mid]) / 2;

      meanVal = sparklineData.reduce((a, b) => a + b) / sparklineData.length;
    }

    // Calculate 7-day average practice count
    double avgPracticeCount = 0.0;
    double practiceMedian = 0.0;
    int maxPracticeCount = 0;
    int minPracticeCount = 0;
    int practiceVolatility = 0;
    final recentCounts = dailyStats
        .map((e) => (e['count'] as int? ?? 0))
        .toList();
    final last7Counts = recentCounts.length > 7
        ? recentCounts.sublist(recentCounts.length - 7)
        : recentCounts;

    if (last7Counts.isNotEmpty) {
      avgPracticeCount =
          last7Counts.reduce((a, b) => a + b) / last7Counts.length;

      final sortedCounts = List<int>.from(last7Counts)..sort();
      final mid = sortedCounts.length ~/ 2;
      practiceMedian = (sortedCounts.length % 2 == 1)
          ? sortedCounts[mid].toDouble()
          : (sortedCounts[mid - 1] + sortedCounts[mid]) / 2;

      maxPracticeCount = last7Counts.reduce(
        (curr, next) => curr > next ? curr : next,
      );
      minPracticeCount = last7Counts.reduce(
        (curr, next) => curr < next ? curr : next,
      );
      practiceVolatility = maxPracticeCount - minPracticeCount;
    }

    // Calculate trend (slope)
    String trendLabel = '持平';
    Color trendColor = ThemeManager.getSecondaryTextColor(style);
    IconData trendIcon = Icons.remove;

    if (sparklineData.length >= 2) {
      final first = sparklineData.first;
      final last = sparklineData.last;
      final slope = last - first;

      // 5% threshold
      if (slope > 0.05) {
        trendLabel = '上升';
        trendColor = ThemeManager.getCorrectColor(style);
        trendIcon = Icons.trending_up;
      } else if (slope < -0.05) {
        trendLabel = '下降';
        trendColor = ThemeManager.getWrongColor(style);
        trendIcon = Icons.trending_down;
      }
    }

    // Calculate practice trend (count)
    String practiceTrendLabel = '持平';
    Color practiceTrendColor = ThemeManager.getSecondaryTextColor(style);
    IconData practiceTrendIcon = Icons.remove;

    if (last7Counts.length >= 2) {
      final pFirst = last7Counts.first;
      final pLast = last7Counts.last;

      if (pLast > pFirst) {
        practiceTrendLabel = '上升';
        practiceTrendColor = ThemeManager.getCorrectColor(style);
        practiceTrendIcon = Icons.trending_up;
      } else if (pLast < pFirst) {
        practiceTrendLabel = '下降';
        practiceTrendColor = ThemeManager.getWrongColor(style);
        practiceTrendIcon = Icons.trending_down;
      }
    }

    return Container(
      decoration: ThemeManager.getCardDecoration(style, elevated: false),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              // 总测试数
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '总测试数',
                      style: TextStyle(
                        color: ThemeManager.getSecondaryTextColor(style),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalTests',
                      style: TextStyle(
                        color: ThemeManager.getTextColor(style),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (sparklineData.isNotEmpty)
                      SizedBox(
                        height: 24,
                        width: 80,
                        child: CustomPaint(
                          painter: _SparklinePainter(
                            data: sparklineData,
                            color: ThemeManager.getCorrectColor(style),
                            themeStyle: style,
                          ),
                        ),
                      ),
                    if (sparklineData.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: trendColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(trendIcon, size: 10, color: trendColor),
                                const SizedBox(width: 4),
                                Text(
                                  '准确率 $trendLabel',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: trendColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: practiceTrendColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  practiceTrendIcon,
                                  size: 10,
                                  color: practiceTrendColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '练习 $practiceTrendLabel',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: practiceTrendColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '波动 ${volatility.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: ThemeManager.getSecondaryTextColor(style),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '均值 ${(meanVal * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: ThemeManager.getSecondaryTextColor(style),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '中位数 ${(medianVal * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: ThemeManager.getSecondaryTextColor(style),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '日均 ${avgPracticeCount.toStringAsFixed(1)}',
                            style: TextStyle(
                              color: ThemeManager.getSecondaryTextColor(style),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '中位数 ${practiceMedian.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}',
                            style: TextStyle(
                              color: ThemeManager.getSecondaryTextColor(style),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '峰值 $maxPracticeCount',
                            style: TextStyle(
                              color: ThemeManager.getSecondaryTextColor(style),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '低谷 $minPracticeCount',
                            style: TextStyle(
                              color: ThemeManager.getSecondaryTextColor(style),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '极差 $practiceVolatility',
                            style: TextStyle(
                              color: ThemeManager.getSecondaryTextColor(style),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // 分隔线
              Container(
                width: 1,
                height: 40,
                color: ThemeManager.getBorderColor(style),
              ),
              // 准确率展示
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildCompactAccuracy(
                          style,
                          '平均准确率',
                          avgAccuracy,
                          ThemeManager.getPrimaryColor(style),
                          tag: 'AVG',
                        ),
                        _buildCompactAccuracy(
                          style,
                          '今日准确率',
                          todayAccuracy,
                          ThemeManager.getCorrectColor(style),
                          tag: '24H',
                          diff: accuracyDiff,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 11,
                          color: ThemeManager.getSecondaryTextColor(style),
                          fontFamily: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.fontFamily,
                        ),
                        children: [
                          const TextSpan(text: '今日较平均 '),
                          TextSpan(
                            text:
                                '${accuracyDiff >= 0 ? '+' : ''}${accuracyDiff.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: accuracyDiff >= 0
                                  ? ThemeManager.getCorrectColor(style)
                                  : ThemeManager.getWrongColor(style),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(children: [_buildRetentionGauge(style, retention)]),
        ],
      ),
    );
  }

  Widget _buildSingleStatCard(
    ThemeStyle style,
    String label,
    String value,
    IconData icon,
    Color color, {
    String? badge,
  }) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: ThemeManager.getCardDecoration(style, elevated: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: color),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: ThemeManager.getTextColor(style),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: ThemeManager.getSecondaryTextColor(style),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactAccuracy(
    ThemeStyle style,
    String label,
    double value,
    Color color, {
    String? tag,
    double? diff,
  }) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                value: value / 100,
                strokeWidth: 4,
                backgroundColor: ThemeManager.getProgressBackgroundColor(style),
                color: color,
              ),
            ),
            Text(
              '${value.toInt()}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: ThemeManager.getTextColor(style),
              ),
            ),
            if (diff != null)
              Positioned(
                right: -8,
                top: -8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: ThemeManager.getBackgroundColor(style),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    diff >= 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    size: 14,
                    color: diff >= 0
                        ? ThemeManager.getCorrectColor(style)
                        : ThemeManager.getWrongColor(style),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tag != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label.replaceAll(
                '准确率',
                '',
              ), // Simplify label if needed, or keep full
              style: TextStyle(
                color: ThemeManager.getSecondaryTextColor(style),
                fontSize: 10,
              ),
            ),
          ],
        ),
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
        final double itemHeight = 120; // Increased height to prevent overflow

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
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
          // SizedBox removed to prevent overflow with spaceBetween
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

  Widget _buildPill(ThemeStyle style, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusRatioBar(ThemeStyle style, int total, int due, int leech) {
    if (total == 0) return const SizedBox.shrink();

    final dueRatio = (due / total).clamp(0.0, 1.0);
    final leechRatio = (leech / total).clamp(0.0, 1.0);
    final healthyRatio = (1.0 - dueRatio - leechRatio).clamp(0.0, 1.0);

    return Column(
      children: [
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Row(
              children: [
                if (healthyRatio > 0)
                  Expanded(
                    flex: (healthyRatio * 100).toInt(),
                    child: Container(
                      color: ThemeManager.getPrimaryColor(
                        style,
                      ).withValues(alpha: 0.2),
                    ),
                  ),
                if (dueRatio > 0)
                  Expanded(
                    flex: (dueRatio * 100).toInt(),
                    child: Container(
                      color: ThemeManager.getWarningColor(style),
                    ),
                  ),
                if (leechRatio > 0)
                  Expanded(
                    flex: (leechRatio * 100).toInt(),
                    child: Container(color: ThemeManager.getWrongColor(style)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (dueRatio > 0) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: ThemeManager.getWarningColor(style),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${(dueRatio * 100).toStringAsFixed(1)}% 待复习',
                style: TextStyle(
                  fontSize: 10,
                  color: ThemeManager.getSecondaryTextColor(style),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (leechRatio > 0) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: ThemeManager.getWrongColor(style),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${(leechRatio * 100).toStringAsFixed(1)}% 疑难',
                style: TextStyle(
                  fontSize: 10,
                  color: ThemeManager.getSecondaryTextColor(style),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildRetentionGauge(ThemeStyle style, double retention) {
    final primary = ThemeManager.getPrimaryColor(style);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '记忆保留',
                style: TextStyle(
                  fontSize: 11,
                  color: ThemeManager.getSecondaryTextColor(style),
                ),
              ),
              Text(
                '${retention.toInt()}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: retention / 100,
              backgroundColor: ThemeManager.getProgressBackgroundColor(style),
              color: primary,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSummaryFooter(
    BuildContext context,
    ThemeStyle style,
    Map<String, dynamic> stats,
  ) {
    final todayTests = stats['todayTests'] as int? ?? 0;
    final avgAccuracy = ((stats['averageAccuracy'] as double? ?? 0.0) * 100)
        .toInt();

    // Attempt to calculate weekly tests if dailyStats available
    int weeklyTests = 0;
    final dailyStats = stats['dailyStats'] as List<dynamic>?;
    if (dailyStats != null) {
      // Sum up last 7 days (or whatever is available)
      for (var day in dailyStats.take(7)) {
        weeklyTests += (day['count'] as int? ?? 0);
      }
    }

    final displayCount = weeklyTests > 0 ? weeklyTests : todayTests;
    final displayLabel = weeklyTests > 0 ? '本周练习' : '今日练习';

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: ThemeManager.getBackgroundColor(style),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ThemeManager.getBorderColor(style).withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          '$displayLabel $displayCount 次 · 平均准确率 $avgAccuracy%',
          style: TextStyle(
            color: ThemeManager.getSecondaryTextColor(style),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPressureTag(ThemeStyle style, int pending, int total) {
    if (total == 0) return const SizedBox.shrink();
    final ratio = pending / total;

    String label;
    Color color;

    if (ratio <= 0.1) {
      label = '状态良好';
      color = ThemeManager.getCorrectColor(style);
    } else if (ratio <= 0.3) {
      label = '任务适中';
      color = ThemeManager.getWarningColor(style);
    } else {
      label = '压力较大';
      color = ThemeManager.getWrongColor(style);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final ThemeStyle themeStyle;

  _SparklinePainter({
    required this.data,
    required this.color,
    required this.themeStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final stepX = size.width / (data.length > 1 ? data.length - 1 : 1);

    // Normalize data or use 0-1 if already normalized.
    // Data passed is raw accuracy (0.0 to 1.0).
    // Invert Y so 1.0 is at top (0), 0.0 is at bottom (height)

    for (int i = 0; i < data.length; i++) {
      final value = data[i].clamp(0.0, 1.0);
      final x = i * stepX;
      final y = size.height * (1 - value);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Curve fitting
        final prevX = (i - 1) * stepX;
        final prevValue = data[i - 1].clamp(0.0, 1.0);
        final prevY = size.height * (1 - prevValue);

        final controlX1 = prevX + stepX / 2;
        final controlY1 = prevY;
        final controlX2 = prevX + stepX / 2;
        final controlY2 = y;

        path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw a small dot at the end
    if (data.isNotEmpty) {
      final lastValue = data.last.clamp(0.0, 1.0);
      final lastX = size.width;
      final lastY = size.height * (1 - lastValue);

      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      // White border for dot to separate from line
      final bgDotPaint = Paint()
        ..color = ThemeManager.getBackgroundColor(themeStyle)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(lastX, lastY), 4, bgDotPaint);
      canvas.drawCircle(Offset(lastX, lastY), 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
