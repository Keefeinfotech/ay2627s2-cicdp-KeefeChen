import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/calendar/data/calendar_preferences_store.dart';
import 'package:frontend/features/calendar/presentation/models/calendar_skin.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('defaults to the system skin and no marks', () async {
    final store = CalendarPreferencesStore(ownerId: 'owner');
    await store.load();

    expect(store.isLoaded, isTrue);
    expect(store.preferences.skin, CalendarSkin.system);
    expect(store.preferences.squareStyle, CalendarSquareStyle.rounded);
    expect(store.preferences.marks, isEmpty);
  });

  test('saves and reloads skin, square style and marks per owner', () async {
    final store = CalendarPreferencesStore(ownerId: 'owner');
    await store.setSkin(CalendarSkin.midnight);
    await store.setSquareStyle(CalendarSquareStyle.soft);
    await store.setMark(DateTime(2026, 11, 17), CalendarMark.focus);
    await store.setMark(DateTime(2026, 11, 23), CalendarMark.important);

    final reloaded = CalendarPreferencesStore(ownerId: 'owner');
    await reloaded.load();
    expect(reloaded.preferences.skin, CalendarSkin.midnight);
    expect(reloaded.preferences.squareStyle, CalendarSquareStyle.soft);
    expect(
      reloaded.preferences.markFor(DateTime(2026, 11, 17)),
      CalendarMark.focus,
    );
    expect(
      reloaded.preferences.markFor(DateTime(2026, 11, 23)),
      CalendarMark.important,
    );

    final other = CalendarPreferencesStore(ownerId: 'someone-else');
    await other.load();
    expect(other.preferences.skin, CalendarSkin.system);
    expect(other.preferences.marks, isEmpty);
  });

  test('setting "none" removes a mark and clearMarks empties all', () async {
    final store = CalendarPreferencesStore(ownerId: 'owner');
    final date = DateTime(2026, 11, 17);
    await store.setMark(date, CalendarMark.done);
    await store.setMark(date, CalendarMark.none);
    expect(store.preferences.markFor(date), CalendarMark.none);
    expect(store.preferences.marks, isEmpty);

    await store.setMark(DateTime(2026, 11, 18), CalendarMark.personal);
    await store.clearMarks();
    expect(store.preferences.marks, isEmpty);
  });

  test(
    'malformed or future-version preferences fall back to defaults',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auxilia.calendar.preferences.v1.owner': 'not-json',
        'auxilia.calendar.preferences.v1.owner2':
            '{"version":99,"prefs":{"skin":"midnight"}}',
      });

      final broken = CalendarPreferencesStore(ownerId: 'owner');
      await broken.load();
      expect(broken.preferences.skin, CalendarSkin.system);

      final future = CalendarPreferencesStore(ownerId: 'owner2');
      await future.load();
      expect(future.preferences.skin, CalendarSkin.system);
    },
  );

  test('reset restores defaults and notifies listeners', () async {
    final store = CalendarPreferencesStore(ownerId: 'owner');
    var notifications = 0;
    store.addListener(() => notifications++);

    await store.setSkin(CalendarSkin.orchid);
    await store.reset();

    expect(store.preferences, const CalendarPreferences());
    expect(notifications, greaterThanOrEqualTo(2));
  });
}
