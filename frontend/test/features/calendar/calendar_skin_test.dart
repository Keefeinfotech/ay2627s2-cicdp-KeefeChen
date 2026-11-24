import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/calendar/presentation/models/calendar_skin.dart';

double _contrast(Color a, Color b) {
  final light = a.computeLuminance() > b.computeLuminance() ? a : b;
  final dark = a.computeLuminance() > b.computeLuminance() ? b : a;
  return (light.computeLuminance() + 0.05) / (dark.computeLuminance() + 0.05);
}

void main() {
  test('system skin keeps the base theme untouched', () {
    final base = AppTheme.light();
    expect(CalendarSkin.system.themeFor(base), same(base));
    expect(CalendarSkin.system.colorScheme, isNull);
  });

  test('every preset builds a complete Material 3 theme', () {
    for (final skin in CalendarSkin.values) {
      if (skin == CalendarSkin.system) continue;
      final theme = skin.themeFor(AppTheme.light());
      final palette = skin.colorScheme!;

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, palette.primary);
      expect(theme.colorScheme.surface, palette.surface);
      expect(theme.scaffoldBackgroundColor, skin.canvas);
      expect(theme.colorScheme.brightness, palette.brightness);
    }
  });

  test('selected day text meets WCAG AA contrast in every skin', () {
    for (final skin in CalendarSkin.values) {
      if (skin == CalendarSkin.system) continue;
      final palette = skin.colorScheme!;
      expect(
        _contrast(palette.primary, palette.onPrimary),
        greaterThanOrEqualTo(4.5),
        reason: '${skin.label} selected-day contrast',
      );
    }
  });

  test('square styles expose distinct corner radii and labels', () {
    final radii = CalendarSquareStyle.values.map((s) => s.radius).toSet();
    expect(radii.length, CalendarSquareStyle.values.length);
    for (final style in CalendarSquareStyle.values) {
      expect(style.label, isNotEmpty);
    }
  });

  test('marks expose labels, icons and skin-aware colours', () {
    for (final mark in CalendarMark.values) {
      expect(mark.label, isNotEmpty);
      expect(mark.icon, isNotNull);
    }
    const night = CalendarSkin.midnight;
    const day = CalendarSkin.sandstone;
    final scheme = night.colorScheme!;
    expect(night.markColor(CalendarMark.focus, scheme), scheme.primary);
    expect(
      day.markColor(CalendarMark.done, day.colorScheme!),
      isNot(day.colorScheme!.primary),
    );
  });

  test('preferences round-trip through JSON', () {
    const original = CalendarPreferences(
      skin: CalendarSkin.aurora,
      squareStyle: CalendarSquareStyle.crisp,
      marks: <String, String>{'2026-11-17': 'focus', '2026-11-23': 'important'},
    );
    final parsed = CalendarPreferences.tryFromJson(original.toJson())!;

    expect(parsed.skin, CalendarSkin.aurora);
    expect(parsed.squareStyle, CalendarSquareStyle.crisp);
    expect(parsed.marks, original.marks);
    expect(parsed.markFor(DateTime(2026, 11, 17)), CalendarMark.focus);
    expect(parsed.markFor(DateTime(2026, 11, 18)), CalendarMark.none);
  });

  test('unknown names and malformed JSON fall back to defaults', () {
    final parsed = CalendarPreferences.tryFromJson(<String, dynamic>{
      'skin': 'not-a-skin',
      'squareStyle': 42,
      'marks': <String, dynamic>{'2026-01-01': 'nonsense'},
    })!;
    expect(parsed.skin, CalendarSkin.system);
    expect(parsed.squareStyle, CalendarSquareStyle.rounded);
    expect(parsed.marks, isEmpty);

    expect(CalendarPreferences.tryFromJson('not a map'), isNull);
    expect(calendarDateKey(DateTime(2026, 1, 5)), '2026-01-05');
  });
}
