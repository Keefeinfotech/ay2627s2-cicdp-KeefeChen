import 'package:flutter/material.dart';

/// Auxilia's central colour system.
///
/// Trust Blue is reserved for primary actions and selected states, with a
/// darker shade for pressed states and links. The canvas and surfaces stay
/// neutral so content remains legible and calm.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Core palette
  // ---------------------------------------------------------------------------

  /// Trust Blue: primary action colour used for buttons, links and selections.
  static const Color trustBlue = Color(0xFF2563EB);

  /// Primary Dark: pressed states, links and high-contrast accents.
  static const Color primaryDark = Color(0xFF1D4ED8);

  /// Light blue tint for selected rows, icon tiles and informational surfaces.
  static const Color primaryLight = Color(0xFFDBEAFE);

  /// Main application background.
  static const Color background = Color(0xFFF8FAFC);

  /// Cards and content surfaces.
  static const Color surface = Color(0xFFFFFFFF);

  /// Main text and headings.
  static const Color textPrimary = Color(0xFF0F172A);

  /// Secondary text and captions.
  static const Color textSecondary = Color(0xFF64748B);

  /// Success and task completion.
  static const Color successGreen = Color(0xFF16A34A);

  /// Warnings and attention states.
  static const Color warningAmber = Color(0xFFD97706);

  /// Errors and destructive actions.
  static const Color errorRed = Color(0xFFDC2626);

  /// Dividers and card borders.
  static const Color divider = Color(0xFFE2E8F0);

  // ---------------------------------------------------------------------------
  // Backwards-compatible aliases
  //
  // Existing widgets were built around these palette names. Keeping the aliases
  // lets the whole application share one set of values without duplicating
  // components.
  // ---------------------------------------------------------------------------

  static const Color deepNavy = primaryDark;
  static const Color clearBlue = trustBlue;
  static const Color softGrey = background;
  static const Color white = surface;
  static const Color teal = successGreen;
  static const Color darkText = textPrimary;
  static const Color mutedText = textSecondary;
  static const Color borderGrey = divider;

  /// A darker blue used for high-contrast brand surfaces.
  static const Color navyDeep = Color(0xFF172554);

  /// A lighter blue for hover states and quiet accents.
  static const Color navyLight = Color(0xFF3B82F6);

  /// Very light blue tint for selected rows and icon tiles.
  static const Color navyTint = Color(0xFFEFF6FF);

  /// Light blue tint for informational surfaces.
  static const Color blueTint = primaryLight;

  /// Light green tint for success surfaces.
  static const Color tealTint = Color(0xFFDCFCE7);

  /// Light amber tint for warning surfaces.
  static const Color warningTint = Color(0xFFFEF3C7);

  /// Light red tint for error surfaces.
  static const Color errorTint = Color(0xFFFEE2E2);

  /// Accessible darker blue for text links on light surfaces.
  static const Color clearBlueText = primaryDark;

  // Semantic aliases used by feature widgets.
  static const Color success = successGreen;
  static const Color warning = warningAmber;
  static const Color danger = errorRed;

  // ---------------------------------------------------------------------------
  // Dark theme surfaces
  // ---------------------------------------------------------------------------

  static const Color darkCanvas = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF111B2E);
  static const Color darkSurfaceAlt = Color(0xFF1B2940);
  static const Color darkBorder = Color(0xFF2C3E57);
  static const Color darkOnSurface = Color(0xFFE8EEF7);
  static const Color darkMuted = Color(0xFF9FB0C3);
  static const Color darkPrimary = Color(0xFFB9CCE8);
  static const Color darkBlue = Color(0xFF7DABF8);
  static const Color darkTeal = Color(0xFF4ADE80);
}
