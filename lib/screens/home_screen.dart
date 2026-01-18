import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../session/base_providers.dart';
import '../models/models.dart';
import '../theme/theme_style.dart';
import '../theme/theme_manager.dart';
import '../session/session_models.dart';

/// 解析主题风格字符串
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

/// 主页面 - 支持多主题风格
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final themeStyle = _parseThemeStyle(settings.themeStyle);
    final gradientColors = ThemeManager.getGradientColors(themeStyle);
    final headerTextColor = ThemeManager.getHeaderTextColor(themeStyle);
    final isDark = ThemeManager.isDarkTheme(themeStyle);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: gradientColors[0] == gradientColors[1]
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: gradientColors,
                ),
          color: gradientColors[0] == gradientColors[1] ? gradientColors[0] : null,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 自定义应用栏
              _buildCustomAppBar(context, theme, themeStyle, headerTextColor),

              // 主要内容
              Expanded(
                child: ref
                    .watch(todayDeckProvider)
                    .when(
                      data: (words) => _buildCardGridContent(
                        context,
                        theme,
                        ref,
                        settings,
                        words,
                        themeStyle,
                      ),
                      loading: () => Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? Colors.white : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      error: (error, stack) =>
                          _buildErrorContent(context, theme, error, themeStyle),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar(
    BuildContext context,
    ThemeData theme,
    ThemeStyle themeStyle,
    Color headerTextColor,
  ) {
    final borderRadius = ThemeManager.getBorderRadius(themeStyle);
    final buttonBgColor = headerTextColor.withValues(alpha: 0.2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          // 返回按钮
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: buttonBgColor,
              borderRadius: BorderRadius.circular(borderRadius * 0.6),
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: headerTextColor,
                size: 18,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          const Spacer(),

          // 标题
          Text(
            'CEFR3000',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: headerTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),

          const Spacer(),

          // 菜单按钮
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: buttonBgColor,
              borderRadius: BorderRadius.circular(borderRadius * 0.6),
            ),
            child: IconButton(
              icon: Icon(Icons.apps, color: headerTextColor, size: 20),
              onPressed: () => Navigator.of(context).pushNamed('/settings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardGridContent(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
    AppSettings settings,
    List<Word> words,
    ThemeStyle themeStyle,
  ) {
    final contentDecoration = ThemeManager.getContentAreaDecoration(themeStyle);
    final textColor = ThemeManager.getTextColor(themeStyle);
    final secondaryTextColor = ThemeManager.getSecondaryTextColor(themeStyle);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: contentDecoration,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖拽指示器
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 欢迎文本
            Text(
              '选择学习模式',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              '开始你的词汇学习之旅',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // 功能卡片网格
            _buildFunctionGrid(context, theme, ref, words, themeStyle),

            const SizedBox(height: 32),

            // 统计信息卡片
            _buildStatsCards(context, theme, ref, themeStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildFunctionGrid(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
    List<Word> words,
    ThemeStyle themeStyle,
  ) {
    final primaryColor = theme.colorScheme.primary;
    final correctColor = ThemeManager.getCorrectColor(themeStyle);
    final warningColor = ThemeManager.getWarningColor(themeStyle);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        // 开始测试卡片
        _buildFunctionCard(
          context: context,
          theme: theme,
          themeStyle: themeStyle,
          title: '开始测试',
          subtitle: '${words.length} 个单词',
          icon: Icons.play_circle_fill,
          color: primaryColor,
          onTap: () => _startTest(context, ref),
        ),

        // 不熟悉单词卡片
        _buildFunctionCard(
          context: context,
          theme: theme,
          themeStyle: themeStyle,
          title: '不熟悉单词',
          subtitle: '重点练习',
          icon: Icons.bookmark,
          color: warningColor,
          onTap: () => Navigator.of(context).pushNamed('/leech_words'),
        ),

        // 设置卡片
        _buildFunctionCard(
          context: context,
          theme: theme,
          themeStyle: themeStyle,
          title: '设置',
          subtitle: '个性化配置',
          icon: Icons.settings,
          color: theme.colorScheme.secondary,
          onTap: () => Navigator.of(context).pushNamed('/settings'),
        ),

        // 统计卡片
        _buildFunctionCard(
          context: context,
          theme: theme,
          themeStyle: themeStyle,
          title: '学习统计',
          subtitle: '查看进度',
          icon: Icons.analytics,
          color: correctColor,
          onTap: () => Navigator.of(context).pushNamed('/stats'),
        ),
      ],
    );
  }

  Widget _buildFunctionCard({
    required BuildContext context,
    required ThemeData theme,
    required ThemeStyle themeStyle,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cardDecoration = ThemeManager.getCardDecoration(themeStyle, elevated: true);
    final iconDecoration = ThemeManager.getIconContainerDecoration(themeStyle, color);
    final textColor = ThemeManager.getTextColor(themeStyle);
    final secondaryTextColor = ThemeManager.getSecondaryTextColor(themeStyle);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: cardDecoration,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: iconDecoration,
                child: Icon(icon, color: color, size: 28),
              ),

              const SizedBox(height: 12),

              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 4),

              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
    ThemeStyle themeStyle,
  ) {
    final statsAsync = ref.watch(learningStatsProvider);
    final primaryColor = theme.colorScheme.primary;
    final correctColor = ThemeManager.getCorrectColor(themeStyle);
    final wrongColor = ThemeManager.getWrongColor(themeStyle);
    final warningColor = ThemeManager.getWarningColor(themeStyle);
    final textColor = ThemeManager.getTextColor(themeStyle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '学习统计',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),

        const SizedBox(height: 16),

        statsAsync.when(
          data: (stats) => Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context: context,
                      theme: theme,
                      themeStyle: themeStyle,
                      title: '学习时长', // 原“总测试”
                      value: stats['totalDurationMinutes'] < 60 
                          ? '${stats['totalDurationMinutes']}m' 
                          : '${(stats['totalDurationMinutes'] / 60).toStringAsFixed(1)}h',
                      icon: Icons.access_time_filled, // 图标改为时间
                      color: primaryColor,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _buildStatCard(
                      context: context,
                      theme: theme,
                      themeStyle: themeStyle,
                      title: '今日准确率',
                      value: stats['todayTests'] > 0 
                          ? '${((stats['todayAccuracy'] ?? 0.0) * 100).toInt()}%'
                          : '-',
                      icon: Icons.track_changes,
                      color: correctColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context: context,
                      theme: theme,
                      themeStyle: themeStyle,
                      title: '今日测试',
                      value: '${stats['todayTests'] ?? 0}次',
                      icon: Icons.today,
                      color: warningColor,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _buildStatCard(
                      context: context,
                      theme: theme,
                      themeStyle: themeStyle,
                      title: '连续学习',
                      value: '${stats['streakDays'] ?? 0}天',
                      icon: Icons.local_fire_department,
                      color: wrongColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => Center(
            child: Text(
              '统计加载失败',
              style: TextStyle(color: textColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required ThemeData theme,
    required ThemeStyle themeStyle,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final decoration = ThemeManager.getStatCardDecoration(themeStyle, color);
    final textColor = ThemeManager.getTextColor(themeStyle);
    final secondaryTextColor = ThemeManager.getSecondaryTextColor(themeStyle);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: secondaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorContent(
    BuildContext context,
    ThemeData theme,
    Object error,
    ThemeStyle themeStyle,
  ) {
    final contentDecoration = ThemeManager.getContentAreaDecoration(themeStyle);
    final textColor = ThemeManager.getTextColor(themeStyle);
    final secondaryTextColor = ThemeManager.getSecondaryTextColor(themeStyle);
    
    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: contentDecoration,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '错误信息：$error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _startTest(BuildContext context, WidgetRef ref) {
    final settings = ref.read(appSettingsProvider);
    final delay = settings.delayConfig;
    final config = SessionConfig(
      levels: settings.selectedLevelsSet,
      wordsPerSession: settings.wordsPerSession,
      timeLimitMs: settings.timeLimitMs,
      orderPolicy: settings.orderPolicy,
      onlyLeeches: settings.onlyLeeches,
      wrongDelay: delay.wrongDelay,
      slowDelay: delay.slowDelay,
      slowThreshold: settings.slowThreshold,
    );

    Navigator.of(context).pushNamed('/test', arguments: config);
  }
}
