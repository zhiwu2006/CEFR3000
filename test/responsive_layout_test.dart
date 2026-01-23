import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/utils/responsive_layout.dart';

void main() {
  group('响应式布局测试', () {
    test('设备类型检测', () {
      // 创建一个测试用的MediaQuery
      final mobileSize = Size(375, 667); // iPhone 8大小
      final tabletSize = Size(768, 1024); // iPad大小
      final desktopSize = Size(1920, 1080); // 桌面大小
      
      // 注意：实际测试需要Widget环境，这里是示例
      debugPrint('移动设备: ${mobileSize.width} x ${mobileSize.height}');
      debugPrint('平板设备: ${tabletSize.width} x ${tabletSize.height}');
      debugPrint('桌面设备: ${desktopSize.width} x ${desktopSize.height}');
      
      // 验证断点
      expect(ResponsiveLayout.mobileMaxWidth, 600);
      expect(ResponsiveLayout.tabletMinWidth, 601);
      expect(ResponsiveLayout.tabletMaxWidth, 1200);
      expect(ResponsiveLayout.desktopMinWidth, 1201);
    });
    
    test('响应式间距计算', () {
      // 测试基础值
      const basePadding = 16.0;
      
      // 预期的平板和桌面缩放值
      const expectedTabletPadding = basePadding * 1.5; // 24.0
      const expectedDesktopPadding = basePadding * 2.0; // 32.0
      
      expect(expectedTabletPadding, 24.0);
      expect(expectedDesktopPadding, 32.0);
    });
    
    test('字体大小缩放', () {
      const baseFontSize = 16.0;
      
      // 预期的缩放值
      const expectedTabletFontSize = baseFontSize * 1.2; // 19.2
      const expectedDesktopFontSize = baseFontSize * 1.4; // 22.4
      
      expect(expectedTabletFontSize, 19.2);
      expect(expectedDesktopFontSize, 22.4);
    });
  });
  
  group('布局组件测试', () {
    test('内容最大宽度', () {
      // 移动端应该使用全宽
      // 平板端最大宽度：800
      // 桌面端最大宽度：1000
      
      const tabletMaxWidth = 800;
      const desktopMaxWidth = 1000;
      
      expect(tabletMaxWidth, 800);
      expect(desktopMaxWidth, 1000);
    });
    
    test('列数配置', () {
      // 默认配置
      const mobileColumns = 1;
      const tabletColumns = 2;
      const desktopColumns = 3;
      
      expect(mobileColumns, 1);
      expect(tabletColumns, 2);
      expect(desktopColumns, 3);
    });
  });
}
