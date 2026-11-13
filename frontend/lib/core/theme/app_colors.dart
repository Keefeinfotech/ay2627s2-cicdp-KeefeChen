import 'package:flutter/material.dart';

/// Auxilia's central colour system — Urban Slate.
///
/// A warm greige canvas (#E9E6E7) with a dark taupe (#5E5653) for primary
/// buttons and the top app bar, steel blue (#6B7C98) for links, focus and
/// selected states, slate grey (#7B7F8A) for secondary text, and warm clay
/// (#AB978C) as the accent. Surfaces stay neutral so content remains legible
/// and calm.
///
/// The weather-inspired token names (pacific, moss, saffron, …) are kept so
/// feature widgets continue to compile; their values now point at the Urban
/// Slate palette.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Urban Slate palette
  // ---------------------------------------------------------------------------

  /// Steel blue - links, focus rings, selections and quiet accents.
  /// Darkened to #4F5D75 so link text meets WCAG AA (>= 4.5) on light surfaces.
  static const Color pacific = Color(0xFF4F5D75);

  /// Slate grey - secondary text, captions and muted accents.
  /// Darkened to #5A5F6A so secondary text meets WCAG AA (>= 4.5) on
  /// greige, white and selected-row tints.
  static const Color moss = Color(0xFF5A5F6A);

  /// Success green — completion states and positive indicators.
  static const Color malachite = Color(0xFF16A34A);

  /// Light steel tint — selected rows, icon tiles and light containers.
  static const Color lichen = Color(0xFFDFE3EB);

  /// Dark taupe — primary buttons, pressed states and the top app bar.
  static const Color saffron = Color(0xFF5E5653);

  /// Error red — inline errors, overdue and destructive states.
  static const Color persimmon = Color(0xFFDC2626);

  /// Warm clay — the palette's warm accent for highlights.
  static const Color blush = Color(0xFFAB978C);

  /// Warm near-black — headings, body text and dark brand surfaces.
  static const Color darkestNavy = Color(0xFF2B2724);

  /// Warm greige — the main application background.
  static const Color cocoCream = Color(0xFFE9E6E7);

  // ---------------------------------------------------------------------------
  // Core palette
  // ---------------------------------------------------------------------------

  /// Primary action accent (steel blue).
  static const Color trustBlue = pacific;

  /// Pressed states, primary buttons and high-contrast surfaces (dark taupe).
  static const Color primaryDark = saffron;

  /// Light tint for selected rows and informational surfaces.
  static const Color primaryLight = lichen;

  /// Main application background (warm greige).
  static const Color background = cocoCream;

  /// Cards and content surfaces.
  static const Color surface = Color(0xFFFFFFFF);

  /// Main text and headings.
  static const Color textPrimary = darkestNavy;

  /// Secondary text and captions.
  static const Color textSecondary = moss;

  /// Success and task completion.
  static const Color successGreen = malachite;

  /// Warnings and attention states.
  static const Color warningAmber = Color(0xFFD97706);

  /// Errors and destructive actions.
  static const Color errorRed = persimmon;

  /// Dividers and card borders (warm hairline).
  static const Color divider = Color(0xFFD9D4D1);

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

  /// A deeper warm charcoal for high-contrast brand surfaces.
  static const Color navyDeep = darkestNavy;

  /// A lighter steel blue for hover states and quiet accents.
  static const Color navyLight = Color(0xFF8794AC);

  /// Very light steel tint for selected rows and icon tiles.
  static const Color navyTint = lichen;

  /// Light tint for informational surfaces.
  static const Color blueTint = primaryLight;

  /// Warm clay accent from the Urban Slate palette.
  static const Color warmAccent = blush;

  /// Light warm clay tint for warm highlights and soft surfaces.
  static const Color warmTint = Color(0xFFF3E9E4);

  /// Light green tint for success surfaces.
  static const Color tealTint = Color(0xFFDCFCE7);

  /// Light amber tint for warning surfaces.
  static const Color warningTint = Color(0xFFFEF3C7);

  /// Light red tint for error surfaces.
  static const Color errorTint = Color(0xFFFEE2E2);

  /// Accessible steel blue for text links on light surfaces.
  static const Color clearBlueText = Color(0xFF4F5D75);

  // Semantic aliases used by feature widgets.
  static const Color success = successGreen;
  static const Color warning = warningAmber;
  static const Color danger = errorRed;

  // ---------------------------------------------------------------------------
  // Dark theme surfaces (warm charcoal variant)
  // ---------------------------------------------------------------------------

  static const Color darkCanvas = darkestNavy;
  static const Color darkSurface = Color(0xFF2E2A29);
  static const Color darkSurfaceAlt = Color(0xFF383331);
  static const Color darkBorder = Color(0xFF4A4441);
  static const Color darkOnSurface = Color(0xFFEDEAE8);
  static const Color darkMuted = Color(0xFFA9A29E);
  static const Color darkPrimary = Color(0xFF93A4BF);
  static const Color darkBlue = Color(0xFF93A4BF);
  static const Color darkTeal = malachite;
}
