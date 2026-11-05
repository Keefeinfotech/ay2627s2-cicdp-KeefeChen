import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/calendar/data/models/calendar_event.dart';
import 'package:frontend/features/calendar/domain/usecases/analyze_schedule.dart';

CalendarEvent _event({
  required String id,
  required String title,
  required DateTime start,
  required Duration duration,
  CalendarEventPriority priority = CalendarEventPriority.medium,
  CalendarEventStatus status = CalendarEventStatus.scheduled,
  String? taskId,
}) {
  return CalendarEvent(
    id: id,
    title: title,
    startTime: start,
    endTime: start.add(duration),
    priority: priority,
    status: status,
    taskId: taskId,
  );
}

void main() {
  const analyzer = AnalyzeSchedule();
  final DateTime monday = DateTime(2026, 3, 2);
  final DateTime tuesday = DateTime(2026, 3, 3);
  final DateTime wednesday = DateTime(2026, 3, 4);

  test('summarises busy time, overlaps and overloaded days', () {
    final events = <CalendarEvent>[
      _event(
        id: 'a',
        title: 'Lecture',
        start: DateTime(2026, 3, 2, 9),
        duration: const Duration(hours: 2),
        priority: CalendarEventPriority.high,
      ),
      _event(
        id: 'b',
        title: 'Team sync',
        start: DateTime(2026, 3, 2, 10),
        duration: const Duration(hours: 2),
      ),
      _event(
        id: 'c',
        title: 'Lab',
        start: DateTime(2026, 3, 2, 13),
        duration: const Duration(hours: 3),
      ),
      _event(
        id: 'd',
        title: 'Tutorial',
        start: DateTime(2026, 3, 3, 9),
        duration: const Duration(hours: 1),
      ),
      _event(
        id: 'e',
        title: 'Cancelled seminar',
        start: DateTime(2026, 3, 4, 9),
        duration: const Duration(hours: 1),
        status: CalendarEventStatus.cancelled,
      ),
    ];

    final analysis = analyzer(events, startDate: monday, endDate: wednesday);

    expect(analysis.days, hasLength(3));
    expect(analysis.busyMinutes, 420);
    expect(analysis.overlaps, hasLength(1));
    expect(analysis.overlaps.single.first.title, 'Lecture');
    expect(analysis.overlaps.single.second.title, 'Team sync');

    final mondaySummary = analysis.dayFor(monday);
    expect(mondaySummary.events, hasLength(3));
    expect(mondaySummary.busy, const Duration(hours: 6));
    expect(mondaySummary.busyLabel, '6 hr');
    expect(mondaySummary.overlapCount, 1);
    expect(mondaySummary.hasOverlap, isTrue);
    expect(mondaySummary.peakConcurrency, 2);
    expect(mondaySummary.isOverloaded, isTrue);

    final tuesdaySummary = analysis.dayFor(tuesday);
    expect(tuesdaySummary.events, hasLength(1));
    expect(tuesdaySummary.isOverloaded, isFalse);
    expect(analysis.eventsOn(tuesday).single.title, 'Tutorial');

    // Cancelled events are hidden from every summary.
    expect(analysis.dayFor(wednesday).events, isEmpty);
    expect(analysis.overloadedDayCount, 1);
    expect(analysis.eventsOn(DateTime(2026, 3, 9)), isEmpty);

    final suggestion = analysis.suggestions.single;
    expect(suggestion.title, 'Resolve overlap: Team sync');
    expect(suggestion.event?.id, 'b');
    expect(suggestion.suggestedStart, DateTime(2026, 3, 2, 11));
    expect(suggestion.description, contains('11:00'));
  });

  test('suggests moving a movable event from an overloaded day', () {
    final events = <CalendarEvent>[
      _event(
        id: 'deep-work',
        title: 'Deep work',
        start: DateTime(2026, 3, 2, 9),
        duration: const Duration(hours: 6),
        priority: CalendarEventPriority.low,
      ),
    ];

    final analysis = analyzer(events, startDate: monday, endDate: tuesday);

    expect(analysis.days.first.isOverloaded, isTrue);
    final suggestion = analysis.suggestions.single;
    expect(suggestion.title, 'Move “Deep work”');
    expect(suggestion.event?.id, 'deep-work');
    expect(suggestion.suggestedStart, DateTime(2026, 3, 3, 9));
    expect(suggestion.description, contains('Monday carries 6 hr of work'));
    expect(suggestion.description, contains('low priority'));
  });

  test('does not move task-linked or completed events', () {
    final events = <CalendarEvent>[
      _event(
        id: 'linked',
        title: 'Assignment',
        start: DateTime(2026, 3, 2, 8),
        duration: const Duration(hours: 5),
        taskId: 'task-1',
      ),
      _event(
        id: 'done',
        title: 'Finished reading',
        start: DateTime(2026, 3, 2, 14),
        duration: const Duration(hours: 1),
        status: CalendarEventStatus.completed,
      ),
    ];

    final analysis = analyzer(events, startDate: monday, endDate: tuesday);

    expect(analysis.days.first.isOverloaded, isTrue);
    expect(analysis.suggestions, isEmpty);
  });

  test('merges adjacent events without flagging an overlap', () {
    final events = <CalendarEvent>[
      _event(
        id: 'first',
        title: 'First',
        start: DateTime(2026, 3, 2, 9),
        duration: const Duration(hours: 1),
      ),
      _event(
        id: 'second',
        title: 'Second',
        start: DateTime(2026, 3, 2, 10),
        duration: const Duration(hours: 1),
      ),
    ];

    final analysis = analyzer(events, startDate: monday, endDate: monday);

    final summary = analysis.days.single;
    expect(summary.busy, const Duration(hours: 2));
    expect(summary.overlapCount, 0);
    expect(summary.hasOverlap, isFalse);
    expect(summary.isOverloaded, isFalse);
    expect(summary.peakConcurrency, 1);
  });
}
