import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'theme/theme_style.dart';
import 'theme/theme_manager.dart';
import 'session/base_providers.dart';
import 'screens/loading_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/test_screen.dart';
import 'screens/leech_words_screen.dart';
import 'screens/stats_screen.dart';
import 'session/session_models.dart';

void main() {
  runApp(
    const ProviderScope(
      child: VocabFlashTestApp(),
    ),
  );
}

/// 解析主题风格字符串
ThemeStyle _parseThemeStyle(String value) {
  switch (value) {
    case 'highContrast':
      return ThemeStyle.highContrast;
    case 'bauhaus':
      return ThemeStyle.bauhaus;
    case 'minimal':
      return ThemeStyle.minimal;
    case 'nature':
      return ThemeStyle.nature;
    case 'cyberpunk':
      return ThemeStyle.cyberpunk;
    default:
      return ThemeStyle.standard;
  }
}

class VocabFlashTestApp extends ConsumerWidget {
  const VocabFlashTestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final themeStyle = _parseThemeStyle(settings.themeStyle);
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
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: ThemeManager.getSurfaceColor(themeStyle),
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      
      // 起始页面
      initialRoute: '/',
      
      // 本地化配置（可扩展）
      locale: Locale(settings.uiLocale.split('-').first, settings.uiLocale.split('-').last),
      
      // 路由配置
      routes: {
        '/': (context) => const LoadingScreen(),
        '/loading': (context) => const LoadingScreen(),
        '/home': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/leech_words': (context) => const LeechWordsScreen(),
        '/stats': (context) => const StatsScreen(),
      },
      
      // 路由生成器，处理带参数的路由
      onGenerateRoute: (routeSettings) {
        if (routeSettings.name == '/test') {
          final config = routeSettings.arguments as SessionConfig?;
          if (config != null) {
            return MaterialPageRoute(
              builder: (context) => TestScreen(config: config),
            );
          }
        }
        return null;
      },
    );
  }
}
