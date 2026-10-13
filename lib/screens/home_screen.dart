import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../session/base_providers.dart';
import '../models/models.dart';
import '../theme/theme_style.dart';
import '../theme/theme_manager.dart';
import '../theme/fono_theme.dart';
import '../theme/digitalism_theme.dart';
import '../session/session_models.dart';
import 'active_recall_screen.dart';
import 'production_recall_screen.dart';
import 'home/tablet_home_layout.dart';
import '../features/sync/presentation/sync_status_badge.dart';

/// 主页面 - 支持多主题风格
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final themeStyle = ThemeStyle.fromString(settings.themeStyle);
    final gradientColors = ThemeManager.getGradientColors(themeStyle);
    final headerTextColor = ThemeManager.getHeaderTextColor(themeStyle);
    final isDark = ThemeManager.isDarkTheme(themeStyle);
    // 按最短边判断平板，避免手机横屏误用平板布局。
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    final scaffoldBody = Container(
      decoration: BoxDecoration(
        gradient: gradientColors[0] == gradientColors[1]
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: gradientColors,
              ),
        color: gradientColors[0] == gradientColors[1]
            ? gradientColors[0]
            : null,
      ),
      child: SafeArea(
        child: isTablet
            ? TabletHomeLayout(
                themeStyle: themeStyle,
                wordCount:
                    ref.watch(todayDeckProvider).asData?.value.length ?? 0,
                onStartTest: () => _startTest(context, ref),
                onStartProduction: () => _startProduction(context, ref),
                onStartPlan: (wordIds) => _startPlan(context, ref, wordIds),
              )
            : Column(
                children: [
                  // 自定义应用栏
                  _buildCustomAppBar(
                    context,
                    theme,
                    themeStyle,
                    headerTextColor,
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SyncStatusBadge(
                        color: ThemeManager.getSecondaryTextColor(themeStyle),
                      ),
                    ),
                  ),

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
                                isDark
                                    ? Colors.white
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          error: (error, stack) => _buildErrorContent(
                            context,
                            theme,
                            error,
                            themeStyle,
                          ),
                        ),
                  ),
                ],
              ),
      ),
    );

    return Scaffold(
      body: themeStyle == ThemeStyle.fono
          ? FonoGridBackground(child: scaffoldBody)
          : scaffoldBody,
    );
  }

  String _formatHeaderDate() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  Widget _buildCustomAppBar(
    BuildContext context,
    ThemeData theme,
    ThemeStyle themeStyle,
    Color headerTextColor,
  ) {
    if (themeStyle == ThemeStyle.digitalism) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Container(
          decoration: BoxDecoration(
            color: DigitalismTheme.surface,
            borderRadius: BorderRadius.circular(DigitalismTheme.buttonRadius),
            border: Border.all(
              color: DigitalismTheme.border,
              width: DigitalismTheme.borderWidth,
            ),
            boxShadow: DigitalismTheme.smallShadow,
          ),
          child: DigitalismWindowHeader(
            title: 'CEFR3000 // ${_formatHeaderDate()}',
            showDivider: false,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed('/settings'),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.settings,
                      color: DigitalismTheme.textPrimary,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: DigitalismTheme.textPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: DigitalismTheme.textPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: DigitalismTheme.textPrimary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

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

            if (themeStyle == ThemeStyle.digitalism) ...[
              const SizedBox(height: 16),
              const DigitalismBanner(
                title: 'MY VOCABULARY RESOLUTIONS',
                subtitle: 'DAILY RETENTION & SRS PRACTICE',
              ),
            ],

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

            // 今日计划：计划阶段只读，不会因为打开首页而消耗新词额度。
            ref
                .watch(todayStudyPlanProvider)
                .when(
                  data: (plan) => _buildTodayPlanBanner(
                    context,
                    theme,
                    ref,
                    themeStyle,
                    plan.items.length,
                    plan.newItemCount,
                    plan.estimatedSeconds,
                    plan.wordIds.toList(),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

            const SizedBox(height: 20),

            // 功能卡片网格 (2x2 黄金矩阵)
            _buildFunctionGrid(context, theme, ref, words, themeStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayPlanBanner(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
    ThemeStyle themeStyle,
    int itemCount,
    int newCount,
    int estimatedSeconds,
    List<int> wordIds,
  ) {
    final textColor = ThemeManager.getTextColor(themeStyle);
    final secondary = ThemeManager.getSecondaryTextColor(themeStyle);
    final borderColor = ThemeManager.getBorderColor(themeStyle);
    final minutes = (estimatedSeconds / 60).ceil();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ThemeManager.getSurfaceColor(themeStyle),
        borderRadius: BorderRadius.circular(
          ThemeManager.getBorderRadius(themeStyle),
        ),
        border: Border.all(color: borderColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.today_outlined,
            color: ThemeManager.getCorrectColor(themeStyle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日学习计划',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  itemCount == 0
                      ? '今天没有到期任务，可以选择额外练习'
                      : '$itemCount 个学习项 · $newCount 个新词 · 约 $minutes 分钟',
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '开始今日计划',
            icon: const Icon(Icons.arrow_forward_ios, size: 16),
            color: textColor,
            onPressed: () => _startPlan(context, ref, wordIds),
          ),
        ],
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
    final activeSession = ref.watch(sessionControllerProvider);
    final hasPausedTest =
        activeSession.sessionId.isNotEmpty &&
        (activeSession.state == SessionState.waiting ||
            activeSession.state == SessionState.resolved ||
            activeSession.state == SessionState.saveFailed);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.0,
      children: [
        // 开始测试卡片
        _buildFunctionCard(
          context: context,
          theme: theme,
          themeStyle: themeStyle,
          title: hasPausedTest ? '继续测试' : '开始测试',
          subtitle: hasPausedTest
              ? '已测 ${activeSession.testedWordCount} / ${activeSession.totalWords}'
              : '${words.length} 个单词',
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

        // 看义拼词卡片：从释义主动回想拼写英文单词
        _buildFunctionCard(
          context: context,
          theme: theme,
          themeStyle: themeStyle,
          title: '看义拼词',
          subtitle: '从释义写单词',
          icon: Icons.spellcheck_rounded,
          color: ThemeManager.getProductionColor(themeStyle),
          onTap: () => _startProduction(context, ref),
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
    final cardDecoration = ThemeManager.getCardDecoration(
      themeStyle,
      elevated: true,
    );
    final iconDecoration = ThemeManager.getIconContainerDecoration(
      themeStyle,
      color,
    );
    final textColor = ThemeManager.getTextColor(themeStyle);
    final secondaryTextColor = ThemeManager.getSecondaryTextColor(themeStyle);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: cardDecoration,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: iconDecoration,
                child: Icon(icon, color: color, size: 24),
              ),

              const SizedBox(height: 8),

              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 2),

              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: secondaryTextColor,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
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

  static bool _isNavigating = false;

  void _startPlan(BuildContext context, WidgetRef ref, List<int> wordIds) {
    final settings = ref.read(appSettingsProvider);
    Navigator.of(context).pushNamed(
      '/recall',
      arguments: ActiveRecallArgs(
        config: SessionConfig.fromAppSettings(settings).copyWith(
          plannedWordIds: wordIds,
          wordsPerSession: wordIds.isEmpty
              ? settings.wordsPerSession
              : wordIds.length,
        ),
        wordIds: wordIds,
      ),
    );
  }

  void _startTest(BuildContext context, WidgetRef ref) {
    if (_isNavigating) return;
    _isNavigating = true;
    final activeSession = ref.read(sessionControllerProvider);
    if (activeSession.sessionId.isNotEmpty &&
        (activeSession.state == SessionState.waiting ||
            activeSession.state == SessionState.resolved ||
            activeSession.state == SessionState.saveFailed)) {
      _isNavigating = false;
      Navigator.of(context).pushNamed('/test', arguments: activeSession.config);
      return;
    }
    final settings = ref.read(appSettingsProvider);
    final baseConfig = SessionConfig.fromAppSettings(settings);
    ref
        .read(todayRecognitionPlanProvider.future)
        .then((plan) {
          _isNavigating = false;
          if (!context.mounted) return;
          if (plan.items.isEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('当前范围没有符合条件的识别复习任务')));
            return;
          }
          final config = baseConfig.copyWith(
            plannedWordIds: plan.items.map((item) => item.wordId).toList(),
          );
          Navigator.of(context).pushNamed('/test', arguments: config);
        })
        .catchError((error) {
          _isNavigating = false;
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('无法生成今日计划：$error')));
        });
  }

  void _startProduction(BuildContext context, WidgetRef ref) {
    if (_isNavigating) return;
    _isNavigating = true;
    final settings = ref.read(appSettingsProvider);
    final baseConfig = SessionConfig.fromAppSettings(settings);
    ref
        .read(todayProductionPlanProvider.future)
        .then((plan) {
          _isNavigating = false;
          if (!context.mounted) return;
          Navigator.of(context).pushNamed(
            '/production',
            arguments: ProductionRecallArgs(
              config: baseConfig.copyWith(
                plannedWordIds: plan.wordIds.toList(),
                wordsPerSession: plan.items.isEmpty
                    ? baseConfig.wordsPerSession
                    : plan.items.length,
              ),
              wordIds: plan.wordIds.toList(),
            ),
          );
        })
        .catchError((_) {
          _isNavigating = false;
          if (!context.mounted) return;
          Navigator.of(context).pushNamed(
            '/production',
            arguments: ProductionRecallArgs(
              config: baseConfig,
              wordIds: const [],
            ),
          );
        });
  }
}
