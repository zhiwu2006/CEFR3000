import 'dart:io';
import 'package:flutter/material.dart';
import 'app_icon_generator.dart';

/// 生成应用图标的脚本
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('开始生成应用图标...');

  try {
    // 生成不同尺寸的图标
    final sizes = [512, 192, 144, 96, 72, 48, 36];

    for (final size in sizes) {
      debugPrint('生成 ${size}x$size 图标...');

      final iconData = await AppIconGenerator.generateIcon(
        size: size.toDouble(),
        primaryColor: const Color(0xFF1976D2),
        secondaryColor: const Color(0xFF0D47A1),
        accentColor: const Color(0xFFFFD54F),
      );

      // 保存到 assets 目录
      final file = File('assets/icon_${size}x$size.png');
      await file.create(recursive: true);
      await file.writeAsBytes(iconData);

      debugPrint('✓ 已保存: ${file.path}');
    }

    debugPrint('\n图标生成完成！');
    debugPrint('请将生成的图标文件复制到对应的平台目录：');
    debugPrint('- Android: android/app/src/main/res/mipmap-*/');
    debugPrint('- iOS: ios/Runner/Assets.xcassets/AppIcon.appiconset/');
  } catch (e) {
    debugPrint('生成图标时出错: $e');
  }
}
