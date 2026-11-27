import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/calendar/data/models/calendar_event.dart';
import 'package:frontend/features/calendar/presentation/widgets/calendar_event_card.dart';

void main() {
  CalendarEvent ev({
    String id = '1',
    String title = 'Meeting',
    DateTime? start,
    DateTime? end,
    bool allDay = false,
    CalendarEventPriority p = CalendarEventPriority.medium,
    CalendarEventStatus s = CalendarEventStatus.scheduled,
    String? loc,
    String? taskId,
  }) {
    final st = start ?? DateTime.now().add(const Duration(hours: 1));
    return CalendarEvent(
      id: id,
      title: title,
      startTime: st,
      endTime: end ?? st.add(const Duration(hours: 1)),
      isAllDay: allDay,
      priority: p,
      status: s,
      location: loc,
      taskId: taskId,
    );
  }

  testWidgets('renders event card variants', (tester) async {
    var tapped = false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 10);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              CalendarEventCard(
                event: ev(start: today, loc: 'Room 1', taskId: 't1'),
                hasConflict: true,
                onTap: () => tapped = true,
              ),
              CalendarEventCard(
                event: ev(
                  id: '2',
                  title: 'Done',
                  s: CalendarEventStatus.completed,
                  p: CalendarEventPriority.high,
                ),
              ),
              CalendarEventCard(
                event: ev(
                  id: '3',
                  title: 'Cancelled',
                  s: CalendarEventStatus.cancelled,
                  p: CalendarEventPriority.low,
                ),
              ),
              CalendarEventCard(
                event: ev(
                  id: '4',
                  title: 'Urgent',
                  p: CalendarEventPriority.urgent,
                  allDay: true,
                ),
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Meeting'), findsOneWidget);
    expect(find.text('Overlap'), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Room 1'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Urgent'), findsOneWidget);
    expect(find.text('All day'), findsOneWidget);

    await tester.tap(find.text('Meeting'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
