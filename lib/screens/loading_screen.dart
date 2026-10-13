import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/sync/data/cloudflare_sync.dart';
import '../session/base_providers.dart';

/// 加载页面
class LoadingScreen extends ConsumerWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appReady = ref.watch(appReadyProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: appReady.when(
        data: (ready) {
          if (ready) {
            // 数据加载完成，导航到首页
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/home');
                // 启动后在后台同步一次；未登录或离线时安静跳过。
                ref.read(cloudSyncProvider.notifier).syncNow(quiet: true);
              }
            });
          }
          return _buildLoadingContent(context, theme, ready);
        },
        loading: () => _buildLoadingContent(context, theme, false),
        error: (error, stack) => _buildErrorContent(context, ref, theme, error),
      ),
    );
  }

  Widget _buildLoadingContent(
    BuildContext context,
    ThemeData theme,
    bool ready,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 应用图标/Logo
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.psychology, size: 50, color: Colors.white),
          ),

          const SizedBox(height: 32),

          // 应用标题
          Text(
            '词汇闪测',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),

          const SizedBox(height: 8),

          // 副标题
          Text(
            '2秒闪测 · 不熟回放 · 轻量SRS',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),

          const SizedBox(height: 48),

          // 加载指示器
          SizedBox(
            width: 200,
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: ready ? 1.0 : null,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.2,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  ready ? '初始化完成' : '正在准备学习数据...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorContent(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    Object error,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),

            const SizedBox(height: 32),

            Text(
              '加载失败',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              '请检查应用权限或重新启动应用',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              '错误信息：$error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: () {
                // 重新执行失败的数据初始化，而不是复用缓存的错误。
                ref.invalidate(coreInitializationProvider);
                ref.invalidate(initializationProvider);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoadingScreen()),
                );
              },
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
