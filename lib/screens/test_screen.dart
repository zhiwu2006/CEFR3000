import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/sync/data/cloudflare_sync.dart';
import '../session/base_providers.dart';
import '../session/session_controller.dart';
import '../session/session_models.dart';
import '../models/question.dart';
import '../theme/theme_style.dart';
import '../theme/theme_manager.dart';
import '../theme/fono_theme.dart';
import '../theme/digitalism_theme.dart';
import '../utils/responsive_layout.dart';
import '../widgets/countdown_ring.dart';
import '../widgets/option_button.dart';
import 'summary_screen.dart';

/// 解析主题风格字符串
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
  bool _resumeWhenForeground = false;
  bool _leavingTestPage = false;
  Timer? _resumeDelayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navigatedToSummary = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSessionFromCheckpoint();
    });
  }

  Future<void> _startSessionFromCheckpoint() async {
    if (!mounted) return;
    _sessionController = ref.read(sessionControllerProvider.notifier);
    final activeSession = ref.read(sessionControllerProvider);
    if (activeSession.sessionId.isNotEmpty &&
        (activeSession.state == SessionState.waiting ||
            activeSession.state == SessionState.resolved ||
            activeSession.state == SessionState.saveFailed)) {
      // 从首页返回时保留原题目、答题记录和暂停状态，不能重新选词覆盖它们。
      // 返回手势在部分 Android 版本会额外发送 resumed 回调，因此这里
      // 强制重新暂停，保证恢复页至少展示两秒暂停状态。
      _sessionController?.pauseSession();
      _resumeAfterBriefPause();
      return;
    }
    final store = await ref.read(sessionCheckpointStoreProvider.future);
    if (!mounted) return;
    final checkpoint = store.load();
    final sessionConfig =
        SessionConfig.fromCheckpointMap(checkpoint?.config ?? {}) ??
        widget.config;

    // 恢复判据以「检查点」为准，而不是 settings.hasActiveSession。
    // hasActiveSession 依赖 currentSessionId，而该字段只由
    // stageCustomSession 写入 —— 首页「开始学习」发起的会话从不写它，
    // 会导致进程被杀后重启时已保存的检查点被读取后丢弃、整轮从零开始。
    if (checkpoint != null && checkpoint.isResumable) {
      await _sessionController?.startSession(
        sessionConfig,
        resumeSessionId: checkpoint.sessionId,
        remainingWordIds: checkpoint.mainQueueWordIds,
        currentProgress: checkpoint.currentProgress,
        checkpoint: checkpoint,
      );
    } else {
      await _sessionController?.startSession(widget.config);
    }
  }

  @override
  void dispose() {
    // 离开测试页只是暂停；整轮完成前不保存学习记录，也不丢弃会话。
    _resumeWhenForeground = false;
    _resumeDelayTimer?.cancel();
    _sessionController?.pauseSession();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final sessionController = _sessionController;
    if (sessionController == null) return;
    if (_leavingTestPage) return;

    // 生命周期事件只暂停/恢复内存中的计时器，不等待存储。
    // inactive / hidden / paused 可连续触发，控制器中的暂停是幂等的。
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _resumeDelayTimer?.cancel();
        _resumeWhenForeground = true;
        sessionController.pauseSession();
        break;
      case AppLifecycleState.resumed:
        if (_resumeWhenForeground) {
          _resumeWhenForeground = false;
          _resumeAfterBriefPause();
        }
        break;
    }
  }

  /// 返回测试页时先保持暂停遮罩两秒，让用户确认已回到原题后再继续。
  void _resumeAfterBriefPause() {
    _resumeDelayTimer?.cancel();
    _resumeDelayTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _sessionController?.resumeSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 精细化响应式：监听生命周期与题目状态，阻断倒计时高频重绘外层整树
    ref.watch(
      sessionControllerProvider.select(
        (s) => (
          state: s.state,
          hasQuestion: s.currentQuestion != null,
          questionId: s.currentQuestion?.word.id,
        ),
      ),
    );
    final sessionData = ref.read(sessionControllerProvider);
    final settings = ref.watch(appSettingsProvider);
    final themeStyle = ThemeStyle.fromString(settings.themeStyle);
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
        body: themeStyle == ThemeStyle.fono
            ? FonoGridBackground(
                child: Container(
                  color: FonoTheme.background,
                  child: _buildBody(
                    context,
                    theme,
                    sessionData,
                    settings,
                    themeStyle,
                  ),
                ),
              )
            : Container(
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
                child: _buildBody(
                  context,
                  theme,
                  sessionData,
                  settings,
                  themeStyle,
                ),
              ),
      ),
    );
  }

  Future<bool> _handleWillPop() async {
    final controller = ref.read(sessionControllerProvider.notifier);
    if (ref.read(sessionControllerProvider).state == SessionState.saving) {
      return false;
    }
    _leavingTestPage = true;
    _resumeWhenForeground = false;
    _resumeDelayTimer?.cancel();
    controller.pauseSession();
    return true;
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
      case SessionState.studying:
        return _buildStudyState(context, theme, sessionData, themeStyle);
      case SessionState.waiting:
      case SessionState.resolved:
        return _buildTestingState(
          context,
          theme,
          sessionData,
          settings,
          themeStyle,
        );
      case SessionState.saving:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('测试完成，正在保存…'),
            ],
          ),
        );
      case SessionState.saveFailed:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('测试已完成，保存失败，答案仍保留在本次会话中。'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.read(sessionControllerProvider.notifier).retrySave(),
                child: const Text('重试保存'),
              ),
            ],
          ),
        );
      case SessionState.finished:
        if (!_navigatedToSummary) {
          _navigatedToSummary = true;
          _navigateToSummary(context, sessionData);
        }
        return _buildLoadingState(theme, themeStyle);
    }
  }

  Widget _buildLoadingState(ThemeData theme, ThemeStyle themeStyle) {
    final cardDecoration = ThemeManager.getCardDecoration(
      themeStyle,
      elevated: true,
    );
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
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
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

  /// 新词学习卡：先看清词义，点继续后隔几题再考，不计时、不计分。
  Widget _buildStudyState(
    BuildContext context,
    ThemeData theme,
    SessionData sessionData,
    ThemeStyle themeStyle,
  ) {
    final question = sessionData.currentQuestion;
    if (question == null) return _buildLoadingState(theme, themeStyle);
    final word = question.word;
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final textColor = ThemeManager.getTextColor(themeStyle);
    final secondary = ThemeManager.getSecondaryTextColor(themeStyle);
    final controller = ref.read(sessionControllerProvider.notifier);

    final header = Text(
      '新词 · 先记一下，稍后再考',
      textAlign: TextAlign.center,
      style:
          (isTablet ? theme.textTheme.titleMedium : theme.textTheme.labelLarge)
              ?.copyWith(color: secondary),
    );
    final wordDisplay = _buildWordDisplay(
      context,
      theme,
      null,
      question,
      themeStyle,
      isTablet: isTablet,
    );
    final definitions = Container(
      padding: EdgeInsets.all(isTablet ? 28 : 20),
      decoration: ThemeManager.getCardDecoration(themeStyle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '释义',
            style:
                (isTablet
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.labelMedium)
                    ?.copyWith(color: secondary),
          ),
          SizedBox(height: isTablet ? 16 : 8),
          for (var i = 0; i < word.cnDefs.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: isTablet ? 14 : 6),
              child: Text(
                word.cnDefs.length > 1
                    ? '${i + 1}. ${word.cnDefs[i]}'
                    : word.cnDefs[i],
                style:
                    (isTablet
                            ? theme.textTheme.headlineSmall
                            : theme.textTheme.titleMedium)
                        ?.copyWith(color: textColor, height: 1.4),
              ),
            ),
          if (word.cnDefs.isEmpty)
            Text(
              '暂无释义',
              style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
            ),
        ],
      ),
    );
    final buttonHeight = isTablet ? 72.0 : 48.0;
    // 只调字号，颜色交给按钮自身，否则深色按钮上的文字会变成同色看不见。
    final buttonText = isTablet
        ? TextStyle(fontSize: theme.textTheme.titleMedium?.fontSize)
        : null;
    final buttons = Row(
      children: [
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: OutlinedButton.icon(
              onPressed: () =>
                  ref.read(ttsServiceProvider).speak(word.headword),
              icon: const Icon(Icons.volume_up_outlined),
              label: Text('再听一遍', style: buttonText),
            ),
          ),
        ),
        SizedBox(width: isTablet ? 24 : 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: buttonHeight,
            child: FilledButton(
              onPressed: sessionData.isPaused
                  ? null
                  : controller.finishStudyCard,
              child: Text('记住了，继续', style: buttonText),
            ),
          ),
        ),
      ],
    );

    final size = MediaQuery.sizeOf(context);
    if (isTablet && size.width > size.height) {
      // 平板横屏：单词和释义并排、上下居中对齐，操作按钮通栏放在底部。
      return Padding(
        padding: const EdgeInsets.fromLTRB(40, 56, 40, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: wordDisplay),
                  const SizedBox(width: 40),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SizedBox(
                        width: double.infinity,
                        child: definitions,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            buttons,
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isTablet ? 720 : 640),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isTablet ? 32 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 16),
              wordDisplay,
              const SizedBox(height: 20),
              definitions,
              SizedBox(height: isTablet ? 32 : 24),
              buttons,
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
      mobile: _buildMobileTestLayout(
        context,
        theme,
        sessionData,
        settings,
        question,
        themeStyle,
      ),
      tablet: _buildTabletTestLayout(
        context,
        theme,
        sessionData,
        settings,
        question,
        themeStyle,
      ),
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
        // 精细化监听：过滤倒计时，仅在题目变动、状态迁移或用户交互时触发重绘
        ref.watch(
          sessionControllerProvider.select(
            (s) => (
              state: s.state,
              isPaused: s.isPaused,
              questionId: s.currentQuestion?.word.id,
              selectedOption: s.selectedOption,
              lastCorrect: s.lastCorrect,
              currentProgress: s.currentProgress,
              attemptsCount: s.attempts.length,
            ),
          ),
        );
        final currentSessionData = ref.read(sessionControllerProvider);
        final isPaused = currentSessionData.isPaused;
        final data = currentSessionData;
        final activeQuestion = data.currentQuestion ?? question;

        return SafeArea(
          child: Stack(
            children: [
              // 主要内容
              Column(
                children: [
                  // 顶部极简紧凑进度栏
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                    child: Row(
                      children: [
                        // 紧凑进度数字徽章
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: headerTextColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              borderRadius > 6 ? 6 : borderRadius,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.testProgressLabel,
                                style: TextStyle(
                                  color: headerTextColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  fontFamily:
                                      themeStyle == ThemeStyle.digitalism ||
                                          themeStyle == ThemeStyle.fono
                                      ? 'monospace'
                                      : null,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (data.testGroupLabel.isNotEmpty)
                                Text(
                                  data.testGroupLabel,
                                  style: TextStyle(
                                    color: headerTextColor,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // 细致进度条
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: headerTextColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: data.testedProgressRatio,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  headerTextColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // 暂停按钮
                        GestureDetector(
                          onTap: () {
                            final controller = ref.read(
                              sessionControllerProvider.notifier,
                            );
                            if (isPaused) {
                              controller.resumeSession();
                            } else {
                              controller.pauseSession();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: headerTextColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                borderRadius > 6 ? 6 : borderRadius,
                              ),
                            ),
                            child: Icon(
                              isPaused ? Icons.play_arrow : Icons.pause,
                              color: headerTextColor,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // 重置按钮
                        GestureDetector(
                          onTap: () => _showResetConfirmDialog(context, ref),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: headerTextColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                borderRadius > 6 ? 6 : borderRadius,
                              ),
                            ),
                            child: Icon(
                              Icons.refresh,
                              color: headerTextColor,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 主要内容卡片
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: contentDecoration,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final availableHeight = constraints.maxHeight;
                            // 预估基础高度：单词区(~145) + 倒计时(~60) + 选项区(~236) ≈ 441
                            final remaining = (availableHeight - 441).clamp(
                              0.0,
                              1000.0,
                            );
                            // 核心间距：单词与倒计时、倒计时与选项严格均等，控制在 20~40dp 黄金区间，绝不过大
                            final double contentGap = (remaining * 0.20).clamp(
                              18.0,
                              38.0,
                            );
                            // 顶部与底部留白自适应分配剩余空间，保证单词在视觉上方、选项在大拇指黄金区
                            final double topSpacing = (remaining * 0.16).clamp(
                              12.0,
                              30.0,
                            );
                            final double bottomSpacing = (remaining * 0.32)
                                .clamp(16.0, 56.0);

                            return SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(height: topSpacing),
                                    // 单词展示与词性标签区
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildWordDisplay(
                                          context,
                                          theme,
                                          settings,
                                          activeQuestion,
                                          themeStyle,
                                        ),
                                        const SizedBox(height: 8),
                                        _buildWordBadges(
                                          context,
                                          theme,
                                          activeQuestion,
                                          themeStyle,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: contentGap),
                                    // 紧凑环形倒计时
                                    _CountdownRingConsumer(
                                      totalTimeMs: data.currentTimeLimitMs,
                                      size: 56,
                                      themeStyle: themeStyle,
                                    ),
                                    SizedBox(height: contentGap),
                                    // 4 个选项按钮
                                    _buildOptionButtons(
                                      context,
                                      theme,
                                      data,
                                      activeQuestion,
                                      themeStyle,
                                    ),
                                    SizedBox(height: bottomSpacing),
                                  ],
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
                      final controller = ref.read(
                        sessionControllerProvider.notifier,
                      );
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
                                borderRadius: BorderRadius.circular(
                                  borderRadius,
                                ),
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
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
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
        // 精细化监听：过滤倒计时，仅在题目变动、状态迁移或用户交互时触发重绘
        ref.watch(
          sessionControllerProvider.select(
            (s) => (
              state: s.state,
              isPaused: s.isPaused,
              questionId: s.currentQuestion?.word.id,
              selectedOption: s.selectedOption,
              lastCorrect: s.lastCorrect,
              currentProgress: s.currentProgress,
              attemptsCount: s.attempts.length,
            ),
          ),
        );
        final currentSessionData = ref.read(sessionControllerProvider);
        final isPaused = currentSessionData.isPaused;
        final data = currentSessionData;
        final activeQuestion = data.currentQuestion ?? question;

        return SafeArea(
          child: Stack(
            children: [
              // 主要内容：顶部细进度条代替倒计时圆环；左右两栏等高，
              // 单词卡与第一个选项顶端对齐，按钮与最后一个选项底端对齐。
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 20, 32, 24),
                child: Column(
                  children: [
                    _CountdownBarConsumer(
                      totalTimeMs: data.currentTimeLimitMs,
                      themeStyle: themeStyle,
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          // 选项按可用高度平分，单个 76~136dp，间距 20dp。
                          const gap = 20.0;
                          final count = activeQuestion.options.length;
                          final height =
                              ((box.maxHeight - gap * (count - 1)) / count)
                                  .clamp(76.0, 136.0);
                          final needed = height * count + gap * (count - 1);
                          final options = _buildOptionButtons(
                            context,
                            theme,
                            data,
                            activeQuestion,
                            themeStyle,
                            optionHeight: height,
                            gap: gap,
                          );
                          final left = Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 单词卡撑满剩余高度，左栏与右侧选项区一样饱满。
                              Expanded(
                                child: _buildWordDisplay(
                                  context,
                                  theme,
                                  settings,
                                  activeQuestion,
                                  themeStyle,
                                  isTablet: true,
                                  expand: true,
                                ),
                              ),
                              const SizedBox(height: gap),
                              _buildProgressInfo(
                                context,
                                theme,
                                data,
                                themeStyle,
                              ),
                              const SizedBox(height: gap),
                              // 暂停与重置并排并拉开距离，避免误触重置。
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 32,
                                runSpacing: 20,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      final controller = ref.read(
                                        sessionControllerProvider.notifier,
                                      );
                                      debugPrint(
                                        'Tablet pause button tapped, isPaused=$isPaused, state=${currentSessionData.state}',
                                      );
                                      if (isPaused) {
                                        controller.resumeSession();
                                      } else {
                                        controller.pauseSession();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(
                                          borderRadius,
                                        ),
                                        border: Border.all(
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isPaused
                                                ? Icons.play_arrow
                                                : Icons.pause,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            isPaused ? '继续' : '暂停',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  color:
                                                      theme.colorScheme.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        _showResetConfirmDialog(context, ref),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          borderRadius,
                                        ),
                                        border: Border.all(
                                          color: Colors.red.withValues(
                                            alpha: 0.3,
                                          ),
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
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
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
                            ],
                          );
                          final row = Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 2, child: left),
                              const SizedBox(width: 32),
                              Expanded(flex: 3, child: options),
                            ],
                          );
                          // 高度不够（分屏等）时整体滚动，不挤压选项。
                          if (needed > box.maxHeight) {
                            return SingleChildScrollView(
                              child: SizedBox(
                                height: math.max(needed, 560),
                                child: row,
                              ),
                            );
                          }
                          return Center(
                            child: SizedBox(height: needed, child: row),
                          );
                        },
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
                      final controller = ref.read(
                        sessionControllerProvider.notifier,
                      );
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
        ref.invalidate(dailyHistorySummariesProvider);
        // 一轮已保存：后台推送到云端，另一台设备下次打开即可看到。
        ref.read(cloudSyncProvider.notifier).syncNow(quiet: true);

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
    bool expand = false,
  }) {
    if (themeStyle == ThemeStyle.digitalism) {
      return DigitalismCard(
        expand: expand,
        windowTitle: 'VOCABULARY // ${question.word.level.toUpperCase()}',
        backgroundColor: DigitalismTheme.surface,
        margin: EdgeInsets.zero,
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 32 : 16,
          vertical: isTablet ? 24 : 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              question.word.headword,
              style:
                  (isTablet
                          ? theme.textTheme.displayMedium
                          : theme.textTheme.headlineLarge)
                      ?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: DigitalismTheme.textPrimary,
                        fontSize: isTablet ? null : 28,
                      ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (question.word.pos.isNotEmpty) ...[
              SizedBox(height: isTablet ? 12 : 6),
              Text(
                question.word.pos,
                style:
                    (isTablet
                            ? theme.textTheme.titleMedium
                            : theme.textTheme.titleSmall)
                        ?.copyWith(
                          color: DigitalismTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w700,
                        ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

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
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32 : 16,
        vertical: isTablet ? 24 : 16,
      ),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: ThemeManager.needsBorder(themeStyle)
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
      ),
      alignment: expand ? Alignment.center : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            question.word.headword,
            style:
                (isTablet
                        ? theme.textTheme.displayMedium
                        : theme.textTheme.headlineLarge)
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: contentTextColor,
                      fontSize: isTablet ? null : 28,
                    ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (question.word.pos.isNotEmpty) ...[
            SizedBox(height: isTablet ? 12 : 4),
            Text(
              question.word.pos,
              style:
                  (isTablet
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.titleSmall)
                      ?.copyWith(
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
      runSpacing: 4,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 16 : 10,
            vertical: isTablet ? 8 : 4,
          ),
          decoration: BoxDecoration(
            color: levelBgColor,
            borderRadius: BorderRadius.circular(
              borderRadius > 6 ? 6 : borderRadius,
            ),
            border: isDark ? Border.all(color: borderColor, width: 1) : null,
          ),
          child: Text(
            question.word.level,
            style:
                (isTablet
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.bodySmall)
                    ?.copyWith(
                      color: levelTextColor,
                      fontWeight: FontWeight.w600,
                    ),
          ),
        ),
        if (question.word.majorPos.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 10,
              vertical: isTablet ? 8 : 4,
            ),
            decoration: BoxDecoration(
              color: posBgColor,
              borderRadius: BorderRadius.circular(
                borderRadius > 6 ? 6 : borderRadius,
              ),
              border: isDark ? Border.all(color: borderColor, width: 1) : null,
            ),
            child: Text(
              question.word.majorPos,
              style:
                  (isTablet
                          ? theme.textTheme.titleSmall
                          : theme.textTheme.bodySmall)
                      ?.copyWith(
                        color: posTextColor,
                        fontWeight: FontWeight.w600,
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
          if (sessionData.testGroupLabel.isNotEmpty) ...[
            Text(
              sessionData.testGroupLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
          ],
          LinearProgressIndicator(
            value: sessionData.testedProgressRatio,
            backgroundColor: progressBgColor,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
          const SizedBox(height: 8),
          Text(
            sessionData.testProgressLabel,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  /// [optionHeight] 不为空时（平板）每个选项固定高度、选项间留 [gap]，
  /// 文字放大，减少相邻选项误触。
  Widget _buildOptionButtons(
    BuildContext context,
    ThemeData theme,
    SessionData sessionData,
    Question question,
    ThemeStyle themeStyle, {
    double? optionHeight,
    double gap = 0,
  }) {
    final large = optionHeight != null;
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(question.options.length, (index) {
        final button = OptionButton(
          text: question.options[index],
          label: ['A', 'B', 'C', 'D'][index],
          padding: large
              ? const EdgeInsets.symmetric(horizontal: 24)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          margin: large
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          isSelected: sessionData.selectedOption == index,
          isCorrect:
              sessionData.state == SessionState.resolved &&
              index == question.correctIndex,
          isWrong:
              sessionData.state == SessionState.resolved &&
              sessionData.selectedOption == index &&
              index != question.correctIndex,
          isRevealed: sessionData.state == SessionState.resolved,
          themeStyle: themeStyle,
          onPressed: sessionData.state == SessionState.waiting
              ? () => ref
                    .read(sessionControllerProvider.notifier)
                    .selectOption(index)
              : null,
        );
        if (!large) return button;
        return Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : gap),
          child: SizedBox(height: optionHeight, child: button),
        );
      }),
    );
    if (!large) return column;
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(1.2)),
      child: column,
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
              // 重置仅操作本轮内存；整轮完成前不保存进度。
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

/// 局部倒计时渲染组件，将 50ms 高频更新完全隔离在此 Widget 内部，避免上层整树重绘
/// 平板倒计时：一条随剩余时间收短的细进度条，最后阶段转为提醒色。
class _CountdownBarConsumer extends ConsumerWidget {
  final int totalTimeMs;
  final ThemeStyle themeStyle;

  const _CountdownBarConsumer({
    required this.totalTimeMs,
    required this.themeStyle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final millisLeft = ref.watch(
      sessionControllerProvider.select((s) => s.millisLeft),
    );
    final theme = Theme.of(context);
    final fraction = totalTimeMs <= 0
        ? 0.0
        : (millisLeft / totalTimeMs).clamp(0.0, 1.0);
    final color = fraction > 0.5
        ? theme.colorScheme.primary
        : fraction > 0.25
        ? Colors.orange.shade700
        : theme.colorScheme.error;
    return Semantics(
      label: '剩余 ${(millisLeft / 1000).toStringAsFixed(1)} 秒',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 6,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: ThemeManager.getSecondaryTextColor(
                  themeStyle,
                ).withValues(alpha: 0.15),
              ),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownRingConsumer extends ConsumerWidget {
  final int totalTimeMs;
  final double size;
  final ThemeStyle themeStyle;

  const _CountdownRingConsumer({
    required this.totalTimeMs,
    required this.size,
    required this.themeStyle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final millisLeft = ref.watch(
      sessionControllerProvider.select((s) => s.millisLeft),
    );
    return CountdownRing(
      totalTimeMs: totalTimeMs,
      remainingTimeMs: millisLeft,
      size: size,
      themeStyle: themeStyle,
    );
  }
}
