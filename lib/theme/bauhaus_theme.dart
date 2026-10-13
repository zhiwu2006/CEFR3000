import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// 包豪斯主题 - 几何构成主义风格
///
/// 设计理念：
/// - 形式追随功能
/// - 纯粹几何美学（圆、方、三角）
/// - 三原色理论（红、蓝、黄）
/// - 硬边阴影，无模糊
/// - 粗边框，强对比
class BauhausTheme {
  // ============ 核心色彩 ============
  static const Color primaryRed = Color(0xFFD02020);
  static const Color primaryBlue = Color(0xFF1040C0);
  static const Color primaryYellow = Color(0xFFF0C020);
  static const Color background = Color(0xFFF0F0F0);
  static const Color foreground = Color(0xFF121212);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFFE0E0E0);

  // ============ 渐变色（用于背景区块） ============
  static const Color gradientStart = primaryBlue;
  static const Color gradientEnd = Color(0xFF0D3399);

  // ============ 语义色彩 ============
  static const Color correctColor = Color(0xFF2E7D32);
  static const Color wrongColor = primaryRed;
  static const Color warningColor = primaryYellow;

  // ============ 边框与阴影 ============
  static const double borderWidthThin = 2.0;
  static const double borderWidthThick = 4.0;

  /// 硬边阴影（包豪斯特色）
  static List<BoxShadow> get hardShadowSmall => [
    const BoxShadow(
      color: foreground,
      offset: Offset(3, 3),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get hardShadowMedium => [
    const BoxShadow(
      color: foreground,
      offset: Offset(6, 6),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get hardShadowLarge => [
    const BoxShadow(
      color: foreground,
      offset: Offset(8, 8),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  // ============ 主题数据 ============
  static ThemeData getTheme(BuildContext? context) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,

      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: primaryRed,
        tertiary: primaryYellow,
        surface: surface,
        error: wrongColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: foreground,
        onSurface: foreground,
        outline: foreground,
      ),

      // 应用栏
      appBarTheme: AppBarTheme(
        backgroundColor: foreground,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          color: Colors.white,
        ),
      ),

      // 卡片
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: const BorderSide(color: foreground, width: borderWidthThick),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // 按钮
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: foreground, width: borderWidthThin),
          ),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: surface,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          side: const BorderSide(color: foreground, width: borderWidthThin),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),

      // 文本主题
      textTheme: _buildTextTheme(),

      // 输入框
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: foreground, width: borderWidthThin),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: primaryBlue, width: borderWidthThick),
        ),
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),

      // 进度指示器
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryRed,
        linearTrackColor: muted,
      ),

      // 分割线
      dividerTheme: const DividerThemeData(
        color: foreground,
        thickness: borderWidthThin,
        space: 0,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primaryYellow,
        side: const BorderSide(color: foreground, width: borderWidthThin),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        labelStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),

      // Slider
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryBlue,
        inactiveTrackColor: muted,
        thumbColor: primaryRed,
        overlayColor: primaryRed.withValues(alpha: 0.2),
        trackHeight: 8,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryRed;
          return muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryRed.withValues(alpha: 0.5);
          }
          return foreground.withValues(alpha: 0.2);
        }),
      ),

      // Radio
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryBlue;
          return foreground;
        }),
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: foreground,
        ),
        subtitleTextStyle: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF666666),
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: foreground, width: borderWidthThick),
        ),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: foreground,
          letterSpacing: 1,
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: foreground,
        contentTextStyle: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return GoogleFonts.outfitTextTheme(
      const TextTheme(
        // 超大标题（单词显示）
        displayLarge: TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.w900,
          color: foreground,
          letterSpacing: -2,
          height: 0.9,
        ),
        displayMedium: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w900,
          color: foreground,
          letterSpacing: -1,
          height: 0.9,
        ),
        // 大标题
        headlineLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          color: foreground,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
        // 标题
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: foreground,
          letterSpacing: 0.5,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: foreground,
          letterSpacing: 0.5,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: foreground,
          letterSpacing: 0.5,
        ),
        // 正文
        bodyLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: foreground,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: foreground,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Color(0xFF666666),
          height: 1.3,
        ),
        // 标签
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: foreground,
          letterSpacing: 1.5,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foreground,
          letterSpacing: 1.5,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: foreground,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  // ============ 辅助方法 ============

  /// 获取按钮装饰（带硬边阴影）
  static BoxDecoration getButtonDecoration({
    Color? backgroundColor,
    bool isPressed = false,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? primaryRed,
      border: Border.all(color: foreground, width: borderWidthThin),
      boxShadow: isPressed ? null : hardShadowSmall,
    );
  }

  /// 获取卡片装饰
  static BoxDecoration getCardDecoration({Color? accentColor}) {
    return BoxDecoration(
      color: surface,
      border: Border.all(color: foreground, width: borderWidthThick),
      boxShadow: hardShadowLarge,
    );
  }

  /// 获取级别徽章颜色
  static Color getLevelBadgeColor(String level) {
    switch (level) {
      case 'A1':
        return primaryBlue;
      case 'A2':
        return primaryYellow;
      case 'B1':
        return primaryRed;
      case 'B2':
        return foreground;
      default:
        return muted;
    }
  }
}
