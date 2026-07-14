import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Dual-font type scale: Manrope for headlines (confident, geometric),
/// Inter for body/labels (exceptional readability for dense medical text).
/// Values taken verbatim from the Stitch DESIGN.md typography spec.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle display({Color color = AppColors.onSurface}) =>
      GoogleFonts.manrope(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 41 / 34,
        letterSpacing: -0.02 * 34,
        color: color,
      );

  static TextStyle headlineLg({Color color = AppColors.onSurface}) =>
      GoogleFonts.manrope(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 34 / 28,
        letterSpacing: -0.01 * 28,
        color: color,
      );

  /// Used on mobile widths in place of headlineLg
  static TextStyle headlineLgMobile({Color color = AppColors.onSurface}) =>
      GoogleFonts.manrope(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 30 / 24,
        color: color,
      );

  static TextStyle headlineMd({Color color = AppColors.onSurface}) =>
      GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 28 / 22,
        color: color,
      );

  static TextStyle bodyLg({Color color = AppColors.onSurfaceVariant}) =>
      GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 24 / 17,
        color: color,
      );

  static TextStyle bodyMd({Color color = AppColors.onSurfaceVariant}) =>
      GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 21 / 15,
        color: color,
      );

  static TextStyle bodySm({Color color = AppColors.onSurfaceVariant}) =>
      GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 18 / 13,
        color: color,
      );

  static TextStyle labelLg({Color color = AppColors.onSurface}) =>
      GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 20 / 15,
        letterSpacing: 0.01 * 15,
        color: color,
      );

  static TextStyle labelSm({Color color = AppColors.onSurfaceVariant}) =>
      GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 16 / 11,
        letterSpacing: 0.03 * 11,
        color: color,
      );
}
