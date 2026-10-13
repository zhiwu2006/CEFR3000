import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Digitalism（数字波普·复古视窗）主题
///
/// 设计灵感源于 Instagram Stories Template - Digitalism：
/// - 温润复古纸张米色底色（#FAF4E7 / #FDF5E8）
/// - 纯正硬核浓黑线条（#121212，线宽 2.5px）
/// - 标志性复古视窗顶栏（日期 + 三圆点控制钮 ● ● ○）
/// - 零弥散纯黑硬阴影（Offset(4, 4), blur: 0）
/// - 柔和复古珊瑚蜜桃粉点缀（#FDB4A3）
/// - 高反差按压反显交互（类似 PARTY! 与 NAH. 按钮）
class DigitalismTheme {
  // ============ 核心色彩 ============
  /// 主画布底色：温润复古米纸色
  static const Color background = Color(0xFFFAF4E7);

  /// 表面色：干净纸白色
  static const Color surface = Color(0xFFFFFDF9);

  /// 卡片色：纸白
  static const Color card = Color(0xFFFFFDF9);

  /// 标志性机能点缀色：复古珊瑚蜜桃粉
  static const Color accentPeach = Color(0xFFFDB4A3);

  /// 主要文字与墨线色：高对比度浓墨黑
  static const Color textPrimary = Color(0xFF121212);

  /// 次要文字色：柔和复古深炭灰
  static const Color textSecondary = Color(0xFF55524E);

  /// 线条与边框色：浓墨黑
  static const Color border = Color(0xFF121212);

  /// 正确状态色：复古深绿
  static const Color correctColor = Color(0xFF1E6B38);

  /// 错误状态色：复古珊瑚赤红
  static const Color wrongColor = Color(0xFFE04838);

  /// 警示状态色：复古暖琥珀
  static const Color warningColor = Color(0xFFD97706);

  /// 进度条底槽色：微暖淡米色
  static const Color progressTrack = Color(0xFFEFE8D8);

  // ============ 尺寸与阴影规范 ============
  /// 标准硬核边框粗细
  static const double borderWidth = 2.5;

  /// 次级边框粗细
  static const double borderThin = 1.8;

  /// 卡片与视窗圆角
  static const double cardRadius = 12.0;

  /// 按钮圆角
  static const double buttonRadius = 10.0;

  /// 标签徽章圆角
  static const double badgeRadius = 6.0;

  /// 零弥散标准硬投影 (4px)
  static const List<BoxShadow> hardShadow = [
    BoxShadow(
      color: textPrimary,
      offset: Offset(4.0, 4.0),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  /// 零弥散次级按钮硬投影 (3.5px)
  static const List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: textPrimary,
      offset: Offset(3.5, 3.5),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  /// 零弥散微型硬投影 (2.0px)
  static const List<BoxShadow> smallShadow = [
    BoxShadow(
      color: textPrimary,
      offset: Offset(2.0, 2.0),
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
        primary: textPrimary,
        secondary: accentPeach,
        tertiary: Color(0xFF1D4ED8), // 核心功能三级强调色（深宝蓝）
        surface: surface,
        error: wrongColor,
        onPrimary: Colors.white,
        onSecondary: textPrimary,
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
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          color: textPrimary,
        ),
      ),

      // 卡片主题：2.5px黑边框与零模糊硬投影
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: border, width: borderWidth),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // 按钮主题：粗线框与硬投影
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: textPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
            side: const BorderSide(color: border, width: borderWidth),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),

      // 文本按钮
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textPrimary,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // 文本样式
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
      ),
    );
  }
}

/// 复古视窗顶栏组件 (Digitalism Window Header)
///
/// 还原原图顶部的视窗控制栏：
/// 左侧：日期 / 标题（默认动态当前日期如 `2026/09/15` 或自定义模块名）
/// 右侧：三圆点窗口控制器（● ● ○）
/// 底部：2.0px 实心分割线
class DigitalismWindowHeader extends StatelessWidget {
  final String? title;
  final bool showDivider;
  final Widget? trailing;

  const DigitalismWindowHeader({
    super.key,
    this.title,
    this.showDivider = true,
    this.trailing,
  });

  static String defaultDateTitle() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = title ?? defaultDateTitle();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // 左侧日期/标题
              Text(
                displayTitle.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: DigitalismTheme.textPrimary,
                ),
              ),
              const Spacer(),
              // 右侧组件或三圆点控制器
              if (trailing != null)
                trailing!
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: DigitalismTheme.textPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: DigitalismTheme.textPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: DigitalismTheme.textPrimary,
                          width: 1.8,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (showDivider)
          Container(
            height: 2.0,
            width: double.infinity,
            color: DigitalismTheme.border,
          ),
      ],
    );
  }
}

/// 数字波普视窗卡片 (Digitalism Window Card)
///
/// 具备 2.5px 墨黑粗边框、4px 硬阴影，并可选内嵌复古视窗顶栏
class DigitalismCard extends StatelessWidget {
  final Widget child;
  final String? windowTitle;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final Widget? trailingHeader;
  final VoidCallback? onTap;

  /// 撑满父级给定的高度，内容在剩余空间里居中。
  final bool expand;

  const DigitalismCard({
    super.key,
    required this.child,
    this.windowTitle,
    this.backgroundColor = DigitalismTheme.surface,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.borderRadius = DigitalismTheme.cardRadius,
    this.trailingHeader,
    this.onTap,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    Widget content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: DigitalismTheme.border,
          width: DigitalismTheme.borderWidth,
        ),
        boxShadow: DigitalismTheme.hardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 2.0),
        child: Column(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (windowTitle != null)
              DigitalismWindowHeader(
                title: windowTitle!,
                trailing: trailingHeader,
              ),
            expand ? Expanded(child: Center(child: body)) : body,
          ],
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }
    return content;
  }
}

/// 珊瑚粉弹窗通知栏 (Digitalism Banner Popup)
///
/// 还原原图中 `NEW YEAR, NEW YOU... [x]` 形式的副视窗
class DigitalismBanner extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry margin;

  const DigitalismBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.onClose,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: DigitalismTheme.accentPeach,
        borderRadius: BorderRadius.circular(DigitalismTheme.badgeRadius),
        border: Border.all(
          color: DigitalismTheme.border,
          width: DigitalismTheme.borderThin,
        ),
        boxShadow: DigitalismTheme.smallShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: DigitalismTheme.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: DigitalismTheme.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onClose != null)
            GestureDetector(
              onTap: onClose,
              child: Container(
                padding: const EdgeInsets.all(2),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: DigitalismTheme.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 物理按压反馈的数字波普按钮 (Digitalism Physical Button)
///
/// 还原原图中 `PARTY!` 与 `NAH.` 的按钮视觉，支持按压时投影收缩与物理沉降
class DigitalismButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isInverse; // 是否为实心黑底反显（如 NAH.）
  final Color? backgroundColor;
  final Color? textColor;
  final double width;
  final double height;
  final Widget? leading;
  final Widget? trailing;

  const DigitalismButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isInverse = false,
    this.backgroundColor,
    this.textColor,
    this.width = double.infinity,
    this.height = 48,
    this.leading,
    this.trailing,
  });

  @override
  State<DigitalismButton> createState() => _DigitalismButtonState();
}

class _DigitalismButtonState extends State<DigitalismButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bg =
        widget.backgroundColor ??
        (widget.isInverse
            ? DigitalismTheme.textPrimary
            : DigitalismTheme.surface);
    final fg =
        widget.textColor ??
        (widget.isInverse ? Colors.white : DigitalismTheme.textPrimary);

    const double offsetDist = 3.5;

    return GestureDetector(
      onTapDown: widget.onPressed != null
          ? (_) => setState(() => _isPressed = true)
          : null,
      onTapUp: widget.onPressed != null
          ? (_) {
              setState(() => _isPressed = false);
              widget.onPressed!();
            }
          : null,
      onTapCancel: () => setState(() => _isPressed = false),
      child: Transform.translate(
        offset: _isPressed ? const Offset(offsetDist, offsetDist) : Offset.zero,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(DigitalismTheme.buttonRadius),
            border: Border.all(
              color: DigitalismTheme.border,
              width: DigitalismTheme.borderWidth,
            ),
            boxShadow: _isPressed
                ? []
                : const [
                    BoxShadow(
                      color: DigitalismTheme.border,
                      offset: Offset(offsetDist, offsetDist),
                      blurRadius: 0,
                      spreadRadius: 0,
                    ),
                  ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.text.toUpperCase(),
                  style: TextStyle(
                    color: fg,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 8),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 同心靶心单选框 (Digitalism Concentric Radio)
///
/// 还原原图 `MY NEW YEAR RESOLUTIONS` 下的 `◎ ○ ○` 选项
class DigitalismConcentricRadio extends StatelessWidget {
  final bool isSelected;
  final double size;

  const DigitalismConcentricRadio({
    super.key,
    required this.isSelected,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(
          color: DigitalismTheme.border,
          width: DigitalismTheme.borderWidth,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: size * 0.45,
                height: size * 0.45,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: DigitalismTheme.textPrimary,
                ),
              ),
            )
          : null,
    );
  }
}
