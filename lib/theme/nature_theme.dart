import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 自然主题 - 森林绿意风格
/// 
/// 设计理念：
/// - 自然色调，护眼舒适
/// - 有机形态，柔和曲线
/// - 温暖质感，木纹肌理
/// - 舒缓配色，减少视觉疲劳
class NatureTheme {
  // ============ 核心色彩 ============
  static const Color primaryGreen = Color(0xFF2D5A27);
  static const Color secondaryGreen = Color(0xFF4A7C43);
  static const Color accentBrown = Color(0xFF8B5E3C);
  static const Color background = Color(0xFFF5F2ED);
  static const Color surface = Color(0xFFFFFDF8);
  static const Color textPrimary = Color(0xFF2C3E2C);
  static const Color textSecondary = Color(0xFF5C6B5C);
  static const Color border = Color(0xFFD4CFC5);

  // ============ 渐变色 ============
  static const Color gradientStart = Color(0xFF3D6B35);
  static const Color gradientEnd = Color(0xFF2D5A27);

  // ============ 语义色彩 ============
  static const Color correctColor = Color(0xFF4CAF50);
  static const Color wrongColor = Color(0xFFD84315);
  static const Color warningColor = Color(0xFFE6A23C);

  // ============ 主题数据 ============
  static ThemeData getTheme(BuildContext? context) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      
      colorScheme: const ColorScheme.light(
        primary: primaryGreen,
        secondary: secondaryGreen,
        tertiary: accentBrown,
        surface: surface,
        error: wrongColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: Colors.white,
        onSurface: textPrimary,
        outline: border,
      ),

      // 应用栏 - 森林绿
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      // 卡片 - 温暖纸质感
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shadowColor: accentBrown.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // 按钮 - 有机圆角
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 2,
        shadowColor: primaryGreen.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          side: const BorderSide(color: primaryGreen, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // 文本主题
      textTheme: _buildTextTheme(),

      // 输入框
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // 进度指示器
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: secondaryGreen,
        linearTrackColor: border,
      ),

      // 分割线
      dividerTheme: DividerThemeData(
        color: border.withValues(alpha: 0.7),
        thickness: 1,
        space: 1,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: secondaryGreen.withValues(alpha: 0.15),
        side: BorderSide(color: border, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
      ),

      // Slider
      sliderTheme: SliderThemeData(
        activeTrackColor: secondaryGreen,
        inactiveTrackColor: border,
        thumbColor: primaryGreen,
        overlayColor: primaryGreen.withValues(alpha: 0.15),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryGreen;
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return secondaryGreen;
          return border;
        }),
      ),

      // Radio
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryGreen;
          return textSecondary;
        }),
      ),

      // ListTile
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryGreen,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return const TextTheme(
      displayLarge: TextStyle(
        fontSize: 52,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -1.5,
        height: 1.1,
      ),
      displayMedium: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -1,
        height: 1.1,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
    );
  }

  // ============ 辅助方法 ============
  
  static Color getLevelBadgeColor(String level) {
    switch (level) {
      case 'A1':
        return const Color(0xFF81C784); // 浅绿
      case 'A2':
        return const Color(0xFF4CAF50); // 绿
      case 'B1':
        return const Color(0xFFE6A23C); // 琥珀
      case 'B2':
        return const Color(0xFFD84315); // 深橙
      default:
        return textSecondary;
    }
  }
}
