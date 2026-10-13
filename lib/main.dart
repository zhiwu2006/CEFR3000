import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme/theme_style.dart';
import 'theme/theme_manager.dart';
import 'session/base_providers.dart';
import 'screens/loading_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/test_screen.dart';
import 'screens/leech_words_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/daily_history_screen.dart';
import 'screens/active_recall_screen.dart';
import 'screens/production_recall_screen.dart';
import 'session/session_models.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const ProviderScope(child: VocabFlashTestApp()));
}

class VocabFlashTestApp extends ConsumerWidget {
  const VocabFlashTestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final themeStyle = ThemeStyle.fromString(settings.themeStyle);
    final isDark = ThemeManager.isDarkTheme(themeStyle);

    return MaterialApp(
      title: '词汇闪测',
      debugShowCheckedModeBanner: false,

      // 主题配置 - 使用新的主题管理器
      theme: ThemeManager.getTheme(themeStyle, context),

      // 系统UI覆盖样式
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarColor: ThemeManager.getSurfaceColor(themeStyle),
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },

      // 起始页面
      initialRoute: '/',

      // 本地化配置（可扩展）
      locale: Locale(
        settings.uiLocale.split('-').first,
        settings.uiLocale.split('-').last,
      ),

      // 路由配置
      routes: {
        '/': (context) => const LoadingScreen(),
        '/loading': (context) => const LoadingScreen(),
        '/home': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/leech_words': (context) => const LeechWordsScreen(),
        '/stats': (context) => const StatsScreen(),
        '/daily_history': (context) => const DailyHistoryScreen(),
      },

      // 路由生成器，处理带参数的路由
      onGenerateRoute: (routeSettings) {
        if (routeSettings.name == '/test') {
          final config =
              routeSettings.arguments as SessionConfig? ??
              SessionConfig.defaultConfig;
          return MaterialPageRoute(
            builder: (context) => TestScreen(config: config),
          );
        }
        if (routeSettings.name == '/recall') {
          final args = routeSettings.arguments as ActiveRecallArgs;
          return MaterialPageRoute(
            builder: (context) =>
                ActiveRecallScreen(config: args.config, wordIds: args.wordIds),
          );
        }
        if (routeSettings.name == '/production') {
          final args = routeSettings.arguments as ProductionRecallArgs;
          return MaterialPageRoute(
            builder: (context) => ProductionRecallScreen(
              config: args.config,
              wordIds: args.wordIds,
              allowLegacyFallback: args.allowLegacyFallback,
            ),
          );
        }
        return null;
      },
    );
  }
}
