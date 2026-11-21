/// Shared spacing, radius and sizing tokens.
///
/// Using these tokens keeps padding and component sizes consistent across the
/// application instead of relying on one-off magic numbers in screens.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double huge = 64;
}

abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 20;
  static const double pill = 999;
}

abstract final class AppSizes {
  /// Maximum readable width for dashboard and content screens.
  static const double maxContentWidth = 1120;

  /// Maximum width for an authentication form.
  static const double maxFormWidth = 420;

  /// Maximum width for the AI conversation column.
  static const double maxChatWidth = 840;

  /// Standard interactive height. Keeps touch targets accessible.
  static const double buttonHeight = 48;
  static const double largeButtonHeight = 52;
  static const double touchTarget = 48;

  /// Default icon sizes.
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;

  /// Icon tile used by dashboard stats and similar compact indicators.
  static const double iconTile = 36;

  /// Consistent minimum height for dashboard stat cards. Keeps the five KPI
  /// cards aligned even when values wrap or text scales up.
  static const double statCardMinHeight = 104;

  /// Progress indicator track height (level bar).
  static const double progressHeight = 8;

  /// Hairline borders for chips, tabs and compact containers.
  static const double hairline = 1.5;

  /// Dashboard switches from a five-card row to a wrapped grid below this
  /// width; below [tightBreakpoint] the grid drops to two columns.
  static const double compactBreakpoint = 620;
  static const double tightBreakpoint = 360;
}
