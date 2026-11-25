import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/calendar/data/models/calendar_event.dart';

void main() {
  test('CalendarEvent basics, copyWith, overlaps, json', () {
    final start = DateTime(2026, 1, 1, 9);
    final end = DateTime(2026, 1, 1, 10);
    final e = CalendarEvent(
      id: '1',
      title: 'Meet',
      startTime: start,
      endTime: end,
      description: 'd',
      isAllDay: false,
      priority: CalendarEventPriority.high,
      status: CalendarEventStatus.scheduled,
      location: 'Room',
      groupId: 'g',
      taskId: 't',
    );
    expect(e.duration, const Duration(hours: 1));
    expect(e.isCompleted, false);
    expect(e.isCancelled, false);
    expect(
      e.overlaps(
        CalendarEvent(
          id: '2',
          title: 'X',
          startTime: DateTime(2026, 1, 1, 9, 30),
          endTime: DateTime(2026, 1, 1, 10, 30),
        ),
      ),
      true,
    );
    expect(
      e.overlaps(
        CalendarEvent(
          id: '3',
          title: 'Y',
          startTime: DateTime(2026, 1, 1, 10),
          endTime: DateTime(2026, 1, 1, 11),
        ),
      ),
      false,
    );

    final c = e.copyWith(
      title: 'New',
      status: CalendarEventStatus.completed,
      location: null,
      groupId: null,
      taskId: null,
    );
    expect(c.title, 'New');
    expect(c.isCompleted, true);
    expect(c.location, null);

    final json = e.toCreateJson();
    expect(json['title'], 'Meet');
    expect(json['priority'], 'HIGH');

    final parsed = CalendarEvent.tryFromJson({
      '_id': '1',
      'title': 'Meet',
      'startTime': start.toUtc().toIso8601String(),
      'endTime': end.toUtc().toIso8601String(),
      'isAllDay': true,
      'priority': 'URGENT',
      'status': 'CANCELLED',
      'location': 'L',
      'groupId': 'g',
      'taskId': 't',
      'description': 'desc',
    });
    expect(parsed, isNotNull);
    expect(parsed!.isCancelled, true);
    expect(parsed.isAllDay, true);
    expect(CalendarEvent.tryFromJson({'id': '1'}), isNull);

    final fromTask = calendarEventFromTask(
      id: 't1',
      title: 'Task',
      dueDate: start,
      project: 'P',
    );
    expect(fromTask.taskId, 't1');
    expect(fromTask.location, 'P');
  });

  test('priority/status labels', () {
    expect(CalendarEventPriority.low.label, 'Low');
    expect(CalendarEventPriority.medium.label, 'Medium');
    expect(CalendarEventPriority.high.label, 'High');
    expect(CalendarEventPriority.urgent.label, 'Urgent');
    expect(
      CalendarEventStatusLabel.fromName('COMPLETED'),
      CalendarEventStatus.completed,
    );
    expect(
      CalendarEventStatusLabel.fromName('CANCELLED'),
      CalendarEventStatus.cancelled,
    );
    expect(
      CalendarEventStatusLabel.fromName('anything'),
      CalendarEventStatus.scheduled,
    );
    expect(
      CalendarEventPriorityLabel.fromName('LOW'),
      CalendarEventPriority.low,
    );
    expect(
      CalendarEventPriorityLabel.fromName('HIGH'),
      CalendarEventPriority.high,
    );
    expect(
      CalendarEventPriorityLabel.fromName('URGENT'),
      CalendarEventPriority.urgent,
    );
    expect(
      CalendarEventPriorityLabel.fromName('x'),
      CalendarEventPriority.medium,
    );
  });
}
