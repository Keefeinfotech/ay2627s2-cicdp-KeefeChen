import 'package:flutter/material.dart';

import '../design_system/ds_tokens.dart';

/// Compatibility facade over the canonical [Ds] palette.
///
/// `Ds` is the single source of truth for colour. These names are retained so
/// existing feature widgets keep compiling while they migrate to `Ds` tokens;
/// every value below resolves to a `Ds` constant. There are no gradients and no
/// parallel Trust Blue value — the primary is always [Ds.trustBlue].
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Legacy palette names, now mapped to canonical tokens
  // ---------------------------------------------------------------------------

  /// Trust blue - primary actions, links, focus rings and selections.
  static const Color pacific = Ds.trustBlue;

  /// Neutral secondary text and captions.
  static const Color moss = Ds.textSecondary;

  /// Success green - completion states and positive indicators.
  static const Color malachite = Ds.accentGreen;

  /// Light trust-blue tint for selected rows and icon tiles.
  static const Color lichen = Ds.trustBlueLight;

  /// Legacy alias now mapped to the primary Trust Blue.
  static const Color saffron = Ds.trustBlue;

  /// Error red - overdue and destructive states.
  static const Color persimmon = Ds.dangerRed;

  /// Neutral slate accent for quiet highlights.
  static const Color blush = Ds.textSecondary;

  /// Deep neutral used for headings and dark brand surfaces.
  static const Color darkestNavy = Ds.textPrimary;

  /// Calm near-white application canvas.
  static const Color cocoCream = Ds.bgPage;

  // ---------------------------------------------------------------------------
  // Semantic names used by feature widgets
  // ---------------------------------------------------------------------------

  static const Color trustBlue = Ds.trustBlue;
  static const Color primaryDark = Ds.trustBlueDark;
  static const Color primaryLight = Ds.trustBlueLight;
  static const Color background = Ds.bgPage;
  static const Color surface = Ds.bgSurface;
  static const Color textPrimary = Ds.textPrimary;
  static const Color textSecondary = Ds.textSecondary;
  static const Color successGreen = Ds.accentGreen;
  static const Color warningAmber = Ds.warningAmber;
  static const Color errorRed = Ds.dangerRed;
  static const Color divider = Ds.border;

  // ---------------------------------------------------------------------------
  // Backwards-compatible aliases
  //
  // Existing widgets were built around these palette names. Keeping the aliases
  // lets the whole application share one set of values without duplicating
  // components. New code should use Ds tokens directly.
  // ---------------------------------------------------------------------------

  static const Color deepNavy = Ds.trustBlueDark;
  static const Color clearBlue = Ds.trustBlue;
  static const Color softGrey = Ds.bgPage;
  static const Color white = Ds.bgSurface;
  static const Color teal = Ds.accentGreen;
  static const Color darkText = Ds.textPrimary;
  static const Color mutedText = Ds.textSecondary;
  static const Color borderGrey = Ds.border;

  static const Color navyDeep = Ds.textPrimary;
  static const Color navyLight = Ds.textMuted;
  static const Color navyTint = Ds.trustBlueLight;
  static const Color blueTint = Ds.trustBlueMuted;
  static const Color warmAccent = Ds.textSecondary;
  static const Color warmTint = Ds.trustBlueMuted;
  static const Color tealTint = Ds.accentGreenSoft;
  static const Color warningTint = Ds.warningAmberSoft;
  static const Color errorTint = Ds.dangerRedSoft;

  /// Accessible trust blue for text links on light surfaces.
  static const Color clearBlueText = Ds.trustBlueDark;

  static const Color success = Ds.accentGreen;
  static const Color warning = Ds.warningAmber;
  static const Color danger = Ds.dangerRed;

  /// Flat, restrained depth. Retained for callers that used the old ambient
  /// shadow; no gradient is involved.
  static List<BoxShadow> softShadow({Color tint = Ds.trustBlue}) => [
    BoxShadow(
      color: tint.withValues(alpha: 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Ds.textPrimary.withValues(alpha: 0.04),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  // ---------------------------------------------------------------------------
  // Dark theme surfaces and on-dark accents
  // ---------------------------------------------------------------------------

  static const Color darkCanvas = Ds.textPrimary;
  static const Color darkSurface = Ds.surfaceDark;
  static const Color darkSurfaceAlt = Ds.surfaceDarkAlt;
  static const Color darkBorder = Ds.borderDark;
  static const Color darkOnSurface = Ds.onSurfaceDark;
  static const Color darkMuted = Ds.mutedDark;
  static const Color darkPrimary = Ds.primaryOnDark;
  static const Color darkBlue = Ds.primaryOnDark;
  static const Color darkTeal = Ds.accentGreen;

  /// Light semantic accents for icon tiles/text on dark surfaces.
  static const Color darkOverdue = Ds.dangerOnDark;
  static const Color darkCompleted = Ds.successOnDark;
  static const Color darkWarning = Ds.warningOnDark;
}

/// Semantic accents shared by the dashboard stat cards, filter tabs and
/// anywhere else status is communicated. Trust Blue is the default; green is
/// reserved for completion, red for overdue, both used sparingly.
abstract final class TabWeather {
  static const Color all = Ds.trustBlue;

  /// Open tasks — a deeper shade of the primary, not a new hue.
  static const Color pending = Ds.trustBlueDark;

  static const Color overdue = Ds.dangerRed;
  static const Color completed = Ds.accentGreen;

  /// The accent to use for text/icons on a surface of the given colour
  /// scheme. Dark surfaces need lighter variants to stay WCAG-legible.
  static Color display(Color accent, ColorScheme scheme) {
    if (scheme.brightness == Brightness.light) return accent;
    if (accent == overdue) return Ds.dangerOnDark;
    if (accent == completed) return Ds.successOnDark;
    return Ds.primaryOnDark;
  }
}
