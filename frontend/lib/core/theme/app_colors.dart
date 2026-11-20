import 'package:flutter/material.dart';

/// Auxilia's central colour system - Trust Blue.
///
/// A blue-led palette built around #2563EB (trust blue): dependable, calm,
/// productive. Emerald is kept for completion/positive cues and surfaces are
/// a cool near-white so content stays legible and professional.
///
/// The legacy token names (pacific, moss, saffron, ...) are kept so feature
/// widgets continue to compile; their values now point at the Trust Blue
/// palette.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Trust Blue palette
  // ---------------------------------------------------------------------------

  /// Trust blue - primary actions, links, focus rings and selections.
  static const Color pacific = Color(0xFF2563EB);

  /// Slate - secondary text, captions and muted accents.
  static const Color moss = Color(0xFF475569);

  /// Success green - completion states and positive indicators.
  static const Color malachite = Color(0xFF059669);

  /// Light blue tint - selected rows, icon tiles and light containers.
  static const Color lichen = Color(0xFFDBEAFE);

  /// Deep trust blue - primary buttons and high-contrast surfaces.
  static const Color saffron = Color(0xFF1D4ED8);

  /// Error red - inline errors, overdue and destructive states.
  static const Color persimmon = Color(0xFFDC2626);

  /// Slate - quiet accent for highlights.
  static const Color blush = Color(0xFF64748B);

  /// Deep navy - headings, body text and dark brand surfaces.
  static const Color darkestNavy = Color(0xFF0F172A);

  /// Cool near-white - the main application background.
  static const Color cocoCream = Color(0xFFF1F5F9);

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
  static const Color divider = Color(0xFFCBD5E1);

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

  /// Accessible trust blue for text links on light surfaces.
  static const Color clearBlueText = Color(0xFF1D4ED8);

  // Semantic aliases used by feature widgets.
  static const Color success = successGreen;
  static const Color warning = warningAmber;
  static const Color danger = errorRed;

  // ---------------------------------------------------------------------------
  // Gradients and depth
  // ---------------------------------------------------------------------------

  /// Signature brand gradient - deep trust blue into vivid azure.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E40AF), Color(0xFF2563EB), Color(0xFF38BDF8)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Success gradient for completion moments.
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF047857), Color(0xFF10B981)],
  );

  /// Soft ambient shadow for elevated surfaces.
  static List<BoxShadow> softShadow({Color tint = const Color(0xFF2563EB)}) => [
    BoxShadow(
      color: tint.withValues(alpha: 0.10),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  // ---------------------------------------------------------------------------
  // Dark theme surfaces (deep navy variant)
  // ---------------------------------------------------------------------------

  static const Color darkCanvas = darkestNavy;
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceAlt = Color(0xFF263449);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkOnSurface = Color(0xFFE2E8F0);
  static const Color darkMuted = Color(0xFF94A3B8);
  static const Color darkPrimary = Color(0xFF60A5FA);
  static const Color darkBlue = Color(0xFF60A5FA);
  static const Color darkTeal = malachite;
}
