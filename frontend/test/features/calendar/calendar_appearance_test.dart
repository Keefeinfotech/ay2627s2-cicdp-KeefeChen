import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/calendar/data/calendar_preferences_store.dart';
import 'package:frontend/features/calendar/presentation/models/calendar_skin.dart';
import 'package:frontend/features/calendar/presentation/widgets/calendar_appearance_dialog.dart';
import 'package:frontend/features/calendar/presentation/widgets/day_mark_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Future<void> Function(BuildContext context) onOpen) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => onOpen(context),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('appearance dialog saves skin and square style', (tester) async {
    final store = CalendarPreferencesStore(ownerId: 'owner');
    await store.load();

    await tester.pumpWidget(
      _host((context) async {
        await showCalendarAppearanceDialog(context, store);
      }),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Calendar appearance'), findsOneWidget);
    await tester.tap(find.text('Aurora'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Crisp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save appearance'));
    await tester.pumpAndSettle();

    expect(store.preferences.skin, CalendarSkin.aurora);
    expect(store.preferences.squareStyle, CalendarSquareStyle.crisp);

    final reloaded = CalendarPreferencesStore(ownerId: 'owner');
    await reloaded.load();
    expect(reloaded.preferences.skin, CalendarSkin.aurora);
  });

  testWidgets('day mark picker returns the selected mark', (tester) async {
    CalendarMark? picked;
    await tester.pumpWidget(
      _host((context) async {
        picked = await showDayMarkPicker(
          context: context,
          date: DateTime(2026, 11, 23),
          current: CalendarMark.focus,
          skin: CalendarSkin.midnight,
        );
      }),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Mark this day'), findsOneWidget);
    await tester.tap(find.text('Important'));
    await tester.pumpAndSettle();

    expect(picked, CalendarMark.important);
  });
}
