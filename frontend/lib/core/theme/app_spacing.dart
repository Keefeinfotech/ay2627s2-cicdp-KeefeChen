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
}
