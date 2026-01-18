import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../session/base_providers.dart';
import '../theme/theme_manager.dart';
import '../theme/theme_style.dart';

/// 统计图表工具类
class ChartUtils {
  /// 根据准确率获取颜色
  static Color getColorForAccuracy(double accuracy, ThemeStyle style) {
    if (accuracy >= 0.8) return ThemeManager.getCorrectColor(style); // >80% 优秀
    if (accuracy >= 0.6) return ThemeManager.getWarningColor(style); // 60-80% 良好
    return ThemeManager.getWrongColor(style); // <60% 需努力
  }
}

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
    final secondaryTextColor = ThemeManager.getSecondaryTextColor(themeStyle);
    final surfaceColor = ThemeManager.getSurfaceColor(themeStyle);
    final gradientColors = ThemeManager.getGradientColors(themeStyle);

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        title: Text(
          '学习数据分析',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                gradientColors[0].withOpacity(0.1),
                surfaceColor,
              ],
            ),
          ),
        ),
      ),
      body: statsAsync.when(
        data: (stats) {
          final levelTotal = stats['levelTotal'] as int? ?? 1; // 防止除0
          final levelLearned = stats['levelLearned'] as int? ?? 0;
          final levelMastered = stats['levelMastered'] as int? ?? 0;
          final notStarted = levelTotal - levelLearned;
          final dailyStats = (stats['dailyStats'] as List<Map<String, dynamic>>?) ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 词库进度概览
                Text(
                  '词库掌握进度 (${settings.selectedLevelsSet.join('+')})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, 
                    color: textColor
                  ),
                ),
                const SizedBox(height: 16),
                _buildProgressCard(
                  context, theme, themeStyle, 
                  levelTotal, levelLearned, levelMastered, notStarted
                ),

                const SizedBox(height: 32),

                // 2. 30天学习热力图 (柱状图)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '近30天学习情况',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold, 
                        color: textColor
                      ),
                    ),
                    Text(
                      '绿色高度代表正确率',
                      style: theme.textTheme.bodySmall?.copyWith(color: secondaryTextColor),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMonthlyChart(context, theme, themeStyle, dailyStats),
                
                const SizedBox(height: 32),
                
                // 3. 详细数据网格
                Text(
                  '核心指标',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, 
                    color: textColor
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailGrid(context, theme, themeStyle, stats),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败: $err')),
      ),
    );
  }

  /// 构建环形进度卡片
  Widget _buildProgressCard(
    BuildContext context, 
    ThemeData theme, 
    ThemeStyle style,
    int total, 
    int learned, 
    int mastered,
    int notStarted,
  ) {
    final cardDecoration = ThemeManager.getCardDecoration(style, elevated: true);
    final primaryColor = theme.colorScheme.primary;
    final successColor = ThemeManager.getCorrectColor(style);
    final secondaryTextColor = ThemeManager.getSecondaryTextColor(style);

    return Container(
      decoration: cardDecoration,
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // 左侧：环形进度条
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              children: [
                // 底层圆环 (未开始)
                Center(
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 10,
                      color: ThemeManager.getWrongColor(style).withOpacity(0.1),
                    ),
                  ),
                ),
                // 中层圆环 (已学习)
                Center(
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: total > 0 ? learned / total : 0,
                      strokeWidth: 10,
                      color: primaryColor.withOpacity(0.5),
                    ),
                  ),
                ),
                // 顶层圆环 (已掌握)
                Center(
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: total > 0 ? mastered / total : 0,
                      strokeWidth: 10,
                      color: successColor,
                    ),
                  ),
                ),
                // 中心文字
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(learned / total * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.bold,
                          color: ThemeManager.getTextColor(style),
                        ),
                      ),
                      Text(
                        '进度',
                        style: TextStyle(
                          fontSize: 10, 
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // 右侧：图例数据
          Expanded(
            child: Column(
              children: [
                _buildLegendItem(theme, style, '词库总量', '$total', Colors.grey),
                const SizedBox(height: 8),
                _buildLegendItem(theme, style, '已学习', '$learned', primaryColor.withOpacity(0.5)),
                const SizedBox(height: 8),
                _buildLegendItem(theme, style, '熟练掌握', '$mastered', successColor),
                const SizedBox(height: 8),
                _buildLegendItem(theme, style, '剩余未学', '$notStarted', ThemeManager.getWrongColor(style).withOpacity(0.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(ThemeData theme, ThemeStyle style, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: ThemeManager.getSecondaryTextColor(style), fontSize: 12),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: ThemeManager.getTextColor(style), 
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace'
          ),
        ),
      ],
    );
  }

  /// 构建月度柱状图 (可左右滑动)
  Widget _buildMonthlyChart(
    BuildContext context, 
    ThemeData theme, 
    ThemeStyle style,
    List<Map<String, dynamic>> dailyStats,
  ) {
    final cardDecoration = ThemeManager.getCardDecoration(style, elevated: true);
    final secondaryTextColor = ThemeManager.getSecondaryTextColor(style);
    
    // 找出最大时长，用于归一化高度 (至少10分钟)'
    // (已废弃逻辑：现在所有有数据的柱子都显示满高)
    
    // 创建 ScrollController 并利用 addPostFrameCallback 滚动到底部（今天）
    final ScrollController scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });

    return Container(
      height: 220,
      decoration: cardDecoration,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: dailyStats.length,
              separatorBuilder: (ctx, index) => const SizedBox(width: 12), // 增加间距
              itemBuilder: (context, index) {
                final stat = dailyStats[index];
                final durationMs = stat['durationMs'] as int;
                final count = stat['totalAttempts'] as int? ?? 0;
                final accuracy = stat['accuracy'] as double;
                final date = stat['date'] as DateTime;
                final isToday = index == dailyStats.length - 1;
                
                // 修改逻辑：柱子高度代表正确率
                final hasActivity = count > 0;
                // 高度直接等于准确率，最小给 5% 以免完全看不见
                final heightFactor = hasActivity ? max(0.05, accuracy) : 0.05; 
                
                // 颜色固定为绿色 (代表正确部分)
                final barColor = hasActivity 
                  ? ThemeManager.getCorrectColor(style)
                  : ThemeManager.getSurfaceColor(style).withOpacity(0.1); 

                // 背景色 (代表错误部分/总量)
                final bgColor = hasActivity
                  ? ThemeManager.getWrongColor(style).withOpacity(0.3)
                  : Colors.transparent;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 数值标签 (显示单词数)
                    if (hasActivity)
                      Text(
                        '$count词', 
                        style: TextStyle(
                          fontSize: 9, 
                          color: secondaryTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 4),
                    
                    // 柱子区域 (Stack叠加: 底部红色，上层绿色)
                    Flexible(
                      child: Container(
                        width: 24,
                        decoration: BoxDecoration(
                          color: bgColor, // 红色背景作为底色
                          borderRadius: BorderRadius.circular(4),
                          border: isToday ? Border.all(
                              color: theme.colorScheme.primary, width: 2
                          ) : null,
                        ),
                        alignment: Alignment.bottomCenter, // 底部对齐
                        child: FractionallySizedBox(
                          heightFactor: heightFactor,
                          widthFactor: 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: barColor, // 绿色作为正确率
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // 日期标签
                    Text(
                      isToday ? '今' : '${date.month}/${date.day}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday 
                            ? theme.colorScheme.primary 
                            : secondaryTextColor,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // 提示语
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.arrow_forward, size: 12, color: secondaryTextColor),
                const SizedBox(width: 4),
                Text(
                  '向左滑动查看更多', 
                  style: TextStyle(fontSize: 10, color: secondaryTextColor)
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
  
  /// 构建详细数据网格
  Widget _buildDetailGrid(
    BuildContext context, 
    ThemeData theme, 
    ThemeStyle style, 
    Map<String, dynamic> stats
  ) {
    final primaryColor = theme.colorScheme.primary;
    final warningColor = ThemeManager.getWarningColor(style);
    
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatItem(theme, style, '累计学习时长', 
          stats['totalDurationMinutes'] < 60 
          ? '${stats['totalDurationMinutes']}m' 
          : '${(stats['totalDurationMinutes'] / 60).toStringAsFixed(1)}h',
          Icons.access_time_filled, primaryColor
        ),
        _buildStatItem(theme, style, '当前连续打卡', 
          '${stats['streakDays']}天',
          Icons.local_fire_department, warningColor
        ),
        _buildStatItem(theme, style, '平均准确率', 
          '${((stats['averageAccuracy'] ?? 0) * 100).toInt()}%',
          Icons.check_circle, ThemeManager.getCorrectColor(style)
        ),
        _buildStatItem(theme, style, '词汇留存率', 
          '${((stats['retentionRate'] ?? 0) * 100).toInt()}%',
          Icons.psychology, Colors.purpleAccent
        ),
      ],
    );
  }
  
  Widget _buildStatItem(ThemeData theme, ThemeStyle style, String label, String value, IconData icon, Color color) {
    return Container(
      decoration: ThemeManager.getCardDecoration(style),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label, 
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ThemeManager.getSecondaryTextColor(style)
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: ThemeManager.getTextColor(style),
            ),
          ),
        ],
      ),
    );
  }

  ThemeStyle _parseThemeStyle(String value) {
    switch (value) {
      case 'highContrast': return ThemeStyle.highContrast;
      case 'bauhaus': return ThemeStyle.bauhaus;
      case 'minimal': return ThemeStyle.minimal;
      case 'nature': return ThemeStyle.nature;
      case 'cyberpunk': return ThemeStyle.cyberpunk;
      default: return ThemeStyle.standard;
    }
  }
}
