import '../theme/theme_style.dart';

/// 主题工具类
class ThemeUtils {
  /// 解析主题风格字符串
  static ThemeStyle parseThemeStyle(String value) {
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

  /// 将主题风格转换为字符串
  static String themeStyleToString(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.standard:
        return 'standard';
      case ThemeStyle.highContrast:
        return 'highContrast';
      case ThemeStyle.bauhaus:
        return 'bauhaus';
      case ThemeStyle.minimal:
        return 'minimal';
      case ThemeStyle.nature:
        return 'nature';
      case ThemeStyle.cyberpunk:
        return 'cyberpunk';
    }
  }
}
