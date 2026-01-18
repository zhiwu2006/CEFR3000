import 'package:flutter/material.dart';

/// 响应式布局工具类
class ResponsiveLayout {
  // 屏幕断点
  static const double mobileMaxWidth = 600;      // 手机最大宽度
  static const double tabletMinWidth = 601;      // 平板最小宽度  
  static const double tabletMaxWidth = 1200;     // 平板最大宽度
  static const double desktopMinWidth = 1201;    // 桌面最小宽度

  /// 获取设备类型
  static DeviceType getDeviceType(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth <= mobileMaxWidth) {
      return DeviceType.mobile;
    } else if (screenWidth <= tabletMaxWidth) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  /// 是否为移动设备
  static bool isMobile(BuildContext context) {
    return getDeviceType(context) == DeviceType.mobile;
  }

  /// 是否为平板设备
  static bool isTablet(BuildContext context) {
    return getDeviceType(context) == DeviceType.tablet;
  }

  /// 是否为桌面设备
  static bool isDesktop(BuildContext context) {
    return getDeviceType(context) == DeviceType.desktop;
  }

  /// 是否为平板或桌面（大屏设备）
  static bool isLargeScreen(BuildContext context) {
    final deviceType = getDeviceType(context);
    return deviceType == DeviceType.tablet || deviceType == DeviceType.desktop;
  }

  /// 获取屏幕尺寸类别
  static ScreenSize getScreenSize(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;
    
    // 判断是否为横屏
    final isLandscape = width > height;
    
    if (width <= mobileMaxWidth) {
      return isLandscape ? ScreenSize.mobileLandscape : ScreenSize.mobilePortrait;
    } else if (width <= tabletMaxWidth) {
      return isLandscape ? ScreenSize.tabletLandscape : ScreenSize.tabletPortrait;
    } else {
      return ScreenSize.desktop;
    }
  }

  /// 获取适应屏幕尺寸的间距
  static double getSpacing(BuildContext context, {
    double mobile = 8.0,
    double tablet = 16.0,
    double desktop = 24.0,
  }) {
    switch (getDeviceType(context)) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet;
      case DeviceType.desktop:
        return desktop;
    }
  }

  /// 获取适应屏幕尺寸的字体大小
  static double getFontSize(BuildContext context, {
    required double baseFontSize,
    double mobileScale = 1.0,
    double tabletScale = 1.2,
    double desktopScale = 1.4,
  }) {
    switch (getDeviceType(context)) {
      case DeviceType.mobile:
        return baseFontSize * mobileScale;
      case DeviceType.tablet:
        return baseFontSize * tabletScale;
      case DeviceType.desktop:
        return baseFontSize * desktopScale;
    }
  }

  /// 获取内容区域最大宽度
  static double getContentMaxWidth(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.mobile:
        return MediaQuery.of(context).size.width;
      case DeviceType.tablet:
        return 800; // 平板内容区域最大宽度
      case DeviceType.desktop:
        return 1000; // 桌面内容区域最大宽度
    }
  }

  /// 获取列数（用于网格布局）
  static int getColumnCount(BuildContext context, {
    int mobileColumns = 1,
    int tabletColumns = 2,
    int desktopColumns = 3,
  }) {
    switch (getDeviceType(context)) {
      case DeviceType.mobile:
        return mobileColumns;
      case DeviceType.tablet:
        return tabletColumns;
      case DeviceType.desktop:
        return desktopColumns;
    }
  }

  /// 获取侧边栏宽度
  static double getSidebarWidth(BuildContext context) {
    if (isLargeScreen(context)) {
      return 300;
    }
    return 0;
  }

  /// 是否应该显示侧边栏
  static bool shouldShowSidebar(BuildContext context) {
    return isLargeScreen(context);
  }

  /// 获取卡片边距
  static EdgeInsets getCardMargin(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    } else {
      return const EdgeInsets.all(16);
    }
  }

  /// 获取页面内边距
  static EdgeInsets getPagePadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(24);
    } else {
      return const EdgeInsets.all(32);
    }
  }

  /// 构建响应式布局
  static Widget buildResponsive({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    switch (getDeviceType(context)) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }

  /// 构建双栏布局（适用于平板和桌面）
  static Widget buildTwoColumnLayout({
    required BuildContext context,
    required Widget left,
    required Widget right,
    double leftFlex = 1,
    double rightFlex = 1,
    double spacing = 16,
  }) {
    if (isMobile(context)) {
      // 移动设备使用单栏布局
      return Column(
        children: [
          left,
          SizedBox(height: spacing),
          right,
        ],
      );
    } else {
      // 平板和桌面使用双栏布局
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: leftFlex.round(), child: left),
          SizedBox(width: spacing),
          Expanded(flex: rightFlex.round(), child: right),
        ],
      );
    }
  }

  /// 构建居中容器（限制最大宽度）
  static Widget buildCenteredContainer({
    required BuildContext context,
    required Widget child,
    EdgeInsets? padding,
  }) {
    final maxWidth = getContentMaxWidth(context);
    final actualPadding = padding ?? getPagePadding(context);
    
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: actualPadding,
        child: child,
      ),
    );
  }
}

/// 设备类型枚举
enum DeviceType {
  mobile,
  tablet,
  desktop,
}

/// 屏幕尺寸枚举
enum ScreenSize {
  mobilePortrait,
  mobileLandscape,
  tabletPortrait,
  tabletLandscape,
  desktop,
}

/// 响应式组件基类
abstract class ResponsiveWidget extends StatelessWidget {
  const ResponsiveWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout.buildResponsive(
      context: context,
      mobile: buildMobile(context),
      tablet: buildTablet(context),
      desktop: buildDesktop(context),
    );
  }

  /// 构建移动端布局
  Widget buildMobile(BuildContext context);

  /// 构建平板布局（可选，默认使用移动端布局）
  Widget? buildTablet(BuildContext context) => null;

  /// 构建桌面布局（可选，默认使用平板布局）
  Widget? buildDesktop(BuildContext context) => null;
}