/// 主题风格枚举
enum ThemeStyle {
  standard,    // 标准主题（现有的深蓝渐变）
  highContrast, // 高对比度主题
  bauhaus,     // 包豪斯风格
  minimal,     // 极简风格
  nature,      // 自然风格
  cyberpunk,   // 赛博朋克风格
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

/// 所有可用主题的信息
const List<ThemeStyleInfo> availableThemes = [
  ThemeStyleInfo(
    style: ThemeStyle.standard,
    name: '标准',
    description: '深蓝渐变，现代简洁',
    icon: '🎨',
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
