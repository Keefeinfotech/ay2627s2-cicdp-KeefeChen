import 'package:flutter/material.dart';

/// Auxilia's vivid weather-inspired colour system.
///
/// Replaces the muted Deep Navy palette with a cafe-by-the-window aesthetic:
/// warm saffron, earthy moss, teal pacific, soft lichen, persimmon, blush,
/// coco cream and darkest navy. Each colour is named after the palette the
/// user shared so the app can feel like sitting in a cosy cafe on a rainy day
/// — vivid, grounded and alive.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Weather-inspired vivid palette
  // ---------------------------------------------------------------------------

  /// Pacific — deep teal, like ocean seen through a rainy cafe window.
  static const Color pacific = Color(0xFF0F7B7B);

  /// Moss — grounded earthy green, like forest after rain.
  static const Color moss = Color(0xFF556B2F);

  /// Malachite — bright vivid green, like new leaves.
  static const Color malachite = Color(0xFF00C853);

  /// Lichen — soft pale green, like morning mist.
  static const Color lichen = Color(0xFFA8C686);

  /// Saffron — warm golden yellow, like sunlight through clouds.
  static const Color saffron = Color(0xFFE9C46A);

  /// Persimmon — warm orange-red, like a cafe mug of spiced tea.
  static const Color persimmon = Color(0xFFE76F51);

  /// Blush — soft pink, like dawn light on porcelain.
  static const Color blush = Color(0xFFF4A261);

  /// Darkest navy — deep brand night, like a dark street outside the cafe.
  static const Color darkestNavy = Color(0xFF1A1A2E);

  /// Coco cream — warm off-white, like frothed milk.
  static const Color cocoCream = Color(0xFFFDF5E6);

  // ---------------------------------------------------------------------------
  // Core palette (kept for backwards-compatible aliases below)
  // ---------------------------------------------------------------------------

  /// Primary action colour — now saffron for a vivid, energetic feel.
  static const Color trustBlue = saffron;

  /// Pressed states, links and high-contrast accents — persimmon.
  static const Color primaryDark = persimmon;

  /// Light tint for selected rows and informational surfaces — lichen.
  static const Color primaryLight = lichen;

  /// Main application background — coco cream.
  static const Color background = cocoCream;

  /// Cards and content surfaces — white-ish coco cream variant.
  static const Color surface = Color(0xFFFFFBF0);

  /// Main text and headings — darkest navy for contrast.
  static const Color textPrimary = darkestNavy;

  /// Secondary text and captions — moss.
  static const Color textSecondary = moss;

  /// Success and task completion — malachite.
  static const Color successGreen = malachite;

  /// Warnings and attention states — saffron.
  static const Color warningAmber = saffron;

  /// Errors and destructive actions — persimmon.
  static const Color errorRed = persimmon;

  /// Dividers and card borders — soft lichen tint.
  static const Color divider = Color(0xFFE8E3D6);

  // ---------------------------------------------------------------------------
  // Backwards-compatible aliases
  // ---------------------------------------------------------------------------

  static const Color deepNavy = primaryDark;
  static const Color clearBlue = trustBlue;
  static const Color softGrey = background;
  static const Color white = surface;
  static const Color teal = successGreen;
  static const Color darkText = textPrimary;
  static const Color mutedText = textSecondary;
  static const Color borderGrey = divider;

  static const Color navyDeep = darkestNavy;
  static const Color navyLight = pacific;
  static const Color navyTint = lichen;
  static const Color blueTint = primaryLight;
  static const Color tealTint = Color(0xFFDCFCE7);
  static const Color warningTint = Color(0xFFFEF3C7);
  static const Color errorTint = Color(0xFFFEE2E2);
  static const Color clearBlueText = primaryDark;

  static const Color success = successGreen;
  static const Color warning = warningAmber;
  static const Color danger = errorRed;

  // ---------------------------------------------------------------------------
  // Dark theme surfaces (cafe-night variant)
  // ---------------------------------------------------------------------------

  static const Color darkCanvas = darkestNavy;
  static const Color darkSurface = Color(0xFF24243A);
  static const Color darkSurfaceAlt = Color(0xFF2E2E4A);
  static const Color darkBorder = Color(0xFF3E3E5E);
  static const Color darkOnSurface = cocoCream;
  static const Color darkMuted = lichen;
  static const Color darkPrimary = saffron;
  static const Color darkBlue = pacific;
  static const Color darkTeal = malachite;
}
