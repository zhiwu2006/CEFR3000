import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/fsrs_fit_controller.dart';

/// 设置页「记忆模型」：按自己的作答历史拟合的结果，以及是否已采用。
class MemoryModelPanel extends ConsumerWidget {
  const MemoryModelPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fit = ref.watch(fsrsFitProvider);
    final result = fit.result;
    final small = theme.textTheme.bodySmall;

    final lines = <Widget>[
      Text(
        '用你的作答历史拟合记忆模型，估计每个词现在还记得的概率。到期词多于今日题量时，'
        '先复习最可能忘掉的。到期日仍按原算法计算，两台设备同步后保持一致。',
        style: small,
      ),
      const SizedBox(height: 12),
    ];
    if (result == null) {
      lines.add(Text(fit.busy ? '正在拟合…' : '还没有拟合', style: small));
    } else {
      final d = result.fittedAt;
      lines.addAll([
        Text(
          result.improves ? '已采用：到期词按遗忘风险排序' : '拟合结果没有明显更准，暂按到期日排序',
          style: theme.textTheme.titleSmall?.copyWith(
            color: result.improves ? theme.colorScheme.primary : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${d.month}月${d.day}日拟合 · 训练 ${result.trainSamples} 次、'
          '检验 ${result.testSamples} 次跨天复习',
          style: small,
        ),
        Text(
          '预测误差（越低越准）：默认 ${result.defaultLoss.toStringAsFixed(3)}'
          ' → 拟合 ${result.fittedLoss.toStringAsFixed(3)}'
          ' · 只猜平均 ${result.baselineLoss.toStringAsFixed(3)}',
          style: small,
        ),
      ]);
    }
    if (fit.message != null) {
      lines.addAll([
        const SizedBox(height: 4),
        Text(
          fit.message!,
          style: small?.copyWith(color: theme.colorScheme.error),
        ),
      ]);
    }
    lines.addAll([
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: fit.busy
            ? const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : OutlinedButton.icon(
                onPressed: () => ref.read(fsrsFitProvider.notifier).refit(),
                icon: const Icon(Icons.auto_graph),
                label: const Text('重新拟合'),
              ),
      ),
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: lines,
    );
  }
}
