import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cloudflare_sync.dart';

/// 设置页「云同步」：填写 Cloudflare Worker 地址与同步密钥。
class CloudSyncPanel extends ConsumerStatefulWidget {
  const CloudSyncPanel({super.key});

  @override
  ConsumerState<CloudSyncPanel> createState() => _CloudSyncPanelState();
}

class _CloudSyncPanelState extends ConsumerState<CloudSyncPanel> {
  final _url = TextEditingController();
  final _token = TextEditingController();
  bool _showToken = false;

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
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
        '两台设备填同样的地址和密钥，学习记录就会自动同步：打开应用和每完成一轮时同步。'
        '设置和 AI 接口密钥不会上传。',
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
    ];

    if (!sync.configured) {
      children.addAll([
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Worker 地址',
            hintText: 'https://sync.example.com',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _token,
          obscureText: !_showToken,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: '同步密钥',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: _showToken ? '隐藏' : '显示',
              icon: Icon(_showToken ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showToken = !_showToken),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: sync.busy
              ? null
              : () => controller.connect(_url.text, _token.text),
          child: const Text('连接并同步'),
        ),
      ]);
    } else {
      children.addAll([
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cloud_done_outlined),
          title: Text(sync.url!.host),
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
              onPressed: sync.busy ? null : controller.disconnect,
              child: const Text('断开同步'),
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
