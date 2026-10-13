import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/responsive_layout.dart';
export 'fono_theme.dart';
export 'digitalism_theme.dart';

/// 应用主题配置
class AppTheme {
  // 主色调 - 深蓝色渐变风格
  static const Color primaryColor = Color(0xFF2E3A59); // 深蓝色
  static const Color secondaryColor = Color(0xFF4A5F7A); // 中蓝色

  // 渐变色
  static const Color gradientStart = Color(0xFF2E3A59); // 深蓝色
  static const Color gradientEnd = Color(0xFF4A5F7A); // 中蓝色

  // 语义色彩
  static const Color correctColor = Color(0xFF4CAF50); // 绿色 - 正确
  static const Color wrongColor = Color(0xFFF44336); // 红色 - 错误
  static const Color warningColor = Color(0xFFFF9800); // 橙色 - 警告

  // 背景色 - 渐变背景
  static const Color backgroundColor = Color(0xFF2E3A59);
  static const Color surfaceColor = Colors.white;
  static const Color cardColor = Colors.white;

  // 文字色彩
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);

  // 高对比度主题色彩
  static const Color highContrastBackground = Color(0xFF000000);
  static const Color highContrastSurface = Color(0xFF1E1E1E);
  static const Color highContrastText = Color(0xFFFFFFFF);
  static const Color highContrastCorrect = Color(0xFF00FF00);
  static const Color highContrastWrong = Color(0xFFFF0000);

  /// 标准主题
  static ThemeData getLightTheme(BuildContext? context) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),

      // 应用栏主题
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),

      // 卡片主题
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // 文本主题
      textTheme: _buildTextTheme(context),

      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),

      // 进度指示器主题
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: Colors.grey,
      ),

      // 分割线主题
      dividerTheme: const DividerThemeData(
        color: Colors.grey,
        thickness: 1,
        space: 16,
      ),

      // 底部导航栏主题
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  /// 高对比度主题
  static ThemeData getHighContrastTheme(BuildContext? context) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: highContrastBackground,

      colorScheme: const ColorScheme.dark(
        primary: highContrastCorrect,
        secondary: highContrastWrong,
        surface: highContrastSurface,
        onPrimary: highContrastBackground,
        onSecondary: highContrastBackground,
        onSurface: highContrastText,
      ),

      // 应用栏主题
      appBarTheme: const AppBarTheme(
        backgroundColor: highContrastSurface,
        foregroundColor: highContrastText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: highContrastText,
        ),
      ),

      // 卡片主题
      cardTheme: CardThemeData(
        color: highContrastSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: highContrastText, width: 2),
        ),
      ),

      // 文本主题
      textTheme: _buildHighContrastTextTheme(context),
    );
  }

  /// 难度徽章颜色
  static Color getLevelBadgeColor(String level) {
    switch (level) {
      case 'A1':
        return const Color(0xFF4CAF50); // 绿色
      case 'A2':
        return const Color(0xFF2196F3); // 蓝色
      case 'B1':
        return const Color(0xFFFF9800); // 橙色
      case 'B2':
        return const Color(0xFFF44336); // 红色
      default:
        return Colors.grey;
    }
  }

  /// 动画持续时间
  static const Duration fastAnimation = Duration(milliseconds: 150);
  static const Duration normalAnimation = Duration(milliseconds: 250);

  /// 边距和间距
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  /// 响应式边距
  static double getResponsivePadding(BuildContext context, double basePadding) {
    return ResponsiveLayout.getSpacing(
      context,
      mobile: basePadding,
      tablet: basePadding * 1.5,
      desktop: basePadding * 2.0,
    );
  }

  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  /// 构建响应式文本主题
  static TextTheme _buildTextTheme(BuildContext? context) {
    final isTablet = context != null && ResponsiveLayout.isTablet(context);
    final isDesktop = context != null && ResponsiveLayout.isDesktop(context);

    double headlineLargeSize = 32;
    double headlineMediumSize = 24;
    double headlineSmallSize = 20;
    double bodyLargeSize = 16;
    double bodyMediumSize = 14;
    double bodySmallSize = 12;
    double labelLargeSize = 14;

    if (isTablet) {
      headlineLargeSize = 40;
      headlineMediumSize = 30;
      headlineSmallSize = 24;
      bodyLargeSize = 18;
      bodyMediumSize = 16;
      bodySmallSize = 14;
      labelLargeSize = 16;
    } else if (isDesktop) {
      headlineLargeSize = 48;
      headlineMediumSize = 36;
      headlineSmallSize = 28;
      bodyLargeSize = 20;
      bodyMediumSize = 18;
      bodySmallSize = 16;
      labelLargeSize = 18;
    }

    return TextTheme(
      // 大标题（单词显示）
      headlineLarge: TextStyle(
        fontSize: headlineLargeSize,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        height: 1.2,
      ),
      // 中标题
      headlineMedium: TextStyle(
        fontSize: headlineMediumSize,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      // 小标题
      headlineSmall: TextStyle(
        fontSize: headlineSmallSize,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      // 正文大
      bodyLarge: TextStyle(
        fontSize: bodyLargeSize,
        color: textPrimary,
        height: 1.5,
      ),
      // 正文中
      bodyMedium: TextStyle(
        fontSize: bodyMediumSize,
        color: textPrimary,
        height: 1.4,
      ),
      // 正文小
      bodySmall: TextStyle(
        fontSize: bodySmallSize,
        color: textSecondary,
        height: 1.3,
      ),
      // 标签
      labelLarge: TextStyle(
        fontSize: labelLargeSize,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
    );
  }

  /// 构建高对比度响应式文本主题
  static TextTheme _buildHighContrastTextTheme(BuildContext? context) {
    final isTablet = context != null && ResponsiveLayout.isTablet(context);
    final isDesktop = context != null && ResponsiveLayout.isDesktop(context);

    double headlineLargeSize = 32;
    double headlineMediumSize = 24;
    double bodyLargeSize = 18;
    double bodyMediumSize = 16;
    double labelLargeSize = 16;

    if (isTablet) {
      headlineLargeSize = 40;
      headlineMediumSize = 30;
      bodyLargeSize = 20;
      bodyMediumSize = 18;
      labelLargeSize = 18;
    } else if (isDesktop) {
      headlineLargeSize = 48;
      headlineMediumSize = 36;
      bodyLargeSize = 22;
      bodyMediumSize = 20;
      labelLargeSize = 20;
    }

    return TextTheme(
      headlineLarge: TextStyle(
        fontSize: headlineLargeSize,
        fontWeight: FontWeight.bold,
        color: highContrastText,
        height: 1.2,
      ),
      headlineMedium: TextStyle(
        fontSize: headlineMediumSize,
        fontWeight: FontWeight.w600,
        color: highContrastText,
      ),
      bodyLarge: TextStyle(
        fontSize: bodyLargeSize,
        color: highContrastText,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: bodyMediumSize,
        color: highContrastText,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontSize: labelLargeSize,
        fontWeight: FontWeight.w500,
        color: highContrastText,
      ),
    );
  }
}
