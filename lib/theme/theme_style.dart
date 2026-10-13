/// 主题风格枚举
enum ThemeStyle {
  standard, // 标准主题（现有的深蓝渐变）
  highContrast, // 高对比度主题
  bauhaus, // 包豪斯风格
  minimal, // 极简风格
  nature, // 自然风格
  cyberpunk, // 赛博朋克风格
  fono, // Aeonik Fono 工业仪器工程美学
  digitalism // Digitalism 数字波普·复古视窗风格
  ;

  /// 从字符串解析主题风格，无效值返回 standard
  static ThemeStyle fromString(String value) {
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
      case 'fono':
      case 'aeonik':
      case 'aeonikFono':
        return ThemeStyle.fono;
      case 'standard':
        return ThemeStyle.standard;
      default:
        return ThemeStyle.digitalism;
    }
  }
}

/// 主题风格元数据
class ThemeStyleInfo {
  final ThemeStyle style;
  final String name;
  final String description;
  final String icon;

  const ThemeStyleInfo({
    required this.style,
    required this.name,
    required this.description,
    required this.icon,
  });
}

/// 所有可用主题的信息（Digitalism 为系统默认主题）
const List<ThemeStyleInfo> availableThemes = [
  ThemeStyleInfo(
    style: ThemeStyle.digitalism,
    name: 'Digitalism',
    description: '复古视窗，硬核黑线，数字波普（默认）',
    icon: '🪟',
  ),
  ThemeStyleInfo(
    style: ThemeStyle.standard,
    name: '标准',
    description: '深蓝渐变，现代简洁',
    icon: '🎨',
  ),
  ThemeStyleInfo(
    style: ThemeStyle.fono,
    name: 'Aeonik Fono',
    description: '精密仪器，工学线条，等宽质感',
    icon: '📟',
  ),
  ThemeStyleInfo(
    style: ThemeStyle.highContrast,
    name: '高对比度',
    description: '黑白分明，视觉无障碍',
    icon: '◐',
  ),
  ThemeStyleInfo(
    style: ThemeStyle.bauhaus,
    name: '包豪斯',
    description: '几何构成，三原色',
    icon: '▲',
  ),
  ThemeStyleInfo(
    style: ThemeStyle.minimal,
    name: '极简',
    description: '纯净留白，专注内容',
    icon: '○',
  ),
  ThemeStyleInfo(
    style: ThemeStyle.nature,
    name: '自然',
    description: '森林绿意，护眼舒适',
    icon: '🌿',
  ),
  ThemeStyleInfo(
    style: ThemeStyle.cyberpunk,
    name: '赛博朋克',
    description: '霓虹故障，数字废土',
    icon: '⚡',
  ),
];
