import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/calendar/data/models/calendar_event.dart';
import 'package:frontend/features/calendar/domain/usecases/analyze_schedule.dart';
import 'package:frontend/features/calendar/presentation/widgets/schedule_optimization_banner.dart';

CalendarEvent _ev(
  String id,
  String title,
  DateTime start,
  DateTime end, {
  CalendarEventPriority priority = CalendarEventPriority.medium,
}) => CalendarEvent(
  id: id,
  title: title,
  startTime: start,
  endTime: end,
  priority: priority,
);

void main() {
  testWidgets('banner shows overload summary and opens sheet', (tester) async {
    final day = DateTime(2026, 1, 5);
    final e1 = _ev(
      '1',
      'A',
      day.add(const Duration(hours: 9)),
      day.add(const Duration(hours: 11)),
    );
    final e2 = _ev(
      '2',
      'B',
      day.add(const Duration(hours: 10)),
      day.add(const Duration(hours: 12)),
      priority: CalendarEventPriority.low,
    );
    final analysis = const AnalyzeSchedule()(
      [e1, e2],
      startDate: day,
      endDate: day,
    );
    var reviewed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleOptimizationBanner(
            analysis: analysis,
            onReview: () => reviewed = true,
          ),
        ),
      ),
    );

    expect(find.text('AI Schedule Optimization'), findsOneWidget);
    expect(find.textContaining('re-balancing'), findsOneWidget);
    await tester.tap(find.text('Review plan'));
    await tester.pump();
    expect(reviewed, isTrue);
  });

  testWidgets('banner shows balanced state', (tester) async {
    final day = DateTime(2026, 1, 5);
    final analysis = const AnalyzeSchedule()(
      const [],
      startDate: day,
      endDate: day,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleOptimizationBanner(analysis: analysis, onReview: () {}),
        ),
      ),
    );
    expect(
      find.text('Your workload is balanced across this view.'),
      findsOneWidget,
    );
    expect(find.text('View insights'), findsOneWidget);
  });

  testWidgets('sheet renders suggestions and applies', (tester) async {
    final day = DateTime(2026, 1, 5);
    final e1 = _ev(
      '1',
      'A',
      day.add(const Duration(hours: 9)),
      day.add(const Duration(hours: 11)),
    );
    final e2 = _ev(
      '2',
      'B',
      day.add(const Duration(hours: 10)),
      day.add(const Duration(hours: 12)),
      priority: CalendarEventPriority.low,
    );
    final analysis = const AnalyzeSchedule()(
      [e1, e2],
      startDate: day,
      endDate: day,
    );
    ScheduleSuggestion? applied;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ScheduleOptimizationSheet(
                  analysis: analysis,
                  onApply: (s) => applied = s,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Schedule optimization'), findsOneWidget);
    if (analysis.suggestions.isNotEmpty) {
      await tester.tap(find.textContaining('Apply').first);
      await tester.pump();
      expect(applied, isNotNull);
    }
  });
}
