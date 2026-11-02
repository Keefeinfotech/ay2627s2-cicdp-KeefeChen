/// Application-wide constants that are not visual design tokens.
abstract final class AppConstants {
  static const String appName = 'Auxilia';
  static const String tagline = 'Help Anywhere, Learn Together';
  static const String shortDescription =
      'Manage tasks, organise schedules and keep track of your responsibilities '
      'with one personal assistant.';
  static const String version = '1.0.0';

  /// Guest tasks are stored under this owner key, as in previous releases.
  static const String guestOwnerId = 'local';
}
