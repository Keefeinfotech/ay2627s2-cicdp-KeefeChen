import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/calendar/domain/usecases/analyze_schedule.dart';
import 'package:frontend/features/calendar/presentation/models/calendar_skin.dart';
import 'package:frontend/features/calendar/presentation/widgets/calendar_views.dart';

Widget buildMonth({
  CalendarPreferences preferences = const CalendarPreferences(),
  ValueChanged<DateTime>? onSelect,
  ValueChanged<DateTime>? onMark,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: 800,
          child: MonthlyCalendarView(
            focusDate: DateTime(2026, 11, 23),
            selectedDate: DateTime(2026, 11, 17),
            analysis: const ScheduleAnalysis(
              days: <CalendarDaySummary>[],
              overlaps: <CalendarOverlap>[],
              suggestions: <ScheduleSuggestion>[],
            ),
            onSelectDate: onSelect ?? (_) {},
            onEventTap: (_) {},
            onCreate: (_) {},
            preferences: preferences,
            onMarkDate: onMark,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders each day as its own square tile', (tester) async {
    await tester.pumpWidget(buildMonth());

    // November 2026 has 30 days; each cell is an independently painted tile.
    for (final day in <int>[1, 8, 17, 23, 30]) {
      expect(find.text('$day'), findsOneWidget, reason: 'day $day');
    }
    final tiles = find.byWidgetPredicate(
      (widget) => widget is Material && widget.borderRadius != null,
    );
    expect(tiles, findsNWidgets(30));
  });

  testWidgets('tapping a square selects that day', (tester) async {
    DateTime? selected;
    await tester.pumpWidget(buildMonth(onSelect: (date) => selected = date));

    await tester.tap(find.text('18'));
    await tester.pumpAndSettle();

    expect(selected, DateTime(2026, 11, 18));
  });

  testWidgets('a marked day shows a flag and can be re-marked', (tester) async {
    DateTime? marked;
    const preferences = CalendarPreferences(
      marks: <String, String>{'2026-11-17': 'focus'},
    );
    await tester.pumpWidget(
      buildMonth(preferences: preferences, onMark: (date) => marked = date),
    );

    expect(find.bySemanticsLabel('Change Focus mark'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Change Focus mark'));
    await tester.pumpAndSettle();

    expect(marked, DateTime(2026, 11, 17));
  });

  testWidgets('unmarked days offer a mark affordance', (tester) async {
    await tester.pumpWidget(buildMonth(onMark: (_) {}));

    expect(find.bySemanticsLabel('Mark this day'), findsNWidgets(30));
  });

  testWidgets('selected square uses the skin primary colour', (tester) async {
    final theme = CalendarSkin.midnight.themeFor(AppTheme.light());
    await tester.pumpWidget(buildMonth(theme: theme));

    final selectedTile = find.byWidgetPredicate(
      (widget) =>
          widget is Material && widget.color == theme.colorScheme.primary,
    );
    expect(selectedTile, findsOneWidget);
  });

  testWidgets('long press opens the mark action', (tester) async {
    DateTime? marked;
    await tester.pumpWidget(buildMonth(onMark: (date) => marked = date));

    await tester.longPress(find.text('23'));
    await tester.pumpAndSettle();

    expect(marked, DateTime(2026, 11, 23));
  });
}
