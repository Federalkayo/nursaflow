import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

/// Elevation shadows per DESIGN.md ("Tonal Layers + Ambient Shadows" —
/// mimics physical stacking of medical charts/notebooks).
class AppShadows {
  AppShadows._();

  static List<BoxShadow> level1 = [
    BoxShadow(
      color: AppColors.shadowTint.withValues(alpha: 0.05),
      offset: const Offset(0, 4),
      blurRadius: 12,
    ),
  ];

  static List<BoxShadow> level2 = [
    BoxShadow(
      color: AppColors.shadowTint.withValues(alpha: 0.10),
      offset: const Offset(0, 8),
      blurRadius: 24,
    ),
  ];
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      surfaceContainerLowest: AppColors.surfaceContainerLowest,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      inverseSurface: AppColors.inverseSurface,
      onInverseSurface: AppColors.inverseOnSurface,
      inversePrimary: AppColors.inversePrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkRipple.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface.withValues(alpha: 0.8),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        titleTextStyle: AppTextStyles.headlineMd(color: AppColors.primary),
      ),

      textTheme: TextTheme(
        displayLarge: AppTextStyles.display(),
        headlineLarge: AppTextStyles.headlineLg(),
        headlineMedium: AppTextStyles.headlineMd(),
        bodyLarge: AppTextStyles.bodyLg(),
        bodyMedium: AppTextStyles.bodyMd(),
        bodySmall: AppTextStyles.bodySm(),
        labelLarge: AppTextStyles.labelLg(),
        labelSmall: AppTextStyles.labelSm(),
      ),

      // Primary buttons: Deep Teal bg, white text, 12px radius, min 44pt touch target
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: AppTextStyles.labelLg(color: AppColors.onPrimary),
          elevation: 0,
        ),
      ),

      // Secondary buttons: teal tint (10% opacity) bg, teal text
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.primary.withValues(alpha: 0.10),
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: AppTextStyles.labelLg(color: AppColors.primary),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.labelLg(color: AppColors.primary),
        ),
      ),

      // Inputs: light gray bg, 12px rounding, 2px teal border on focus
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F3F5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        hintStyle: AppTextStyles.bodyMd(color: AppColors.outline),
        labelStyle: AppTextStyles.bodyMd(color: AppColors.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceContainerLow,
        labelStyle: AppTextStyles.bodySm(color: AppColors.primary),
        side: const BorderSide(color: AppColors.primary, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.outlineVariant,
        thickness: 0.5,
        space: 1,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.coral,
        linearTrackColor: AppColors.surfaceContainerHigh,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface.withValues(alpha: 0.85),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onSurfaceVariant,
        selectedLabelStyle: AppTextStyles.labelSm(color: AppColors.primary),
        unselectedLabelStyle:
            AppTextStyles.labelSm(color: AppColors.onSurfaceVariant),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  // Dark theme derived from the design system's "fixed-dim"/inverse tokens.
  // Screens were designed primarily for light mode (per Stitch export);
  // this keeps the app usable in dark mode without a full separate pass.
  static ThemeData get dark {
    final base = light;
    const colorScheme = ColorScheme.dark(
      primary: AppColors.primaryFixedDim,
      onPrimary: AppColors.onPrimaryFixed,
      secondary: AppColors.secondaryFixedDim,
      tertiary: AppColors.tertiaryFixedDim,
      surface: AppColors.inverseSurface,
      onSurface: AppColors.inverseOnSurface,
      error: AppColors.error,
      onError: AppColors.onError,
    );
    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.onSurface,
    );
  }
}
