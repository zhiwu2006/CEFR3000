import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_sync.dart';

/// 设置页「云同步」：邮箱验证码登录、立即同步、退出。
class CloudSyncPanel extends ConsumerStatefulWidget {
  const CloudSyncPanel({super.key});

  @override
  ConsumerState<CloudSyncPanel> createState() => _CloudSyncPanelState();
}

class _CloudSyncPanelState extends ConsumerState<CloudSyncPanel> {
  final _email = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sync = ref.watch(cloudSyncProvider);
    final controller = ref.read(cloudSyncProvider.notifier);
    final report = sync.lastReport;

    final children = <Widget>[
      Text(
        '登录后，学习记录会在手机和平板之间自动同步：打开应用和每完成一轮时同步。'
        '设置和 AI 接口密钥不会上传。',
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
    ];

    switch (sync.phase) {
      case CloudSyncPhase.signedOut:
        children.addAll([
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: '邮箱',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => controller.sendCode(_email.text),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: sync.busy
                ? null
                : () => controller.sendCode(_email.text),
            child: const Text('发送验证码'),
          ),
        ]);
      case CloudSyncPhase.codeSent:
        children.addAll([
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: const InputDecoration(
              labelText: '邮件中的验证码',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => controller.verifyCode(_code.text),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: sync.busy ? null : controller.changeEmail,
                child: const Text('换个邮箱'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: sync.busy
                    ? null
                    : () => controller.verifyCode(_code.text),
                child: const Text('登录'),
              ),
            ],
          ),
        ]);
      case CloudSyncPhase.signedIn:
        children.addAll([
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_done_outlined),
            title: Text(sync.email ?? '已登录'),
            subtitle: Text(
              report == null
                  ? '本次打开后尚未同步'
                  : '上次同步 ${_time(report.finishedAt)} · '
                        '上传 ${report.pushedEvents} 条作答 · '
                        '收到 ${report.merged.newEvents} 条',
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: sync.busy ? null : controller.signOut,
                child: const Text('退出登录'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: sync.busy ? null : () => controller.syncNow(),
                icon: const Icon(Icons.sync),
                label: const Text('立即同步'),
              ),
            ],
          ),
        ]);
    }

    if (sync.busy) {
      children.addAll([
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
      ]);
    }
    final message = sync.error ?? sync.message;
    if (message != null) {
      children.addAll([
        const SizedBox(height: 8),
        Text(
          message,
          style: theme.textTheme.bodySmall?.copyWith(
            color: sync.error != null ? theme.colorScheme.error : null,
          ),
        ),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
