import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../session/base_providers.dart';
import '../session/session_controller.dart';
import '../session/session_models.dart';
import '../models/question.dart';
import '../theme/theme_style.dart';
import '../theme/theme_manager.dart';
import '../utils/responsive_layout.dart';
import '../widgets/countdown_ring.dart';
import '../widgets/option_button.dart';
import 'summary_screen.dart';

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

/// 测试页面 - 支持多主题风格
class TestScreen extends ConsumerStatefulWidget {
  final SessionConfig config;

  const TestScreen({super.key, required this.config});

  @override
  ConsumerState<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends ConsumerState<TestScreen>
    with WidgetsBindingObserver {
  
  SessionController? _sessionController;
  bool _navigatedToSummary = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navigatedToSummary = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sessionController = ref.read(sessionControllerProvider.notifier);
      final settings = ref.read(appSettingsProvider);

      if (settings.hasActiveSession) {
        _sessionController?.startSession(
          widget.config,
          resumeSessionId: settings.currentSessionId,
          remainingWordIds: settings.remainingWordIds,
          currentProgress: settings.currentProgress,
        );
      } else {
        _sessionController?.startSession(widget.config);
      }
    });
  }

  @override
  void dispose() {
    _sessionController?.stopSession();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final sessionController = _sessionController;
    if (sessionController == null) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        sessionController.pauseSession();
        break;
      case AppLifecycleState.resumed:
        sessionController.resumeSession();
        break;
      case AppLifecycleState.detached:
        sessionController.stopSession();
        break;
      case AppLifecycleState.hidden:
        sessionController.pauseSession();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionData = ref.watch(sessionControllerProvider);
    final settings = ref.watch(appSettingsProvider);
    final themeStyle = _parseThemeStyle(settings.themeStyle);
    final gradientColors = ThemeManager.getGradientColors(themeStyle);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _handleWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
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
          child: _buildBody(context, theme, sessionData, settings, themeStyle),
        ),
      ),
    );
  }

  Future<bool> _handleWillPop() async {
    final sessionData = ref.read(sessionControllerProvider);

    if (sessionData.state == SessionState.finished) {
      return true;
    }

    if (sessionData.state != SessionState.idle) {
      await _saveTestProgress();
    }

    ref.read(sessionControllerProvider.notifier).stopSession();
    return true;
  }

  Future<void> _saveTestProgress() async {
    final sessionData = ref.read(sessionControllerProvider);
    final settings = ref.read(appSettingsProvider.notifier);

    if (sessionData.state == SessionState.idle ||
        sessionData.state == SessionState.finished) {
      return;
    }

    final remainingWordIds = <int>[];
    remainingWordIds.addAll(sessionData.mainQueue.map((w) => w.id));
    remainingWordIds.addAll(sessionData.delayedQueue.map((item) => item.wordId));

    if (sessionData.currentQuestion != null) {
      remainingWordIds.add(sessionData.currentQuestion!.word.id);
    }

    await settings.saveTestProgress(
      sessionId: sessionData.sessionId,
      currentProgress: sessionData.attempts.length,
      totalWords: sessionData.config.wordsPerSession,
      remainingWordIds: remainingWordIds,
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    SessionData sessionData,
    settings,
    ThemeStyle themeStyle,
  ) {
    switch (sessionData.state) {
      case SessionState.idle:
      case SessionState.presenting:
        return _buildLoadingState(theme, themeStyle);
      case SessionState.waiting:
      case SessionState.resolved:
        return _buildTestingState(context, theme, sessionData, settings, themeStyle);
      case SessionState.finished:
        if (!_navigatedToSummary) {
          _navigatedToSummary = true;
          _navigateToSummary(context, sessionData);
        }
        return _buildLoadingState(theme, themeStyle);
    }
  }

  Widget _buildLoadingState(ThemeData theme, ThemeStyle themeStyle) {
    final cardDecoration = ThemeManager.getCardDecoration(themeStyle, elevated: true);
    final textColor = ThemeManager.getTextColor(themeStyle);
    
    return SafeArea(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: cardDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
              const SizedBox(height: 24),
              Text(
                '准备中...',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestingState(
    BuildContext context,
    ThemeData theme,
    SessionData sessionData,
    settings,
    ThemeStyle themeStyle,
  ) {
    final question = sessionData.currentQuestion;
    if (question == null) {
      return _buildLoadingState(theme, themeStyle);
    }

    return ResponsiveLayout.buildResponsive(
      context: context,
      mobile: _buildMobileTestLayout(context, theme, sessionData, settings, question, themeStyle),
      tablet: _buildTabletTestLayout(context, theme, sessionData, settings, question, themeStyle),
    );
  }

  Widget _buildMobileTestLayout(
    BuildContext context,
    ThemeData theme,
    SessionData sessionData,
    settings,
    Question question,
    ThemeStyle themeStyle,
  ) {
    final contentDecoration = ThemeManager.getContentAreaDecoration(themeStyle);
    final headerTextColor = ThemeManager.getHeaderTextColor(themeStyle);
    final borderRadius = ThemeManager.getBorderRadius(themeStyle);
    final textColor = ThemeManager.getTextColor(themeStyle);
    final surfaceColor = ThemeManager.getSurfaceColor(themeStyle);
    
    return Consumer(
      builder: (context, ref, child) {
        final currentSessionData = ref.watch(sessionControllerProvider);
        final isPaused = currentSessionData.isPaused;
        final data = currentSessionData;
        final activeQuestion = data.currentQuestion ?? question;
        
        return SafeArea(
          child: Stack(
            children: [
              // 主要内容
              Column(
                children: [
                  // 顶部进度栏
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: headerTextColor.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: LinearProgressIndicator(
                                  value: data.attempts.length / data.config.wordsPerSession,
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation<Color>(headerTextColor),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // 暂停按钮
                            GestureDetector(
                              onTap: () {
                                final controller = ref.read(sessionControllerProvider.notifier);
                                print('Pause button tapped, isPaused=$isPaused, state=${currentSessionData.state}');
                                if (isPaused) {
                                  controller.resumeSession();
                                } else {
                                  controller.pauseSession();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: headerTextColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(borderRadius),
                                ),
                                child: Icon(
                                  isPaused ? Icons.play_arrow : Icons.pause,
                                  color: headerTextColor,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 重置按钮
                            GestureDetector(
                              onTap: () => _showResetConfirmDialog(context, ref),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: headerTextColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(borderRadius),
                                ),
                                child: Icon(
                                  Icons.refresh,
                                  color: headerTextColor,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${data.attempts.length + 1} / ${data.config.wordsPerSession}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: headerTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 主要内容卡片
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(top: 20),
                      decoration: contentDecoration,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                child: IntrinsicHeight(
                                  child: Column(
                                    children: [
                                      Flexible(
                                        flex: 2,
                                        child: SingleChildScrollView(
                                              child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              _buildWordDisplay(context, theme, settings, activeQuestion, themeStyle),
                                              const SizedBox(height: 16),
                                              _buildWordBadges(context, theme, activeQuestion, themeStyle),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        child: CountdownRing(
                                          totalTimeMs: data.config.timeLimitMs,
                                          remainingTimeMs: data.millisLeft,
                                          size: 80,
                                          themeStyle: themeStyle,
                                        ),
                                      ),
                                      Flexible(
                                        flex: 2,
                                        child: SingleChildScrollView(
                                          child: _buildOptionButtons(context, theme, data, activeQuestion, themeStyle),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              // 暂停遮罩
              if (isPaused)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      // 点击遮罩恢复
                      final controller = ref.read(sessionControllerProvider.notifier);
                      controller.resumeSession();
                    },
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.7),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(borderRadius),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.pause_circle_filled,
                                    size: 64,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '已暂停',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '点击任意位置继续',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: textColor.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabletTestLayout(
    BuildContext context,
    ThemeData theme,
    SessionData sessionData,
    settings,
    Question question,
    ThemeStyle themeStyle,
  ) {
    final textColor = ThemeManager.getTextColor(themeStyle);
    final surfaceColor = ThemeManager.getSurfaceColor(themeStyle);
    final borderRadius = ThemeManager.getBorderRadius(themeStyle);
    
    return Consumer(
      builder: (context, ref, child) {
        final currentSessionData = ref.watch(sessionControllerProvider);
        final isPaused = currentSessionData.isPaused;
        final data = currentSessionData;
        final activeQuestion = data.currentQuestion ?? question;
        
        return SafeArea(
          child: Stack(
            children: [
              // 主要内容
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildWordDisplay(context, theme, settings, activeQuestion, themeStyle, isTablet: true),
                            const SizedBox(height: 24),
                            _buildWordBadges(context, theme, activeQuestion, themeStyle, isTablet: true),
                            const SizedBox(height: 32),
                            _buildProgressInfo(context, theme, data, themeStyle),
                            const SizedBox(height: 16),
                            // 平板端暂停按钮
                            GestureDetector(
                              onTap: () {
                                final controller = ref.read(sessionControllerProvider.notifier);
                                print('Tablet pause button tapped, isPaused=$isPaused, state=${currentSessionData.state}');
                                if (isPaused) {
                                  controller.resumeSession();
                                } else {
                                  controller.pauseSession();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(borderRadius),
                                  border: Border.all(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isPaused ? Icons.play_arrow : Icons.pause,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isPaused ? '继续' : '暂停',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // 重置按钮
                            GestureDetector(
                              onTap: () => _showResetConfirmDialog(context, ref),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(borderRadius),
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.refresh,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '重置',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          CountdownRing(
                            totalTimeMs: data.config.timeLimitMs,
                            remainingTimeMs: data.millisLeft,
                            size: 120,
                            themeStyle: themeStyle,
                          ),
                          const SizedBox(height: 32),
                          Expanded(
                            child: SingleChildScrollView(
                              child: _buildOptionButtons(context, theme, data, activeQuestion, themeStyle),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 暂停遮罩
              if (isPaused)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      final controller = ref.read(sessionControllerProvider.notifier);
                      controller.resumeSession();
                    },
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.7),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(borderRadius),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pause_circle_filled,
                                size: 80,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                '已暂停',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '点击任意位置继续',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: textColor.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToSummary(BuildContext context, SessionData sessionData) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        // 清除进行中的测试进度并刷新统计
        ref.read(appSettingsProvider.notifier).clearTestProgress();
        ref.invalidate(learningStatsProvider);

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SummaryScreen(sessionData: sessionData),
          ),
        );
      }
    });
  }

  Widget _buildWordDisplay(
    BuildContext context,
    ThemeData theme,
    settings,
    Question question,
    ThemeStyle themeStyle, {
    bool isTablet = false,
  }) {
    final isDark = ThemeManager.isDarkTheme(themeStyle);
    final textColor = ThemeManager.getTextColor(themeStyle);
    final borderRadius = ThemeManager.getBorderRadius(themeStyle);
    final borderColor = ThemeManager.getBorderColor(themeStyle);
    final borderWidth = ThemeManager.getBorderWidth(themeStyle);
    
    final containerColor = isDark 
        ? ThemeManager.getSurfaceColor(themeStyle) 
        : theme.colorScheme.primaryContainer;
    final contentTextColor = isDark 
        ? textColor 
        : theme.colorScheme.onPrimaryContainer;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 32 : 24),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: ThemeManager.needsBorder(themeStyle) 
            ? Border.all(color: borderColor, width: borderWidth) 
            : null,
      ),
      child: Column(
        children: [
          Text(
            question.word.headword,
            style: (isTablet ? theme.textTheme.displayMedium : theme.textTheme.headlineLarge)?.copyWith(
              fontWeight: FontWeight.bold,
              color: contentTextColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (question.word.pos.isNotEmpty) ...[
            SizedBox(height: isTablet ? 12 : 8),
            Text(
              question.word.pos,
              style: (isTablet ? theme.textTheme.titleMedium : theme.textTheme.titleSmall)?.copyWith(
                color: contentTextColor.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWordBadges(
    BuildContext context,
    ThemeData theme,
    Question question,
    ThemeStyle themeStyle, {
    bool isTablet = false,
  }) {
    final isDark = ThemeManager.isDarkTheme(themeStyle);
    final textColor = ThemeManager.getTextColor(themeStyle);
    final surfaceColor = ThemeManager.getSurfaceColor(themeStyle);
    final borderRadius = ThemeManager.getBorderRadius(themeStyle);
    final borderColor = ThemeManager.getBorderColor(themeStyle);
    
    final levelBgColor = isDark ? surfaceColor : theme.colorScheme.secondary;
    final levelTextColor = isDark ? textColor : theme.colorScheme.onSecondary;
    final posBgColor = isDark ? surfaceColor : theme.colorScheme.tertiary;
    final posTextColor = isDark ? textColor : theme.colorScheme.onTertiary;
    
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: isTablet ? 12 : 8,
      runSpacing: 8,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 16 : 12,
            vertical: isTablet ? 8 : 6,
          ),
          decoration: BoxDecoration(
            color: levelBgColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: isDark ? Border.all(color: borderColor, width: 1) : null,
          ),
          child: Text(
            question.word.level,
            style: (isTablet ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)?.copyWith(
              color: levelTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (question.word.majorPos.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: isTablet ? 8 : 6,
            ),
            decoration: BoxDecoration(
              color: posBgColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: isDark ? Border.all(color: borderColor, width: 1) : null,
            ),
            child: Text(
              question.word.majorPos,
              style: (isTablet ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)?.copyWith(
                color: posTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressInfo(
    BuildContext context,
    ThemeData theme,
    SessionData sessionData,
    ThemeStyle themeStyle,
  ) {
    final textColor = ThemeManager.getTextColor(themeStyle);
    final cardDecoration = ThemeManager.getCardDecoration(themeStyle);
    final progressBgColor = ThemeManager.getProgressBackgroundColor(themeStyle);
    final progressColor = theme.colorScheme.primary;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration,
      child: Column(
        children: [
          Text(
            '进度',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: sessionData.attempts.length / sessionData.config.wordsPerSession,
            backgroundColor: progressBgColor,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
          const SizedBox(height: 8),
          Text(
            '${sessionData.attempts.length + 1} / ${sessionData.config.wordsPerSession}',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButtons(
    BuildContext context,
    ThemeData theme,
    SessionData sessionData,
    Question question,
    ThemeStyle themeStyle,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(
          question.options.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OptionButton(
              text: question.options[index],
              label: ['A', 'B', 'C', 'D'][index],
              isSelected: sessionData.selectedOption == index,
              isCorrect: sessionData.state == SessionState.resolved && index == question.correctIndex,
              isWrong: sessionData.state == SessionState.resolved &&
                  sessionData.selectedOption == index &&
                  index != question.correctIndex,
              isRevealed: sessionData.state == SessionState.resolved,
              themeStyle: themeStyle,
              onPressed: sessionData.state == SessionState.waiting
                  ? () => ref.read(sessionControllerProvider.notifier).selectOption(index)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// 显示重置确认对话框
  void _showResetConfirmDialog(BuildContext context, WidgetRef ref) {
    // 先暂停测试
    ref.read(sessionControllerProvider.notifier).pauseSession();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重置测试'),
        content: const Text('确定要重置当前测试吗？当前进度将不会被保存。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // 恢复测试
              ref.read(sessionControllerProvider.notifier).resumeSession();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              // 清除进度并重新开始
              await ref.read(appSettingsProvider.notifier).clearTestProgress();
              // 重新开始测试：保持本轮单词集合，顺序重新打乱
              await ref
                  .read(sessionControllerProvider.notifier)
                  .restartWithSameWords(shuffle: true);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }
}
