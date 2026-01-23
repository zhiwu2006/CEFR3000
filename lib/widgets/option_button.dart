import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/theme_style.dart';
import '../theme/theme_manager.dart';

/// 选项按钮组件
class OptionButton extends StatefulWidget {
  final String text; // 选项文本
  final String label; // 选项标签（A、B、C、D）
  final bool isSelected; // 是否被选中
  final bool isCorrect; // 是否为正确答案
  final bool isWrong; // 是否为错误答案
  final bool isRevealed; // 是否已显示答案
  final bool isEnabled; // 是否可点击
  final bool isHighContrast; // 高对比度模式（兼容旧代码）
  final ThemeStyle? themeStyle; // 主题风格
  final VoidCallback? onPressed; // 点击回调
  final Duration animationDuration; // 动画持续时间

  const OptionButton({
    super.key,
    required this.text,
    required this.label,
    this.isSelected = false,
    this.isCorrect = false,
    this.isWrong = false,
    this.isRevealed = false,
    this.isEnabled = true,
    this.isHighContrast = false,
    this.themeStyle,
    this.onPressed,
    this.animationDuration = const Duration(milliseconds: 200),
  });

  @override
  State<OptionButton> createState() => _OptionButtonState();
}

class _OptionButtonState extends State<OptionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.7,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(OptionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 当状态变化时触发反馈
    if (oldWidget.isSelected != widget.isSelected && widget.isSelected) {
      _triggerFeedback();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _triggerFeedback() {
    // 触觉反馈
    HapticFeedback.lightImpact();
    
    // 缩放动画
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
  }

  void _onTapCancel() {
    setState(() {
      _isPressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _isPressed ? 0.98 : _scaleAnimation.value,
          child: Opacity(
            opacity: widget.isEnabled ? _fadeAnimation.value : 0.5,
            child: _buildButton(context, theme),
          ),
        );
      },
    );
  }

  Widget _buildButton(BuildContext context, ThemeData theme) {
    final themeStyle = widget.themeStyle ?? 
        (widget.isHighContrast ? ThemeStyle.highContrast : ThemeStyle.standard);
    
    return GestureDetector(
      onTapDown: widget.isEnabled ? _onTapDown : null,
      onTapUp: widget.isEnabled ? _onTapUp : null,
      onTapCancel: widget.isEnabled ? _onTapCancel : null,
      onTap: widget.isEnabled ? widget.onPressed : null,
      child: AnimatedContainer(
        duration: AppTheme.normalAnimation,
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.paddingMedium,
          vertical: AppTheme.paddingSmall,
        ),
        decoration: _getButtonDecoration(themeStyle),
        child: Row(
          children: [
            // 选项标签
            _buildLabel(theme, themeStyle),
            const SizedBox(width: AppTheme.paddingMedium),
            // 选项文本
            Expanded(
              child: _buildText(theme, themeStyle),
            ),
            // 状态图标
            if (widget.isRevealed)
              _buildStatusIcon(themeStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(ThemeData theme, ThemeStyle themeStyle) {
    final isDark = ThemeManager.isDarkTheme(themeStyle);
    final correctColor = ThemeManager.getCorrectColor(themeStyle);
    final wrongColor = ThemeManager.getWrongColor(themeStyle);
    final borderWidth = ThemeManager.getBorderWidth(themeStyle);
    final borderColor = ThemeManager.getBorderColor(themeStyle);
    
    Color labelColor;
    Color labelBackground;
    
    if (isDark) {
      labelColor = widget.isSelected ? Colors.black : Colors.white;
      labelBackground = widget.isSelected 
          ? (widget.isCorrect ? correctColor : wrongColor)
          : ThemeManager.getSurfaceColor(themeStyle);
    } else {
      if (widget.isRevealed) {
        if (widget.isCorrect) {
          labelColor = Colors.white;
          labelBackground = correctColor;
        } else if (widget.isSelected && widget.isWrong) {
          labelColor = Colors.white;
          labelBackground = wrongColor;
        } else {
          labelColor = theme.colorScheme.onSurface;
          labelBackground = Colors.grey.shade200;
        }
      } else {
        labelColor = widget.isSelected ? Colors.white : theme.colorScheme.primary;
        labelBackground = widget.isSelected ? theme.colorScheme.primary : Colors.transparent;
      }
    }

    return AnimatedContainer(
      duration: AppTheme.fastAnimation,
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: labelBackground,
        border: Border.all(
          color: isDark ? borderColor : theme.colorScheme.primary,
          width: borderWidth,
        ),
        borderRadius: BorderRadius.circular(themeStyle == ThemeStyle.bauhaus ? 0 : 16),
      ),
      child: Center(
        child: Text(
          widget.label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: labelColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildText(ThemeData theme, ThemeStyle themeStyle) {
    final isDark = ThemeManager.isDarkTheme(themeStyle);
    final correctColor = ThemeManager.getCorrectColor(themeStyle);
    final wrongColor = ThemeManager.getWrongColor(themeStyle);
    final textColor = ThemeManager.getTextColor(themeStyle);
    
    Color finalTextColor;
    
    if (isDark) {
      finalTextColor = textColor;
    } else {
      if (widget.isRevealed && widget.isCorrect) {
        finalTextColor = correctColor;
      } else if (widget.isRevealed && widget.isSelected && widget.isWrong) {
        finalTextColor = wrongColor;
      } else {
        finalTextColor = theme.colorScheme.onSurface;
      }
    }

    return Text(
      widget.text,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: finalTextColor,
        fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
        height: 1.4,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildStatusIcon(ThemeStyle themeStyle) {
    final correctColor = ThemeManager.getCorrectColor(themeStyle);
    final wrongColor = ThemeManager.getWrongColor(themeStyle);
    
    if (widget.isCorrect) {
      return Icon(
        Icons.check_circle,
        color: correctColor,
        size: 24,
      );
    } else if (widget.isSelected && widget.isWrong) {
      return Icon(
        Icons.cancel,
        color: wrongColor,
        size: 24,
      );
    }
    return const SizedBox.shrink();
  }

  BoxDecoration _getButtonDecoration(ThemeStyle themeStyle) {
    final isDark = ThemeManager.isDarkTheme(themeStyle);
    final correctColor = ThemeManager.getCorrectColor(themeStyle);
    final wrongColor = ThemeManager.getWrongColor(themeStyle);
    final surfaceColor = ThemeManager.getSurfaceColor(themeStyle);
    final borderColor = ThemeManager.getBorderColor(themeStyle);
    final borderWidth = ThemeManager.getBorderWidth(themeStyle);
    final borderRadius = ThemeManager.getBorderRadius(themeStyle);
    final shadow = ThemeManager.getCardShadow(themeStyle);
    
    Color bgColor;
    Color finalBorderColor;
    
    if (widget.isRevealed && widget.isCorrect) {
      bgColor = correctColor.withValues(alpha: isDark ? 0.3 : 0.1);
      finalBorderColor = correctColor;
    } else if (widget.isRevealed && widget.isSelected && widget.isWrong) {
      bgColor = wrongColor.withValues(alpha: isDark ? 0.3 : 0.1);
      finalBorderColor = wrongColor;
    } else if (widget.isSelected) {
      bgColor = surfaceColor;
      finalBorderColor = borderColor;
    } else {
      bgColor = surfaceColor;
      finalBorderColor = borderColor.withValues(alpha: 0.5);
    }
    
    return BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: finalBorderColor,
        width: widget.isSelected ? borderWidth : borderWidth * 0.5,
      ),
      boxShadow: widget.isSelected && !widget.isRevealed ? shadow : null,
    );
  }
}

/// 选项按钮列表组件
class OptionButtonList extends StatelessWidget {
  final List<String> options;
  final int? selectedIndex;
  final int? correctIndex;
  final bool isRevealed;
  final bool isEnabled;
  final bool isHighContrast;
  final ThemeStyle? themeStyle;
  final Function(int index)? onOptionSelected;

  const OptionButtonList({
    super.key,
    required this.options,
    this.selectedIndex,
    this.correctIndex,
    this.isRevealed = false,
    this.isEnabled = true,
    this.isHighContrast = false,
    this.themeStyle,
    this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['A', 'B', 'C', 'D'];
    
    return Column(
      children: List.generate(
        options.length,
        (index) => OptionButton(
          text: options[index],
          label: labels[index],
          isSelected: selectedIndex == index,
          isCorrect: correctIndex == index,
          isWrong: selectedIndex == index && correctIndex != index,
          isRevealed: isRevealed,
          isEnabled: isEnabled,
          isHighContrast: isHighContrast,
          themeStyle: themeStyle,
          onPressed: () => onOptionSelected?.call(index),
        ),
      ),
    );
  }
}

/// 快速选择组件（键盘快捷键）
class QuickOptionSelector extends StatefulWidget {
  final Function(int index)? onOptionSelected;
  final bool isEnabled;

  const QuickOptionSelector({
    super.key,
    this.onOptionSelected,
    this.isEnabled = true,
  });

  @override
  State<QuickOptionSelector> createState() => _QuickOptionSelectorState();
}

class _QuickOptionSelectorState extends State<QuickOptionSelector> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 自动获取焦点以接收键盘事件
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Container(), // 不可见的组件
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.isEnabled) return KeyEventResult.ignored;
    
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyA:
        case LogicalKeyboardKey.digit1:
          widget.onOptionSelected?.call(0);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyB:
        case LogicalKeyboardKey.digit2:
          widget.onOptionSelected?.call(1);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyC:
        case LogicalKeyboardKey.digit3:
          widget.onOptionSelected?.call(2);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyD:
        case LogicalKeyboardKey.digit4:
          widget.onOptionSelected?.call(3);
          return KeyEventResult.handled;
      }
    }
    
    return KeyEventResult.ignored;
  }
}
