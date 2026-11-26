import 'package:flutter/material.dart';

import '../../../../core/design_system/ds_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Visual skins available for the calendar surface.
///
/// `system` keeps the application theme. The other presets rebuild the
/// Material 3 palette from scratch and are applied to the calendar subtree
/// only, so customising the calendar never changes the rest of Auxilia.
enum CalendarSkin { system, midnight, aurora, sandstone, orchid }

/// Corner treatment of the individual day squares.
enum CalendarSquareStyle { soft, rounded, crisp }

/// A user-applied mark for a single day.
///
/// Marks are independent of scheduled events: they let learners flag a day
/// as focus time, done, important or personal without creating a calendar
/// event.
enum CalendarMark { none, focus, done, important, personal }

const ColorScheme _midnightScheme = ColorScheme(
  brightness: Brightness.dark,
  // #2563EB keeps white selected-day text above the WCAG AA 4.5:1 threshold.
  primary: Color(0xFF2563EB),
  onPrimary: Colors.white,
  primaryContainer: Color(0xFF1E3A5F),
  onPrimaryContainer: Color(0xFFDBEAFE),
  secondary: Color(0xFF38BDF8),
  onSecondary: Color(0xFF082F49),
  secondaryContainer: Color(0xFF0C4A6E),
  onSecondaryContainer: Color(0xFFE0F2FE),
  tertiary: Color(0xFF34D399),
  onTertiary: Color(0xFF052E25),
  tertiaryContainer: Color(0xFF0F3E34),
  onTertiaryContainer: Color(0xFFC9F5EA),
  error: Color(0xFFF87171),
  onError: Color(0xFF450A0A),
  errorContainer: Color(0xFF7F1D1D),
  onErrorContainer: Color(0xFFFEE2E2),
  surface: Color(0xFF1E293B),
  onSurface: Color(0xFFE2E8F0),
  onSurfaceVariant: Color(0xFF94A3B8),
  surfaceContainerHighest: Color(0xFF28374C),
  outline: Color(0xFF475569),
  outlineVariant: Color(0xFF334155),
  shadow: Color(0x66000000),
  scrim: Color(0x99000000),
  inverseSurface: Color(0xFFE2E8F0),
  onInverseSurface: Color(0xFF0F172A),
  inversePrimary: Color(0xFF93C5FD),
  surfaceTint: Color(0xFF2563EB),
);

const ColorScheme _auroraScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF34D399),
  onPrimary: Color(0xFF052E25),
  primaryContainer: Color(0xFF12433B),
  onPrimaryContainer: Color(0xFFA7F3D0),
  secondary: Color(0xFF22D3EE),
  onSecondary: Color(0xFF083344),
  secondaryContainer: Color(0xFF155E75),
  onSecondaryContainer: Color(0xFFCFFAFE),
  tertiary: Color(0xFF6EE7B7),
  onTertiary: Color(0xFF052E25),
  tertiaryContainer: Color(0xFF14532D),
  onTertiaryContainer: Color(0xFFDCFCE7),
  error: Color(0xFFFCA5A5),
  onError: Color(0xFF450A0A),
  errorContainer: Color(0xFF7F1D1D),
  onErrorContainer: Color(0xFFFEE2E2),
  surface: Color(0xFF112C30),
  onSurface: Color(0xFFD5F5EC),
  onSurfaceVariant: Color(0xFF96BDB6),
  surfaceContainerHighest: Color(0xFF1C3C40),
  outline: Color(0xFF3A6665),
  outlineVariant: Color(0xFF275052),
  shadow: Color(0x66000000),
  scrim: Color(0x99000000),
  inverseSurface: Color(0xFFD5F5EC),
  onInverseSurface: Color(0xFF071D20),
  inversePrimary: Color(0xFF6EE7B7),
  surfaceTint: Color(0xFF34D399),
);

const ColorScheme _sandstoneScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFFB45309),
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFFEF3C7),
  onPrimaryContainer: Color(0xFF78350F),
  secondary: Color(0xFF0F766E),
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFCCFBF1),
  onSecondaryContainer: Color(0xFF134E4A),
  tertiary: Color(0xFF15803D),
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFDCFCE7),
  onTertiaryContainer: Color(0xFF14532D),
  error: Color(0xFFB91C1C),
  onError: Colors.white,
  errorContainer: Color(0xFFFEE2E2),
  onErrorContainer: Color(0xFF7F1D1D),
  surface: Color(0xFFFFFFFB),
  onSurface: Color(0xFF292524),
  onSurfaceVariant: Color(0xFF78716C),
  surfaceContainerHighest: Color(0xFFF5EFE4),
  outline: Color(0xFFA8A29E),
  outlineVariant: Color(0xFFE7E2D9),
  shadow: Color(0x1A292524),
  scrim: Color(0x66292524),
  inverseSurface: Color(0xFF292524),
  onInverseSurface: Color(0xFFFFFFFB),
  inversePrimary: Color(0xFFFCD34D),
  surfaceTint: Color(0xFFB45309),
);

/// Brand-compliant light skin. The persisted enum name remains `orchid` for
/// backwards compatibility, but the user-facing option is now "Focus".
const ColorScheme _focusScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Ds.trustBlue,
  onPrimary: Ds.onPrimary,
  primaryContainer: Ds.trustBlueLight,
  onPrimaryContainer: Ds.trustBlueDark,
  secondary: Ds.accentGreen,
  onSecondary: Ds.onPrimary,
  secondaryContainer: Ds.accentGreenSoft,
  onSecondaryContainer: Ds.accentGreen,
  tertiary: Ds.warningAmber,
  onTertiary: Ds.onPrimary,
  tertiaryContainer: Ds.warningAmberSoft,
  onTertiaryContainer: Ds.textPrimary,
  error: Ds.dangerRed,
  onError: Ds.onPrimary,
  errorContainer: Ds.dangerRedSoft,
  onErrorContainer: Ds.dangerRed,
  surface: Ds.bgSurface,
  onSurface: Ds.textPrimary,
  onSurfaceVariant: Ds.textSecondary,
  surfaceContainerHighest: Ds.bgPage,
  outline: Ds.borderStrong,
  outlineVariant: Ds.border,
  shadow: Color(0x1A101828),
  scrim: Color(0x66101828),
  inverseSurface: Ds.textPrimary,
  onInverseSurface: Ds.bgSurface,
  inversePrimary: Ds.primaryOnDark,
  surfaceTint: Ds.trustBlue,
);

extension CalendarSkinUi on CalendarSkin {
  /// Human-readable name shown in the appearance picker.
  String get label => switch (this) {
    CalendarSkin.system => 'System',
    CalendarSkin.midnight => 'Midnight',
    CalendarSkin.aurora => 'Aurora',
    CalendarSkin.sandstone => 'Sandstone',
    CalendarSkin.orchid => 'Focus',
  };

  /// Short explanation shown under the skin swatch.
  String get description => switch (this) {
    CalendarSkin.system => 'Follow the application theme',
    CalendarSkin.midnight => 'Deep navy with clear blue days',
    CalendarSkin.aurora => 'Dark teal with mint highlights',
    CalendarSkin.sandstone => 'Warm paper with amber days',
    CalendarSkin.orchid => 'Trust Blue with neutral days and green accents',
  };

  /// Representative colour for the picker swatch.
  Color get swatch => switch (this) {
    CalendarSkin.system => AppColors.saffron,
    CalendarSkin.midnight => const Color(0xFF1E293B),
    CalendarSkin.aurora => const Color(0xFF112C30),
    CalendarSkin.sandstone => const Color(0xFFF5EFE4),
    CalendarSkin.orchid => Ds.trustBlue,
  };

  bool get isDark => switch (this) {
    CalendarSkin.system => false,
    CalendarSkin.midnight => true,
    CalendarSkin.aurora => true,
    CalendarSkin.sandstone => false,
    CalendarSkin.orchid => false,
  };

  /// The palette used by this skin, or `null` for [CalendarSkin.system].
  ColorScheme? get colorScheme => switch (this) {
    CalendarSkin.system => null,
    CalendarSkin.midnight => _midnightScheme,
    CalendarSkin.aurora => _auroraScheme,
    CalendarSkin.sandstone => _sandstoneScheme,
    CalendarSkin.orchid => _focusScheme,
  };

  Color get canvas => switch (this) {
    CalendarSkin.system => AppColors.background,
    CalendarSkin.midnight => const Color(0xFF0F172A),
    CalendarSkin.aurora => const Color(0xFF071D20),
    CalendarSkin.sandstone => const Color(0xFFFBF7F0),
    CalendarSkin.orchid => Ds.bgPage,
  };

  /// Secondary semantic colours that are not part of Material's ColorScheme.
  Color get warningColor => switch (this) {
    CalendarSkin.system => AppColors.warningAmber,
    CalendarSkin.midnight => const Color(0xFFFBBF24),
    CalendarSkin.aurora => const Color(0xFFFCD34D),
    CalendarSkin.sandstone => const Color(0xFFB45309),
    CalendarSkin.orchid => Ds.warningAmber,
  };

  Color get doneColor => switch (this) {
    CalendarSkin.system => AppColors.successGreen,
    CalendarSkin.midnight => const Color(0xFF34D399),
    CalendarSkin.aurora => const Color(0xFF6EE7B7),
    CalendarSkin.sandstone => const Color(0xFF15803D),
    CalendarSkin.orchid => Ds.accentGreen,
  };

  Color get personalColor => switch (this) {
    CalendarSkin.system => Ds.trustBlue,
    CalendarSkin.midnight => Ds.primaryOnDark,
    CalendarSkin.aurora => Ds.successOnDark,
    CalendarSkin.sandstone => Ds.trustBlueDark,
    CalendarSkin.orchid => Ds.accentGreen,
  };

  /// Builds the theme applied to the calendar subtree.
  ThemeData themeFor(ThemeData base) {
    final scheme = colorScheme;
    if (scheme == null) return base;
    return AppTheme.fromScheme(scheme, canvas);
  }

  /// Colour used to render a day mark.
  Color markColor(CalendarMark mark, ColorScheme scheme) => switch (mark) {
    CalendarMark.none => scheme.outlineVariant,
    CalendarMark.focus => scheme.primary,
    CalendarMark.done => doneColor,
    CalendarMark.important => scheme.error,
    CalendarMark.personal => personalColor,
  };
}

extension CalendarSquareStyleUi on CalendarSquareStyle {
  String get label => switch (this) {
    CalendarSquareStyle.soft => 'Soft',
    CalendarSquareStyle.rounded => 'Rounded',
    CalendarSquareStyle.crisp => 'Crisp',
  };

  double get radius => switch (this) {
    CalendarSquareStyle.soft => 16,
    CalendarSquareStyle.rounded => 10,
    CalendarSquareStyle.crisp => 2,
  };
}

extension CalendarMarkUi on CalendarMark {
  String get label => switch (this) {
    CalendarMark.none => 'No mark',
    CalendarMark.focus => 'Focus',
    CalendarMark.done => 'Done',
    CalendarMark.important => 'Important',
    CalendarMark.personal => 'Personal',
  };

  IconData get icon => switch (this) {
    CalendarMark.none => Icons.flag_outlined,
    CalendarMark.focus => Icons.center_focus_strong_rounded,
    CalendarMark.done => Icons.check_rounded,
    CalendarMark.important => Icons.priority_high_rounded,
    CalendarMark.personal => Icons.star_border_rounded,
  };

  bool get isMarked => this != CalendarMark.none;
}

/// Stable key for a day, independent of time zones or locale.
String calendarDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// All persisted appearance choices for one workspace.
class CalendarPreferences {
  const CalendarPreferences({
    this.skin = CalendarSkin.system,
    this.squareStyle = CalendarSquareStyle.rounded,
    this.marks = const <String, String>{},
  });

  final CalendarSkin skin;
  final CalendarSquareStyle squareStyle;

  /// Mark name keyed by `yyyy-MM-dd`.
  final Map<String, String> marks;

  CalendarPreferences copyWith({
    CalendarSkin? skin,
    CalendarSquareStyle? squareStyle,
    Map<String, String>? marks,
  }) {
    return CalendarPreferences(
      skin: skin ?? this.skin,
      squareStyle: squareStyle ?? this.squareStyle,
      marks: marks ?? this.marks,
    );
  }

  CalendarMark markFor(DateTime date) {
    final name = marks[calendarDateKey(date)];
    if (name == null) return CalendarMark.none;
    return _markFromName(name);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'skin': skin.name,
    'squareStyle': squareStyle.name,
    'marks': marks,
  };

  static CalendarPreferences? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final parsedMarks = <String, String>{};
    final rawMarks = raw['marks'];
    if (rawMarks is Map) {
      for (final entry in rawMarks.entries) {
        if (entry.key is String && entry.value is String) {
          final name = entry.value as String;
          if (_markFromName(name) != CalendarMark.none ||
              name == CalendarMark.none.name) {
            parsedMarks[entry.key as String] = name;
          }
        }
      }
    }
    return CalendarPreferences(
      skin: _skinFromName(_string(raw['skin'])),
      squareStyle: _squareStyleFromName(_string(raw['squareStyle'])),
      marks: parsedMarks,
    );
  }

  static String? _string(Object? value) => value is String ? value : null;

  static CalendarSkin _skinFromName(String? name) {
    for (final value in CalendarSkin.values) {
      if (value.name == name) return value;
    }
    return CalendarSkin.system;
  }

  static CalendarSquareStyle _squareStyleFromName(String? name) {
    for (final value in CalendarSquareStyle.values) {
      if (value.name == name) return value;
    }
    return CalendarSquareStyle.rounded;
  }

  static CalendarMark _markFromName(String? name) {
    for (final value in CalendarMark.values) {
      if (value.name == name) return value;
    }
    return CalendarMark.none;
  }
}
