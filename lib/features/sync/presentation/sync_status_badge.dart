import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cloudflare_sync.dart';

/// 首页的同步状态：上次同步时间或失败提示，点按立即同步。未配置同步时不显示。
class SyncStatusBadge extends ConsumerWidget {
  final Color? color;

  const SyncStatusBadge({super.key, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(cloudSyncProvider);
    if (!sync.configured) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final base = color ?? theme.colorScheme.onSurfaceVariant;
    final failed = sync.error != null && !sync.busy;
    final tint = failed ? theme.colorScheme.error : base;

    final String label;
    final Widget icon;
    if (sync.busy) {
      label = '同步中…';
      icon = SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: base),
      );
    } else if (failed) {
      label = '同步失败 · 点按重试';
      icon = Icon(Icons.cloud_off_outlined, size: 16, color: tint);
    } else {
      final at = sync.lastSyncedAt;
      label = at == null ? '尚未同步 · 点按同步' : '已同步 · ${describeSyncTime(at)}';
      icon = Icon(Icons.cloud_done_outlined, size: 16, color: tint);
    }

    return Tooltip(
      message: failed ? sync.error! : '点按立即同步',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: sync.busy
            ? null
            : () => ref.read(cloudSyncProvider.notifier).syncNow(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: tint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 今天只显示时刻，昨天写「昨天」，更早写日期。
  static String describeSyncTime(DateTime at, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final local = at.toLocal();
    final hm =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    final days = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime(local.year, local.month, local.day)).inDays;
    if (days <= 0) return '今天 $hm';
    if (days == 1) return '昨天 $hm';
    return '${local.month}月${local.day}日';
  }
}
