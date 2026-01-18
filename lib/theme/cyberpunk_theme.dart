import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// 赛博朋克主题 - 霓虹故障风格
/// 
/// 设计理念：
/// - "High-Tech, Low-Life" 数字废土美学
/// - 深邃黑暗背景 + 霓虹发光效果
/// - 故障艺术（Glitch）视觉语言
/// - 终端/黑客界面风格
/// - 扫描线纹理 + 色差效果
class CyberpunkTheme {
  // ============ 核心色彩 ============
  /// 深渊黑（带微蓝底色）
  static const Color background = Color(0xFF0A0A0F);
  /// 前景文字（非纯白，减少刺眼）
  static const Color foreground = Color(0xFFE0E0E0);
  /// 卡片背景（深紫黑）
  static const Color card = Color(0xFF12121A);
  /// UI 镀铬/高亮背景
  static const Color muted = Color(0xFF1C1C2E);
  /// 次要文字
  static const Color mutedForeground = Color(0xFF6B7280);
  /// 边框
  static const Color border = Color(0xFF2A2A3A);
  /// 表面色
  static const Color surface = Color(0xFF12121A);

  // ============ 霓虹色彩 ============
  /// 主霓虹 - 电子绿（Matrix 风格）
  static const Color neonGreen = Color(0xFF00FF88);
  /// 次霓虹 - 热粉/品红
  static const Color neonMagenta = Color(0xFFFF00FF);
  /// 第三霓虹 - 电光蓝/青色
  static const Color neonCyan = Color(0xFF00D4FF);
  /// 警告霓虹 - 琥珀黄
  static const Color neonYellow = Color(0xFFFFD54F);

  // ============ 渐变色 ============
  static const Color gradientStart = Color(0xFF0A0A0F);
  static const Color gradientEnd = Color(0xFF12121A);

  // ============ 语义色彩 ============
  static const Color correctColor = neonGreen;
  static const Color wrongColor = Color(0xFFFF3366);
  static const Color warningColor = neonYellow;

  // ============ 发光效果 ============
  /// 小型霓虹发光
  static List<BoxShadow> get neonGlowSmall => [
    BoxShadow(
      color: neonGreen.withValues(alpha: 0.6),
      blurRadius: 3,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: neonGreen.withValues(alpha: 0.3),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];

  /// 中型霓虹发光
  static List<BoxShadow> get neonGlowMedium => [
    BoxShadow(
      color: neonGreen.withValues(alpha: 0.6),
      blurRadius: 5,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: neonGreen.withValues(alpha: 0.4),
      blurRadius: 10,
      spreadRadius: 0,
    ),
  ];

  /// 大型霓虹发光
  static List<BoxShadow> get neonGlowLarge => [
    BoxShadow(
      color: neonGreen.withValues(alpha: 0.6),
      blurRadius: 10,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: neonGreen.withValues(alpha: 0.4),
      blurRadius: 20,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: neonGreen.withValues(alpha: 0.2),
      blurRadius: 40,
      spreadRadius: 0,
    ),
  ];

  /// 品红霓虹发光
  static List<BoxShadow> get neonGlowMagenta => [
    BoxShadow(
      color: neonMagenta.withValues(alpha: 0.6),
      blurRadius: 5,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: neonMagenta.withValues(alpha: 0.4),
      blurRadius: 15,
      spreadRadius: 0,
    ),
  ];

  /// 青色霓虹发光
  static List<BoxShadow> get neonGlowCyan => [
    BoxShadow(
      color: neonCyan.withValues(alpha: 0.6),
      blurRadius: 5,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: neonCyan.withValues(alpha: 0.4),
      blurRadius: 15,
      spreadRadius: 0,
    ),
  ];

  // ============ 主题数据 ============
  static ThemeData getTheme(BuildContext? context) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      
      colorScheme: ColorScheme.dark(
        primary: neonGreen,
        secondary: neonMagenta,
        tertiary: neonCyan,
        surface: surface,
        error: wrongColor,
        onPrimary: background,
        onSecondary: background,
        onTertiary: background,
        onSurface: foreground,
        outline: border,
        surfaceContainerHighest: muted,
      ),

      // 应用栏 - 深黑 + 霓虹边框
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: neonGreen,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.orbitron(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 3,
          color: neonGreen,
        ),
      ),

      // 卡片 - 深色 + 霓虹边框
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // 按钮 - 霓虹边框风格
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonGreen,
          foregroundColor: background,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
          ),
          textStyle: GoogleFonts.shareTechMono(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: neonGreen,
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: BorderSide(color: neonGreen, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
          ),
          textStyle: GoogleFonts.shareTechMono(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: neonGreen,
          textStyle: GoogleFonts.shareTechMono(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ),

      // 文本主题
      textTheme: _buildTextTheme(),

      // 输入框 - 终端风格
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: neonGreen, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: border, width: 1),
        ),
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixStyle: GoogleFonts.jetBrainsMono(
          color: neonGreen,
          fontSize: 14,
        ),
        hintStyle: GoogleFonts.jetBrainsMono(
          color: mutedForeground,
          fontSize: 14,
        ),
      ),

      // 进度指示器 - 霓虹绿
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: neonGreen,
        linearTrackColor: border,
        circularTrackColor: border,
      ),

      // 分割线
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      // Chip - 霓虹边框
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: neonGreen.withValues(alpha: 0.2),
        side: BorderSide(color: border, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        labelStyle: GoogleFonts.shareTechMono(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foreground,
          letterSpacing: 1,
        ),
      ),

      // Slider - 霓虹风格
      sliderTheme: SliderThemeData(
        activeTrackColor: neonGreen,
        inactiveTrackColor: border,
        thumbColor: neonGreen,
        overlayColor: neonGreen.withValues(alpha: 0.2),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),

      // Switch - 霓虹开关
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return neonGreen;
          return mutedForeground;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return neonGreen.withValues(alpha: 0.4);
          return border;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return neonGreen;
          return border;
        }),
      ),

      // Radio - 霓虹单选
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return neonGreen;
          return mutedForeground;
        }),
      ),

      // Checkbox - 霓虹复选
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return neonGreen;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(background),
        side: BorderSide(color: border, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        titleTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: foreground,
        ),
        subtitleTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: mutedForeground,
        ),
        iconColor: neonGreen,
      ),

      // Dialog - 终端弹窗
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: neonGreen, width: 1),
        ),
        titleTextStyle: GoogleFonts.orbitron(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: neonGreen,
          letterSpacing: 2,
        ),
        contentTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          color: foreground,
        ),
      ),

      // SnackBar - 霓虹通知
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: GoogleFonts.jetBrainsMono(
          color: neonGreen,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: neonGreen, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // BottomSheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ),

      // FloatingActionButton
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: neonGreen,
        foregroundColor: background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Icon
      iconTheme: IconThemeData(
        color: foreground,
        size: 24,
      ),

      // TabBar
      tabBarTheme: TabBarThemeData(
        labelColor: neonGreen,
        unselectedLabelColor: mutedForeground,
        indicatorColor: neonGreen,
        labelStyle: GoogleFonts.shareTechMono(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
        unselectedLabelStyle: GoogleFonts.shareTechMono(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 2,
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      // 超大标题（单词显示）- Orbitron 机械风格
      displayLarge: GoogleFonts.orbitron(
        fontSize: 56,
        fontWeight: FontWeight.w900,
        color: foreground,
        letterSpacing: 4,
        height: 1.0,
      ),
      displayMedium: GoogleFonts.orbitron(
        fontSize: 44,
        fontWeight: FontWeight.w700,
        color: foreground,
        letterSpacing: 3,
        height: 1.0,
      ),
      // 大标题
      headlineLarge: GoogleFonts.orbitron(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: foreground,
        letterSpacing: 2,
      ),
      headlineMedium: GoogleFonts.orbitron(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: foreground,
        letterSpacing: 1.5,
      ),
      headlineSmall: GoogleFonts.orbitron(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: foreground,
        letterSpacing: 1,
      ),
      // 标题 - Share Tech Mono
      titleLarge: GoogleFonts.shareTechMono(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: foreground,
        letterSpacing: 1,
      ),
      titleMedium: GoogleFonts.shareTechMono(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: foreground,
        letterSpacing: 0.5,
      ),
      titleSmall: GoogleFonts.shareTechMono(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: foreground,
        letterSpacing: 0.5,
      ),
      // 正文 - JetBrains Mono 终端风格
      bodyLarge: GoogleFonts.jetBrainsMono(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: foreground,
        height: 1.6,
        letterSpacing: 0.5,
      ),
      bodyMedium: GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: foreground,
        height: 1.5,
        letterSpacing: 0.3,
      ),
      bodySmall: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: mutedForeground,
        height: 1.4,
        letterSpacing: 0.2,
      ),
      // 标签
      labelLarge: GoogleFonts.shareTechMono(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: foreground,
        letterSpacing: 2,
      ),
      labelMedium: GoogleFonts.shareTechMono(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: foreground,
        letterSpacing: 1.5,
      ),
      labelSmall: GoogleFonts.shareTechMono(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: mutedForeground,
        letterSpacing: 1.5,
      ),
    );
  }

  // ============ 辅助方法 ============
  
  /// 获取霓虹边框装饰
  static BoxDecoration getNeonBorderDecoration({
    Color? glowColor,
    double borderWidth = 1,
    double borderRadius = 4,
  }) {
    final color = glowColor ?? neonGreen;
    return BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: color, width: borderWidth),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.4),
          blurRadius: 8,
          spreadRadius: 0,
        ),
      ],
    );
  }

  /// 获取卡片装饰（带霓虹发光）
  static BoxDecoration getCardDecoration({bool withGlow = false}) {
    return BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: border, width: 1),
      boxShadow: withGlow ? neonGlowSmall : null,
    );
  }

  /// 获取终端风格装饰
  static BoxDecoration getTerminalDecoration() {
    return BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: neonGreen.withValues(alpha: 0.5), width: 1),
    );
  }

  /// 获取级别徽章颜色
  static Color getLevelBadgeColor(String level) {
    switch (level) {
      case 'A1':
        return neonGreen;
      case 'A2':
        return neonCyan;
      case 'B1':
        return neonYellow;
      case 'B2':
        return neonMagenta;
      default:
        return mutedForeground;
    }
  }

  /// 获取霓虹文字阴影（发光效果）
  static List<Shadow> getNeonTextShadow({Color? color}) {
    final glowColor = color ?? neonGreen;
    return [
      Shadow(
        color: glowColor.withValues(alpha: 0.8),
        blurRadius: 4,
      ),
      Shadow(
        color: glowColor.withValues(alpha: 0.5),
        blurRadius: 8,
      ),
      Shadow(
        color: glowColor.withValues(alpha: 0.3),
        blurRadius: 16,
      ),
    ];
  }

  /// 获取色差文字阴影（故障效果）
  static List<Shadow> getGlitchTextShadow() {
    return [
      Shadow(
        color: neonMagenta.withValues(alpha: 0.8),
        offset: const Offset(-2, 0),
        blurRadius: 0,
      ),
      Shadow(
        color: neonCyan.withValues(alpha: 0.8),
        offset: const Offset(2, 0),
        blurRadius: 0,
      ),
    ];
  }

  /// 扫描线装饰（用于覆盖层）
  static BoxDecoration getScanlineDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: List.generate(100, (index) {
          return index.isEven 
              ? Colors.transparent 
              : Colors.black.withValues(alpha: 0.05);
        }),
        stops: List.generate(100, (index) => index / 100),
      ),
    );
  }
}
