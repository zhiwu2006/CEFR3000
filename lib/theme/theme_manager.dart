import 'package:flutter/material.dart';
import 'theme_style.dart';
import 'app_theme.dart';
import 'bauhaus_theme.dart';
import 'minimal_theme.dart';
import 'nature_theme.dart';
import 'cyberpunk_theme.dart';

/// 主题管理器 - 统一管理所有主题
class ThemeManager {
  /// 根据主题风格获取 ThemeData
  static ThemeData getTheme(ThemeStyle style, BuildContext? context) {
    switch (style) {
      case ThemeStyle.standard:
        return AppTheme.getLightTheme(context);
      case ThemeStyle.highContrast:
        return AppTheme.getHighContrastTheme(context);
      case ThemeStyle.bauhaus:
        return BauhausTheme.getTheme(context);
      case ThemeStyle.minimal:
        return MinimalTheme.getTheme(context);
      case ThemeStyle.nature:
        return NatureTheme.getTheme(context);
      case ThemeStyle.cyberpunk:
        return CyberpunkTheme.getTheme(context);
    }
  }

  /// 获取主题的渐变背景色
  static List<Color> getGradientColors(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.standard:
        return [AppTheme.gradientStart, AppTheme.gradientEnd];
      case ThemeStyle.highContrast:
        return [AppTheme.highContrastBackground, AppTheme.highContrastBackground];
      case ThemeStyle.bauhaus:
        return [BauhausTheme.primaryBlue, BauhausTheme.gradientEnd];
      case ThemeStyle.minimal:
        return [MinimalTheme.background, MinimalTheme.background];
      case ThemeStyle.nature:
        return [NatureTheme.gradientStart, NatureTheme.gradientEnd];
      case ThemeStyle.cyberpunk:
        return [CyberpunkTheme.background, CyberpunkTheme.card];
    }
  }

  /// 获取主题的主要背景色
  static Color getBackgroundColor(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.standard:
        return AppTheme.gradientStart;
      case ThemeStyle.highContrast:
        return AppTheme.highContrastBackground;
      case ThemeStyle.bauhaus:
        return BauhausTheme.background;
      case ThemeStyle.minimal:
        return MinimalTheme.background;
      case ThemeStyle.nature:
        return NatureTheme.background;
      case ThemeStyle.cyberpunk:
        return CyberpunkTheme.background;
    }
  }

  /// 获取主题的表面色
  static Color getSurfaceColor(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.standard:
        return Colors.white;
      case ThemeStyle.highContrast:
        return AppTheme.highContrastSurface;
      case ThemeStyle.bauhaus:
        return BauhausTheme.surface;
      case ThemeStyle.minimal:
        return MinimalTheme.surface;
      case ThemeStyle.nature:
        return NatureTheme.surface;
      case ThemeStyle.cyberpunk:
        return CyberpunkTheme.card;
    }
  }

  /// 获取主题的文字颜色
  static Color getTextColor(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.standard:
        return AppTheme.textPrimary;
      case ThemeStyle.highContrast:
        return AppTheme.highContrastText;
      case ThemeStyle.bauhaus:
        return BauhausTheme.foreground;
      case ThemeStyle.minimal:
        return MinimalTheme.textPrimary;
      case ThemeStyle.nature:
        return NatureTheme.textPrimary;
      case ThemeStyle.cyberpunk:
        return CyberpunkTheme.foreground;
    }
  }

  /// 获取顶部栏文字颜色（在渐变背景上）
  static Color getHeaderTextColor(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.standard:
      case ThemeStyle.nature:
      case ThemeStyle.bauhaus:
        return Colors.white;
      case ThemeStyle.highContrast:
      case ThemeStyle.cyberpunk:
        return Colors.white;
      case ThemeStyle.minimal:
        return MinimalTheme.textPrimary;
    }
  }

  /// 获取主题的正确答案颜色
  static Color getCorrectColor(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.standard:
        return AppTheme.correctColor;
      case ThemeStyle.highContrast:
        return AppTheme.highContrastCorrect;
      case ThemeStyle.bauhaus:
        return BauhausTheme.correctColor;
      case ThemeStyle.minimal:
        return MinimalTheme.correctColor;
      case ThemeStyle.nature:
        return NatureTheme.correctColor;
      case ThemeStyle.cyberpunk:
        return CyberpunkTheme.correctColor;
    }
  }

  /// 获取主题的错误答案颜色
  static Color getWrongColor(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.standard:
        return AppTheme.wrongColor;
      case ThemeStyle.highContrast:
        return AppTheme.highContrastWrong;
      case ThemeStyle.bauhaus:
        return BauhausTheme.wrongColor;
      case ThemeStyle.minimal:
        return MinimalTheme.wrongColor;
      case ThemeStyle.nature:
        return NatureTheme.wrongColor;
      case ThemeStyle.cyberpunk:
        return CyberpunkTheme.wrongColor;
    }
  }

  /// 获取主题的警告色
  static Color getWarningColor(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.standard:
        return AppTheme.warningColor;
      case ThemeStyle.highContrast:
        return const Color(0xFFFFD700);
      case ThemeStyle.bauhaus:
        return BauhausTheme.warningColor;
      case ThemeStyle.minimal:
        return const Color(0xFF9E9E9E);
      case ThemeStyle.nature:
        return NatureTheme.warningColor;
      case ThemeStyle.cyberpunk:
        return CyberpunkTheme.warningColor;
    }
  }

  /// 获取级别徽章颜色
  static Color getLevelBadgeColor(ThemeStyle style, String level) {
    switch (style) {
      case ThemeStyle.standard:
      case ThemeStyle.highContrast:
        return AppTheme.getLevelBadgeColor(level);
      case ThemeStyle.bauhaus:
        return BauhausTheme.getLevelBadgeColor(level);
      case ThemeStyle.minimal:
        return MinimalTheme.getLevelBadgeColor(level);
      case ThemeStyle.nature:
        return NatureTheme.getLevelBadgeColor(level);
      case ThemeStyle.cyberpunk:
        return CyberpunkTheme.getLevelBadgeColor(level);
    }
  }

  /// 判断是否为深色主题
  static bool isDarkTheme(ThemeStyle style) {
    return style == ThemeStyle.highContrast || style == ThemeStyle.cyberpunk;
  }

  /// 获取主题的主色调
  static Color getPrimaryColor(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.standard:
        return AppTheme.primaryColor;
      case ThemeStyle.highContrast:
        return AppTheme.highContrastCorrect;
      case ThemeStyle.bauhaus:
        return BauhausTheme.primaryBlue;
      case ThemeStyle.minimal:
        return MinimalTheme.textPrimary;
      case ThemeStyle.nature:
        return NatureTheme.primaryGreen;
      case ThemeStyle.cyberpunk:
        return CyberpunkTheme.neonGreen;
    }
  }

  /// 获取边框颜色
  static Color getBorderColor(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.standard:
        return Colors.grey.shade200;
      case ThemeStyle.highContrast:
        return AppTheme.highContrastText;
      case ThemeStyle.bauhaus:
        return BauhausTheme.foreground;
      case ThemeStyle.minimal:
        return MinimalTheme.border;
      case ThemeStyle.nature:
        return NatureTheme.border;
      case ThemeStyle.cyberpunk:
        return CyberpunkTheme.border;
    }
  }

  /// 获取边框宽度
  static double getBorderWidth(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.bauhaus:
        return 3.0;
      case ThemeStyle.highContrast:
        return 2.0;
      case ThemeStyle.cyberpunk:
        return 1.0;
      default:
        return 1.0;
    }
  }

  /// 获取圆角半径
  static double getBorderRadius(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.bauhaus:
        return 0.0; // 包豪斯使用直角
      case ThemeStyle.cyberpunk:
        return 4.0; // 赛博朋克使用小圆角
      case ThemeStyle.minimal:
        return 8.0;
      case ThemeStyle.nature:
        return 16.0;
      default:
        return 20.0;
    }
  }

  /// 获取大圆角半径（用于内容区域）
  static double getLargeBorderRadius(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.bauhaus:
        return 0.0;
      case ThemeStyle.cyberpunk:
        return 4.0;
      case ThemeStyle.minimal:
        return 16.0;
      default:
        return 30.0;
    }
  }

  /// 获取卡片阴影
  static List<BoxShadow> getCardShadow(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.bauhaus:
        return BauhausTheme.hardShadowMedium;
      case ThemeStyle.highContrast:
      case ThemeStyle.cyberpunk:
        return []; // 深色主题不使用阴影
      case ThemeStyle.minimal:
        return [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ];
      case ThemeStyle.nature:
        return [
          BoxShadow(
            color: NatureTheme.accentBrown.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ];
      default:
        return [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ];
    }
  }

  /// 获取卡片装饰
  static BoxDecoration getCardDecoration(ThemeStyle style, {bool elevated = false}) {
    final surfaceColor = getSurfaceColor(style);
    final borderColor = getBorderColor(style);
    final borderWidth = getBorderWidth(style);
    final borderRadius = getBorderRadius(style);
    final shadow = elevated ? getCardShadow(style) : <BoxShadow>[];

    return BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: borderWidth),
      boxShadow: shadow,
    );
  }

  /// 获取内容区域装饰（带大圆角）
  static BoxDecoration getContentAreaDecoration(ThemeStyle style) {
    final surfaceColor = getSurfaceColor(style);
    final borderRadius = getLargeBorderRadius(style);

    return BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(borderRadius),
        topRight: Radius.circular(borderRadius),
      ),
    );
  }

  /// 获取按钮装饰
  static BoxDecoration getButtonDecoration(
    ThemeStyle style, {
    required Color color,
    bool isOutlined = false,
  }) {
    final borderRadius = getBorderRadius(style);
    final borderWidth = getBorderWidth(style);

    if (style == ThemeStyle.bauhaus) {
      return BoxDecoration(
        color: isOutlined ? Colors.transparent : color,
        border: Border.all(color: BauhausTheme.foreground, width: borderWidth),
        boxShadow: isOutlined ? null : BauhausTheme.hardShadowSmall,
      );
    }

    if (style == ThemeStyle.cyberpunk) {
      return BoxDecoration(
        color: isOutlined ? Colors.transparent : color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: color, width: 2),
        boxShadow: isOutlined ? null : CyberpunkTheme.neonGlowSmall,
      );
    }

    return BoxDecoration(
      color: isOutlined ? Colors.transparent : color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: isOutlined ? Border.all(color: color, width: 1.5) : null,
    );
  }

  /// 获取图标容器装饰
  static BoxDecoration getIconContainerDecoration(ThemeStyle style, Color color) {
    final borderRadius = getBorderRadius(style);

    if (style == ThemeStyle.bauhaus) {
      return BoxDecoration(
        color: color,
        border: Border.all(color: BauhausTheme.foreground, width: 2),
      );
    }

    if (style == ThemeStyle.cyberpunk) {
      return BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      );
    }

    return BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(borderRadius * 0.75),
    );
  }

  /// 获取统计卡片装饰
  static BoxDecoration getStatCardDecoration(ThemeStyle style, Color color) {
    final borderRadius = getBorderRadius(style);
    final borderWidth = getBorderWidth(style);

    if (style == ThemeStyle.bauhaus) {
      return BoxDecoration(
        color: BauhausTheme.surface,
        border: Border.all(color: BauhausTheme.foreground, width: borderWidth),
        boxShadow: BauhausTheme.hardShadowSmall,
      );
    }

    if (style == ThemeStyle.cyberpunk) {
      return BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      );
    }

    return BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(borderRadius * 0.8),
      border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
    );
  }

  /// 获取进度条背景色
  static Color getProgressBackgroundColor(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.highContrast:
        return Colors.grey.shade800;
      case ThemeStyle.cyberpunk:
        return CyberpunkTheme.border;
      case ThemeStyle.bauhaus:
        return BauhausTheme.muted;
      default:
        return Colors.grey.shade200;
    }
  }

  /// 获取次要文字颜色
  static Color getSecondaryTextColor(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.standard:
        return AppTheme.textSecondary;
      case ThemeStyle.highContrast:
        return Colors.grey.shade400;
      case ThemeStyle.bauhaus:
        return const Color(0xFF666666);
      case ThemeStyle.minimal:
        return MinimalTheme.textSecondary;
      case ThemeStyle.nature:
        return NatureTheme.textSecondary;
      case ThemeStyle.cyberpunk:
        return CyberpunkTheme.mutedForeground;
    }
  }

  /// 是否需要边框（用于卡片等）
  static bool needsBorder(ThemeStyle style) {
    return style == ThemeStyle.bauhaus || 
           style == ThemeStyle.highContrast || 
           style == ThemeStyle.cyberpunk;
  }

  /// 获取状态栏样式
  static Brightness getStatusBarBrightness(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.highContrast:
      case ThemeStyle.cyberpunk:
        return Brightness.light;
      case ThemeStyle.minimal:
        return Brightness.dark;
      default:
        return Brightness.light;
    }
  }
}
