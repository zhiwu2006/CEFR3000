import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/theme_style.dart';
import '../theme/theme_manager.dart';

/// 倒计时环形组件
class CountdownRing extends StatefulWidget {
  final int totalTimeMs; // 总时间（毫秒）
  final int remainingTimeMs; // 剩余时间（毫秒）
  final double size; // 环形大小
  final double strokeWidth; // 线条宽度
  final Color? progressColor; // 进度颜色
  final Color? backgroundColor; // 背景颜色
  final bool showText; // 是否显示文字
  final bool isHighContrast; // 高对比度模式（兼容旧代码）
  final ThemeStyle? themeStyle; // 主题风格

  const CountdownRing({
    super.key,
    required this.totalTimeMs,
    required this.remainingTimeMs,
    this.size = 80.0,
    this.strokeWidth = 6.0,
    this.progressColor,
    this.backgroundColor,
    this.showText = true,
    this.isHighContrast = false,
    this.themeStyle,
  });

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void didUpdateWidget(CountdownRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 当时间改变时触发缩放动画
    if (oldWidget.remainingTimeMs != widget.remainingTimeMs) {
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.totalTimeMs > 0 
        ? (widget.remainingTimeMs / widget.totalTimeMs).clamp(0.0, 1.0)
        : 0.0;
    
    final theme = Theme.of(context);
    final themeStyle = widget.themeStyle ?? 
        (widget.isHighContrast ? ThemeStyle.highContrast : ThemeStyle.standard);
    final isDark = ThemeManager.isDarkTheme(themeStyle);
    
    final progressColor = widget.progressColor ?? 
        _getProgressColor(progress, themeStyle);
    final bgColor = widget.backgroundColor ?? 
        ThemeManager.getProgressBackgroundColor(themeStyle);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 背景圆环
                CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _CirclePainter(
                    progress: 1.0,
                    color: bgColor,
                    strokeWidth: widget.strokeWidth,
                  ),
                ),
                // 进度圆环
                CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _CirclePainter(
                    progress: progress,
                    color: progressColor,
                    strokeWidth: widget.strokeWidth,
                  ),
                ),
                // 中间文字
                if (widget.showText)
                  _buildCenterText(context, theme, progress, themeStyle),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCenterText(BuildContext context, ThemeData theme, double progress, ThemeStyle themeStyle) {
    final remainingSeconds = (widget.remainingTimeMs / 1000).ceil();
    final totalSeconds = (widget.totalTimeMs / 1000).ceil();
    final isDark = ThemeManager.isDarkTheme(themeStyle);
    final textColor = ThemeManager.getTextColor(themeStyle);
    final correctColor = ThemeManager.getCorrectColor(themeStyle);
    final warningColor = ThemeManager.getWarningColor(themeStyle);
    final wrongColor = ThemeManager.getWrongColor(themeStyle);
    
    // 文字颜色根据剩余时间调整
    Color finalTextColor;
    if (isDark) {
      finalTextColor = textColor;
    } else {
      if (progress > 0.5) {
        finalTextColor = theme.colorScheme.onSurface;
      } else if (progress > 0.2) {
        finalTextColor = warningColor;
      } else {
        finalTextColor = wrongColor;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$remainingSeconds',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: finalTextColor,
            fontWeight: FontWeight.bold,
            fontSize: widget.size * 0.25,
          ),
        ),
        if (widget.size > 60) // 只在较大尺寸时显示
          Text(
            's',
            style: theme.textTheme.bodySmall?.copyWith(
              color: finalTextColor.withValues(alpha: 0.7),
              fontSize: widget.size * 0.1,
            ),
          ),
      ],
    );
  }

  Color _getProgressColor(double progress, ThemeStyle themeStyle) {
    final correctColor = ThemeManager.getCorrectColor(themeStyle);
    final warningColor = ThemeManager.getWarningColor(themeStyle);
    final wrongColor = ThemeManager.getWrongColor(themeStyle);
    
    if (progress > 0.6) return correctColor;
    if (progress > 0.3) return warningColor;
    return wrongColor;
  }
}

/// 圆环绘制器
class _CirclePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CirclePainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    // 绘制圆弧，从顶部开始（-π/2），顺时针方向
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_CirclePainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.color != color ||
           oldDelegate.strokeWidth != strokeWidth;
  }
}

/// 简化版倒计时环（仅显示进度）
class SimpleCountdownRing extends StatelessWidget {
  final double progress; // 0.0 到 1.0
  final double size;
  final double strokeWidth;
  final Color? color;

  const SimpleCountdownRing({
    super.key,
    required this.progress,
    this.size = 24.0,
    this.strokeWidth = 3.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = color ?? Theme.of(context).colorScheme.primary;
    
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        value: progress,
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
        backgroundColor: progressColor.withOpacity(0.2),
      ),
    );
  }
}

/// 脉冲倒计时环（紧急状态）
class PulsingCountdownRing extends StatefulWidget {
  final int totalTimeMs;
  final int remainingTimeMs;
  final double size;
  final double strokeWidth;

  const PulsingCountdownRing({
    super.key,
    required this.totalTimeMs,
    required this.remainingTimeMs,
    this.size = 80.0,
    this.strokeWidth = 6.0,
  });

  @override
  State<PulsingCountdownRing> createState() => _PulsingCountdownRingState();
}

class _PulsingCountdownRingState extends State<PulsingCountdownRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(PulsingCountdownRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final progress = widget.totalTimeMs > 0 
        ? widget.remainingTimeMs / widget.totalTimeMs
        : 0.0;
    
    // 当剩余时间少于30%时开始脉冲
    if (progress < 0.3 && progress > 0) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: CountdownRing(
            totalTimeMs: widget.totalTimeMs,
            remainingTimeMs: widget.remainingTimeMs,
            size: widget.size,
            strokeWidth: widget.strokeWidth,
            progressColor: Colors.red,
          ),
        );
      },
    );
  }
}