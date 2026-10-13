import 'package:flutter/material.dart';
import '../features/lexicon/domain/production_hint_helper.dart';

/// 字母下划线/方格槽位输入组件。
///
/// 采用“隐形输入代理 + 展示层响应式投递”架构：
/// - 自动适配单词/短语（跳过空格与标点符号）；
/// - 支持系统软键盘、退格、大写字母规范化；
/// - 提示揭示字母（Hinted）固定锁定显示，支持用户盲打或纯补全模式；
/// - 符合 Digitalism 复古波普美学风格。
class WordSlotInput extends StatefulWidget {
  final String targetWord;
  final Set<int> revealedIndices;
  final bool enabled;
  final bool isSubmitted;
  final bool isCorrect;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const WordSlotInput({
    super.key,
    required this.targetWord,
    required this.revealedIndices,
    this.enabled = true,
    this.isSubmitted = false,
    this.isCorrect = false,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<WordSlotInput> createState() => WordSlotInputState();
}

class WordSlotInputState extends State<WordSlotInput>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _cursorBlinkController;

  @override
  void initState() {
    super.initState();
    _cursorBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _inputController.addListener(_handleInputChanged);
  }

  @override
  void didUpdateWidget(covariant WordSlotInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetWord != widget.targetWord) {
      _inputController.clear();
    }
  }

  @override
  void dispose() {
    _inputController.removeListener(_handleInputChanged);
    _inputController.dispose();
    _focusNode.dispose();
    _cursorBlinkController.dispose();
    super.dispose();
  }

  void requestFocus() {
    if (widget.enabled && !_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  void clear() {
    _inputController.clear();
  }

  /// 合成并计算当前所有槽位的最终字符映射。
  List<String?> _computeSlotCharacters() {
    final word = widget.targetWord;
    final result = List<String?>.filled(word.length, null);

    // 1. 特殊标点和非字母直接展示
    for (var i = 0; i < word.length; i++) {
      if (!ProductionHintHelper.isAlpha(word[i])) {
        result[i] = word[i];
      }
    }

    // 2. 提示揭示的字符锁定填入
    for (final index in widget.revealedIndices) {
      if (index >= 0 && index < word.length) {
        result[index] = word[index];
      }
    }

    // 3. 用户输入的字符映射到剩余可编辑的空槽中
    final rawInput = _inputController.text.trim();
    if (rawInput.isNotEmpty) {
      // 若用户输入的内容长度恰好匹配目标词且用户输入了全词，直接映射
      if (rawInput.length == word.length) {
        for (var i = 0; i < word.length; i++) {
          if (ProductionHintHelper.isAlpha(word[i])) {
            result[i] = rawInput[i];
          }
        }
      } else {
        // 顺序填入尚未被提示锁定的空白槽位
        var inputCharIdx = 0;
        for (var i = 0; i < word.length && inputCharIdx < rawInput.length; i++) {
          if (result[i] == null) {
            result[i] = rawInput[inputCharIdx];
            inputCharIdx++;
          }
        }
      }
    }

    return result;
  }

  /// 获取当前合成的完整单词答案
  String get currentAnswer {
    final slots = _computeSlotCharacters();
    final buffer = StringBuffer();
    for (var i = 0; i < widget.targetWord.length; i++) {
      buffer.write(slots[i] ?? '');
    }
    return buffer.toString();
  }

  void _handleInputChanged() {
    widget.onChanged?.call(currentAnswer);
    setState(() {});
  }

  int? _findActiveCursorIndex(List<String?> slots) {
    if (!widget.enabled || widget.isSubmitted) return null;
    for (var i = 0; i < widget.targetWord.length; i++) {
      if (ProductionHintHelper.isAlpha(widget.targetWord[i]) &&
          !widget.revealedIndices.contains(i) &&
          slots[i] == null) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slots = _computeSlotCharacters();
    final activeIndex = _findActiveCursorIndex(slots);

    // 计算槽位尺寸：长单词适当微缩
    final len = widget.targetWord.length;
    final slotWidth = len > 10 ? 32.0 : (len > 7 ? 38.0 : 44.0);
    final slotHeight = len > 10 ? 44.0 : 50.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: requestFocus,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 真正的隐藏输入框代理，捕获软键盘全量输入
          Offstage(
            offstage: true,
            child: TextField(
              controller: _inputController,
              focusNode: _focusNode,
              autofocus: true,
              enabled: widget.enabled && !widget.isSubmitted,
              keyboardType: TextInputType.visiblePassword, // 避免中文输入法干扰英文打字
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                widget.onSubmitted?.call(currentAnswer);
              },
            ),
          ),

          // 视觉槽位展示区（波普复古方格/下划线）
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 10,
            children: List.generate(widget.targetWord.length, (index) {
              final targetChar = widget.targetWord[index];
              final isAlpha = ProductionHintHelper.isAlpha(targetChar);

              // 非字母字符（空格/连字符）
              if (!isAlpha) {
                if (targetChar == ' ') {
                  return const SizedBox(width: 14);
                }
                return SizedBox(
                  width: 20,
                  height: slotHeight,
                  child: Center(
                    child: Text(
                      targetChar,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }

              final isHinted = widget.revealedIndices.contains(index);
              final char = slots[index];
              final isActive = activeIndex == index;

              // 边框和背景颜色计算
              Color borderColor;
              Color bgColor;
              Color textColor;

              if (widget.isSubmitted) {
                if (widget.isCorrect) {
                  borderColor = const Color(0xFF15803D); // 绿
                  bgColor = const Color(0xFFDCFCE7);
                  textColor = const Color(0xFF15803D);
                } else {
                  borderColor = theme.colorScheme.error;
                  bgColor = theme.colorScheme.errorContainer.withValues(alpha: 0.2);
                  textColor = theme.colorScheme.error;
                }
              } else if (isHinted) {
                borderColor = const Color(0xFF2563EB); // 提示蓝
                bgColor = const Color(0xFFEFF6FF);
                textColor = const Color(0xFF1D4ED8);
              } else if (isActive) {
                borderColor = theme.colorScheme.primary;
                bgColor = theme.colorScheme.primaryContainer.withValues(alpha: 0.15);
                textColor = theme.colorScheme.onSurface;
              } else if (char != null) {
                borderColor = theme.colorScheme.outline;
                bgColor = theme.colorScheme.surface;
                textColor = theme.colorScheme.onSurface;
              } else {
                borderColor = theme.colorScheme.outlineVariant;
                bgColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
                textColor = theme.colorScheme.onSurface;
              }

              return AnimatedBuilder(
                animation: _cursorBlinkController,
                builder: (context, child) {
                  final showCursorBar = isActive && _cursorBlinkController.value > 0.4;
                  return Container(
                    width: slotWidth,
                    height: slotHeight,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isActive
                            ? (showCursorBar ? borderColor : borderColor.withValues(alpha: 0.3))
                            : borderColor,
                        width: isActive || isHinted ? 2.0 : 1.5,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: borderColor.withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 下划线基准
                        Positioned(
                          bottom: 6,
                          child: Container(
                            width: slotWidth * 0.65,
                            height: 2,
                            decoration: BoxDecoration(
                              color: isHinted
                                  ? const Color(0xFF2563EB)
                                  : (char != null
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),

                        // 字符显示
                        if (char != null)
                          Text(
                            char,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              fontSize: len > 10 ? 20 : 24,
                            ),
                          )
                        else if (showCursorBar)
                          Container(
                            width: 2,
                            height: 22,
                            color: theme.colorScheme.primary,
                          ),

                        // 提示标识小徽标
                        if (isHinted && !widget.isSubmitted)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
