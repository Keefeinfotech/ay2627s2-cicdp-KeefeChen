import 'package:flutter/material.dart';

/// Auxilia's central colour system.
///
/// Deep Navy is the primary brand colour. Clear Blue and Teal are supporting
/// accents only; surfaces stay white or soft grey so the navy remains dominant.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Official palette
  // ---------------------------------------------------------------------------

  /// Primary brand colour used for headers, primary actions and selected states.
  static const Color deepNavy = Color(0xFF243B53);

  /// Secondary accent for interactive highlights and links.
  static const Color clearBlue = Color(0xFF2F80ED);

  /// Main application background.
  static const Color softGrey = Color(0xFFF5F7FA);

  /// Cards and content surfaces.
  static const Color white = Color(0xFFFFFFFF);

  /// Success and positive feedback.
  static const Color teal = Color(0xFF16A085);

  /// Main body text.
  static const Color darkText = Color(0xFF1F2937);

  /// Secondary text and captions.
  static const Color mutedText = Color(0xFF64748B);

  /// Dividers and card borders.
  static const Color borderGrey = Color(0xFFE2E8F0);

  /// Errors and destructive actions.
  static const Color errorRed = Color(0xFFDC2626);

  /// Warnings and attention states.
  static const Color warningAmber = Color(0xFFD97706);

  // ---------------------------------------------------------------------------
  // Derived tints and shades
  // ---------------------------------------------------------------------------

  /// A darker navy used at the end of brand gradients.
  static const Color navyDeep = Color(0xFF1B2E42);

  /// A lighter navy for gradients and hover states.
  static const Color navyLight = Color(0xFF34506C);

  /// Very light navy tint for selected rows and icon tiles.
  static const Color navyTint = Color(0xFFE9EFF5);

  /// Light blue tint for informational surfaces.
  static const Color blueTint = Color(0xFFEAF2FD);

  /// Light teal tint for success surfaces.
  static const Color tealTint = Color(0xFFE7F6F2);

  /// Light amber tint for warning surfaces.
  static const Color warningTint = Color(0xFFFEF3C7);

  /// Light red tint for error surfaces.
  static const Color errorTint = Color(0xFFFEE2E2);

  /// Accessible darker blue for text links on light surfaces.
  static const Color clearBlueText = Color(0xFF1D63B8);

  // Semantic aliases used by feature widgets.
  static const Color success = teal;
  static const Color warning = warningAmber;
  static const Color danger = errorRed;

  // ---------------------------------------------------------------------------
  // Dark theme surfaces
  // ---------------------------------------------------------------------------

  static const Color darkCanvas = Color(0xFF0E1925);
  static const Color darkSurface = Color(0xFF16273A);
  static const Color darkSurfaceAlt = Color(0xFF1E3044);
  static const Color darkBorder = Color(0xFF2C4259);
  static const Color darkOnSurface = Color(0xFFE6EDF5);
  static const Color darkMuted = Color(0xFF9FB0C3);
  static const Color darkPrimary = Color(0xFF9DB9D8);
  static const Color darkBlue = Color(0xFF6FA8F5);
  static const Color darkTeal = Color(0xFF4FD1B5);

  // ---------------------------------------------------------------------------
  // Gradients
  // ---------------------------------------------------------------------------

  /// Subtle navy-only gradient. Kept deliberately restrained so the identity
  /// stays recognisably Deep Navy rather than becoming a multicolour gradient.
  static const LinearGradient navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[deepNavy, navyLight],
  );

  /// A deeper variant used for splash and welcome backgrounds.
  static const LinearGradient navyBackdrop = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[navyDeep, deepNavy, navyLight],
    stops: <double>[0, 0.55, 1],
  );
}
