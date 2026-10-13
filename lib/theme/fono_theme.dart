import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Aeonik Fono 工业仪器工程美学主题
///
/// 设计灵感源于 Braun / Teenage Engineering / 瑞士现代工业仪表美学：
/// - 极具质感的低饱和哑光淡抹茶/鼠尾草米绿底色（#EBF0E4）
/// - 精密锐利的深石墨炭黑（#181B18）单像素工程线条与等宽排版
/// - 纯粹的几何线性轮廓卡片（零模糊阴影，极简工学）
/// - 标志性胶囊药丸（Capsule / Stadium）控件与技术网格/线框插画
class FonoTheme {
  // ============ 核心色彩 ============
  /// 主底色：淡鼠尾草米绿/哑光抹茶灰（低眩光护眼）
  static const Color background = Color(0xFFEBF0E4);

  /// 表面色：略带微亮的工学面板浅色
  static const Color surface = Color(0xFFF2F6ED);

  /// 卡片色：与底色融为一体，靠墨黑细线勾勒轮廓
  static const Color card = Color(0xFFEBF0E4);

  /// 主要文字色：极深石墨炭黑
  static const Color textPrimary = Color(0xFF141714);

  /// 次要文字色：工学说明文字中灰
  static const Color textSecondary = Color(0xFF5E665B);

  /// 边框与线条色：精密仪器线框黑
  static const Color border = Color(0xFF181B18);

  /// 渐变色：低眩光微渐变
  static const Color gradientStart = Color(0xFFEBF0E4);
  static const Color gradientEnd = Color(0xFFE5ECE0);

  /// 语义色：工学深墨绿（正确/激活）
  static const Color correctColor = Color(0xFF22512A);

  /// 语义色：工业警示陶土红（错误/失误）
  static const Color wrongColor = Color(0xFFB83226);

  /// 语义色：工业指示琥珀橙（勉强/注意）
  static const Color warningColor = Color(0xFFB37418);

  /// 边框与圆角规范
  static const double borderWidth = 1.3;
  static const double cardRadius = 18.0;
  static const double pillRadius = 999.0;

  // ============ 主题数据 ============
  static ThemeData getTheme(BuildContext? context) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,

      colorScheme: const ColorScheme.light(
        primary: textPrimary,
        secondary: textSecondary,
        surface: surface,
        error: wrongColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        outline: border,
      ),

      // 顶部应用栏
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: textPrimary,
        ),
      ),

      // 卡片主题：线框无弥散投影
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: border, width: borderWidth),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // 胶囊药丸按钮与线性按钮
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: textPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(pillRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: border, width: borderWidth),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(pillRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // 输入框
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          borderSide: const BorderSide(color: border, width: borderWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          borderSide: const BorderSide(color: border, width: borderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          borderSide: const BorderSide(
            color: textPrimary,
            width: borderWidth * 1.5,
          ),
        ),
      ),

      // 单选框与滑动开关
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return textPrimary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return textPrimary;
          return Colors.transparent;
        }),
        trackOutlineColor: WidgetStateProperty.all(border),
        trackOutlineWidth: WidgetStateProperty.all(borderWidth),
      ),

      dividerTheme: const DividerThemeData(
        color: border,
        thickness: borderWidth * 0.8,
        space: 24,
      ),

      textTheme: _buildTextTheme(),
    );
  }

  static TextTheme _buildTextTheme() {
    return const TextTheme(
      displayLarge: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        letterSpacing: -1.5,
        height: 1.1,
      ),
      displayMedium: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -1.0,
        height: 1.1,
      ),
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.6,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.4,
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: textSecondary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.3,
      ),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 0.5,
      ),
      labelMedium: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textSecondary,
        letterSpacing: 0.3,
      ),
      labelSmall: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: textSecondary,
        letterSpacing: 0.2,
      ),
    );
  }

  /// 等宽字母等级标签
  static Color getLevelBadgeColor(String level) {
    switch (level) {
      case 'A1':
      case 'A2':
        return const Color(0xFF22512A);
      case 'B1':
      case 'B2':
        return const Color(0xFF334E68);
      case 'C1':
      case 'C2':
        return const Color(0xFF6B46C1);
      default:
        return textPrimary;
    }
  }
}

// ============================================================================
// 工学视觉图元与背景组件 (Technical Line-Art & Grid Painters)
// ============================================================================

/// 工学技术背景：带有轻柔方格线与坐标十字标记（+）
class FonoGridBackground extends StatelessWidget {
  final Widget child;
  final bool showTicks;

  const FonoGridBackground({
    super.key,
    required this.child,
    this.showTicks = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FonoGridPainter(showTicks: showTicks),
      child: child,
    );
  }
}

class _FonoGridPainter extends CustomPainter {
  final bool showTicks;

  _FonoGridPainter({this.showTicks = true});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF181B18).withValues(alpha: 0.04)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const step = 32.0;

    // 垂直网格线
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    // 水平网格线
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    if (showTicks) {
      final tickPaint = Paint()
        ..color = const Color(0xFF181B18).withValues(alpha: 0.25)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      // 绘制四个角落的极简工学角标
      const len = 8.0;
      const pad = 12.0;
      // 左上
      canvas.drawLine(
        const Offset(pad, pad),
        const Offset(pad + len, pad),
        tickPaint,
      );
      canvas.drawLine(
        const Offset(pad, pad),
        const Offset(pad, pad + len),
        tickPaint,
      );
      // 右上
      canvas.drawLine(
        Offset(size.width - pad, pad),
        Offset(size.width - pad - len, pad),
        tickPaint,
      );
      canvas.drawLine(
        Offset(size.width - pad, pad),
        Offset(size.width - pad, pad + len),
        tickPaint,
      );
      // 左下
      canvas.drawLine(
        Offset(pad, size.height - pad),
        Offset(pad + len, size.height - pad),
        tickPaint,
      );
      canvas.drawLine(
        Offset(pad, size.height - pad),
        Offset(pad, size.height - pad - len),
        tickPaint,
      );
      // 右下
      canvas.drawLine(
        Offset(size.width - pad, size.height - pad),
        Offset(size.width - pad - len, size.height - pad),
        tickPaint,
      );
      canvas.drawLine(
        Offset(size.width - pad, size.height - pad),
        Offset(size.width - pad, size.height - pad - len),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FonoGridPainter oldDelegate) =>
      oldDelegate.showTicks != showTicks;
}

/// 暖气片折线弯管线框插画 (Serpentine Radiator Coil)
class FonoRadiatorWidget extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const FonoRadiatorWidget({
    super.key,
    this.width = 44,
    this.height = 54,
    this.color = FonoTheme.border,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _RadiatorPainter(color: color),
    );
  }
}

class _RadiatorPainter extends CustomPainter {
  final Color color;

  _RadiatorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    const loops = 5;
    final loopWidth = size.width / (loops + 1);
    final top = size.height * 0.08;
    final bottom = size.height * 0.92;
    final r = loopWidth * 0.45;

    double currentX = loopWidth * 0.5;
    path.moveTo(currentX, bottom);

    for (int i = 0; i < loops; i++) {
      // 向上垂直线
      path.lineTo(currentX, top + r);
      // 顶部半圆弧
      path.arcTo(
        Rect.fromCircle(center: Offset(currentX + r, top + r), radius: r),
        pi,
        pi,
        false,
      );
      currentX += r * 2;
      // 向下垂直线
      path.lineTo(currentX, bottom - r);
      if (i < loops - 1) {
        // 底部半圆弧连接到下一折
        path.arcTo(
          Rect.fromCircle(center: Offset(currentX + r, bottom - r), radius: r),
          0,
          pi,
          false,
        );
        currentX += r * 2;
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RadiatorPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 太阳能网格阵列线框插画 (Solar Panel Grid)
class FonoSolarPanelWidget extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const FonoSolarPanelWidget({
    super.key,
    this.width = 44,
    this.height = 54,
    this.color = FonoTheme.border,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _SolarGridPainter(color: color),
    );
  }
}

class _SolarGridPainter extends CustomPainter {
  final Color color;

  _SolarGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

    // 两块并排的太阳能板
    final panelWidth = (size.width - 6) / 2;
    for (int p = 0; p < 2; p++) {
      final left = p * (panelWidth + 6);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, panelWidth, size.height),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, borderPaint);

      // 横向划分 6 条细线
      final rowStep = size.height / 7;
      for (int r = 1; r < 7; r++) {
        canvas.drawLine(
          Offset(left, r * rowStep),
          Offset(left + panelWidth, r * rowStep),
          gridPaint,
        );
      }

      // 纵向居中划分
      canvas.drawLine(
        Offset(left + panelWidth / 2, 0),
        Offset(left + panelWidth / 2, size.height),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SolarGridPainter oldDelegate) =>
      oldDelegate.color != color;
}
