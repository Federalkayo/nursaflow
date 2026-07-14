import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

enum DeviceType { mobile, tablet, desktop }

class Responsive {
  Responsive._();

  static DeviceType deviceTypeOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppBreakpoints.desktop) return DeviceType.desktop;
    if (width >= AppBreakpoints.tablet) return DeviceType.tablet;
    return DeviceType.mobile;
  }

  static bool isMobile(BuildContext context) =>
      deviceTypeOf(context) == DeviceType.mobile;
  static bool isTablet(BuildContext context) =>
      deviceTypeOf(context) == DeviceType.tablet;
  static bool isDesktop(BuildContext context) =>
      deviceTypeOf(context) == DeviceType.desktop;

  /// Pick a value based on current breakpoint, falling back sensibly.
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final type = deviceTypeOf(context);
    switch (type) {
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.mobile:
        return mobile;
    }
  }

  /// Side margin per DESIGN.md: 20px mobile, 24px tablet/desktop.
  static double horizontalMargin(BuildContext context) => value(
        context,
        mobile: AppSpacing.containerMargin,
        tablet: AppSpacing.lg,
        desktop: AppSpacing.lg,
      );

  /// Number of grid columns for card grids: 1 mobile, 2 tablet, 3 desktop.
  static int gridColumns(BuildContext context) => value(
        context,
        mobile: 1,
        tablet: 2,
        desktop: 3,
      );
}
