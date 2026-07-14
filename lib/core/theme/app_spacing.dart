/// Spacing + radius tokens from the Clinical Clarity design system.
/// Everything is built on an 8px base unit.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double base = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Mobile screen side margin
  static const double containerMargin = 20;

  /// Grid gutter (tablet/desktop)
  static const double gutter = 16;
}

class AppRadius {
  AppRadius._();

  static const double sm = 4; // 0.25rem
  static const double base = 8; // 0.5rem — small elements: buttons/inputs use 12
  static const double button = 12; // buttons & inputs
  static const double card = 20; // cards & modals
  static const double sheet = 24; // bottom sheets / large containers (top corners)
  static const double full = 9999; // pills / chips
}

/// Responsive breakpoints per DESIGN.md:
/// Mobile: single column, 20px margins
/// Tablet: 6-column grid, 24px margins
/// Desktop: 12-column grid, max 1200px, centered
class AppBreakpoints {
  AppBreakpoints._();

  static const double tablet = 600;
  static const double desktop = 1024;
  static const double maxContentWidth = 1200;
}
