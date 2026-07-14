import 'package:flutter/material.dart';

/// Color tokens extracted directly from the Stitch "Clinical Clarity" design
/// system (see DESIGN.md in the original export). Deep teal = trust/medical
/// authority, warm coral = CTAs/progress, dusty aqua = secondary accents.
class AppColors {
  AppColors._();

  // Surfaces
  static const surface = Color(0xFFFBF8FF);
  static const surfaceDim = Color(0xFFD7D8F4);
  static const surfaceBright = Color(0xFFFBF8FF);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF4F2FF);
  static const surfaceContainer = Color(0xFFEDECFF);
  static const surfaceContainerHigh = Color(0xFFE6E6FF);
  static const surfaceContainerHighest = Color(0xFFE0E0FC);
  static const surfaceVariant = Color(0xFFE0E0FC);

  // On-surface
  static const onSurface = Color(0xFF181A2E);
  static const onSurfaceVariant = Color(0xFF3E494A);
  static const inverseSurface = Color(0xFF2D2F44);
  static const inverseOnSurface = Color(0xFFF1EFFF);
  static const outline = Color(0xFF6F797A);
  static const outlineVariant = Color(0xFFBEC8CA);

  // Primary — Deep Teal
  static const surfaceTint = Color(0xFF006972);
  static const primary = Color(0xFF00535B);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF006D77);
  static const onPrimaryContainer = Color(0xFF9BECF7);
  static const inversePrimary = Color(0xFF82D3DE);
  static const primaryFixed = Color(0xFF9FF0FB);
  static const primaryFixedDim = Color(0xFF82D3DE);
  static const onPrimaryFixed = Color(0xFF001F23);
  static const onPrimaryFixedVariant = Color(0xFF004F56);

  // Secondary — Warm Coral
  static const secondary = Color(0xFF8C4E35);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFFFAD8F);
  static const onSecondaryContainer = Color(0xFF793F27);
  static const secondaryFixed = Color(0xFFFFDBCE);
  static const secondaryFixedDim = Color(0xFFFFB59A);
  static const onSecondaryFixed = Color(0xFF380D00);
  static const onSecondaryFixedVariant = Color(0xFF6F3720);
  // Convenience alias used across screens for CTA highlights / progress bars
  static const coral = Color(0xFFFF7A54);

  // Tertiary — Dusty Aqua
  static const tertiary = Color(0xFF01544F);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFF286D67);
  static const onTertiaryContainer = Color(0xFFA9ECE4);
  static const tertiaryFixed = Color(0xFFACEFE7);
  static const tertiaryFixedDim = Color(0xFF90D3CB);
  static const onTertiaryFixed = Color(0xFF00201E);
  static const onTertiaryFixedVariant = Color(0xFF00504B);

  // Error
  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  // Background
  static const background = Color(0xFFFBF8FF);
  static const onBackground = Color(0xFF181A2E);

  // Elevation shadow tint (Level 1 / Level 2 per DESIGN.md)
  static const shadowTint = Color(0xFF2B2D42);
}
