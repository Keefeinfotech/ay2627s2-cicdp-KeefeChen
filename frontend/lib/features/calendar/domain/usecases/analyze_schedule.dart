import '../../data/models/calendar_event.dart';

/// One calendar day with its events and workload indicators.
class CalendarDaySummary {
  const CalendarDaySummary({
    required this.date,
    required this.events,
    required this.busy,
    required this.overlapCount,
    required this.peakConcurrency,
  });

  final DateTime date;
  final List<CalendarEvent> events;
  final Duration busy;
  final int overlapCount;
  final int peakConcurrency;

  bool get hasOverlap => overlapCount > 0;

  bool get isOverloaded => busy.inMinutes > 300 || overlapCount > 0;

  String get busyLabel {
    final minutes = busy.inMinutes;
    if (minutes < 60) return '$minutes min';
    final hours = minutes / 60;
    return hours == hours.roundToDouble()
        ? '${hours.round()} hr'
        : '${hours.toStringAsFixed(1)} hr';
  }
}

/// A pair of events that occupy the same time.
class CalendarOverlap {
  const CalendarOverlap({required this.first, required this.second});

  final CalendarEvent first;
  final CalendarEvent second;
}

/// A workload re-balancing recommendation produced locally.
class ScheduleSuggestion {
  const ScheduleSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.day,
    this.event,
    this.suggestedStart,
  });

  final String id;
  final String title;
  final String description;
  final DateTime day;
  final CalendarEvent? event;
  final DateTime? suggestedStart;
}

class ScheduleAnalysis {
  const ScheduleAnalysis({
    required this.days,
    required this.overlaps,
    required this.suggestions,
  });

  final List<CalendarDaySummary> days;
  final List<CalendarOverlap> overlaps;
  final List<ScheduleSuggestion> suggestions;

  int get overloadedDayCount => days.where((day) => day.isOverloaded).length;

  int get busyMinutes =>
      days.fold<int>(0, (total, day) => total + day.busy.inMinutes);

  List<CalendarEvent> eventsOn(DateTime date) {
    final target = _dateOnly(date);
    for (final day in days) {
      if (_sameDate(day.date, target)) return day.events;
    }
    return const <CalendarEvent>[];
  }

  CalendarDaySummary dayFor(DateTime date) {
    final target = _dateOnly(date);
    for (final day in days) {
      if (_sameDate(day.date, target)) return day;
    }
    return CalendarDaySummary(
      date: target,
      events: const <CalendarEvent>[],
      busy: Duration.zero,
      overlapCount: 0,
      peakConcurrency: 0,
    );
  }
}

/// Deterministic schedule analysis so the calendar can explain workload,
/// overlaps and a sensible re-balancing plan without a network round-trip.
class AnalyzeSchedule {
  const AnalyzeSchedule({this.dailyCapacityMinutes = 300});

  /// Work above five hours is treated as an overloaded day.
  final int dailyCapacityMinutes;

  ScheduleAnalysis call(
    List<CalendarEvent> events, {
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    final days = <CalendarDaySummary>[];
    final overlaps = <CalendarOverlap>[];
    final suggestions = <ScheduleSuggestion>[];

    var cursor = start;
    while (!cursor.isAfter(end)) {
      final dayEvents =
          events
              .where(
                (event) =>
                    !event.isCancelled && _sameDate(event.startTime, cursor),
              )
              .toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));

      final dayOverlaps = <CalendarOverlap>[];
      var peak = 0;
      for (var index = 0; index < dayEvents.length; index++) {
        var concurrency = 1;
        for (var other = index + 1; other < dayEvents.length; other++) {
          if (dayEvents[index].overlaps(dayEvents[other])) {
            dayOverlaps.add(
              CalendarOverlap(
                first: dayEvents[index],
                second: dayEvents[other],
              ),
            );
            concurrency += 1;
          }
        }
        if (concurrency > peak) peak = concurrency;
      }

      final busy = _unionDuration(dayEvents);
      final summary = CalendarDaySummary(
        date: cursor,
        events: dayEvents,
        busy: busy,
        overlapCount: dayOverlaps.length,
        peakConcurrency: peak,
      );
      days.add(summary);
      overlaps.addAll(dayOverlaps);

      cursor = cursor.add(const Duration(days: 1));
    }

    for (final day in days.where((day) => day.isOverloaded)) {
      final suggestion = _suggestionFor(day, days);
      if (suggestion != null) suggestions.add(suggestion);
    }

    return ScheduleAnalysis(
      days: days,
      overlaps: overlaps,
      suggestions: suggestions,
    );
  }

  ScheduleSuggestion? _suggestionFor(
    CalendarDaySummary day,
    List<CalendarDaySummary> allDays,
  ) {
    if (day.events.isEmpty) return null;

    if (day.hasOverlap) {
      final overlap = _firstOverlap(day.events);
      if (overlap != null) {
        return ScheduleSuggestion(
          id: 'overlap-${overlap.second.id}',
          title: 'Resolve overlap: ${overlap.second.title}',
          description:
              '“${overlap.first.title}” and “${overlap.second.title}” share '
              'the same time. Move the second event to '
              '${_timeLabel(overlap.first.endTime)}.',
          day: day.date,
          event: overlap.second,
          suggestedStart: overlap.first.endTime,
        );
      }
    }

    final movable =
        day.events
            .where((event) => event.taskId == null && !event.isCompleted)
            .toList()
          ..sort(
            (a, b) =>
                _priorityWeight(a.priority)
                    .compareTo(_priorityWeight(b.priority)),
          );
    if (movable.isEmpty) return null;

    final event = movable.first;
    final nextDay = _lightestDay(allDays, day.date);
    if (nextDay == null) return null;

    return ScheduleSuggestion(
      id: 'move-${event.id}-${nextDay.date.toIso8601String()}',
      title: 'Move “${event.title}”',
      description:
          '${_weekdayLabel(day.date)} carries ${day.busyLabel} of work. '
          'Moving this ${_priorityLabel(event.priority)} priority event to '
          '${_weekdayLabel(nextDay.date)} balances the week.',
      day: day.date,
      event: event,
      suggestedStart: DateTime(
        nextDay.date.year,
        nextDay.date.month,
        nextDay.date.day,
        event.startTime.hour,
        event.startTime.minute,
      ),
    );
  }

  CalendarDaySummary? _lightestDay(
    List<CalendarDaySummary> days,
    DateTime current,
  ) {
    CalendarDaySummary? best;
    for (final day in days) {
      if (!day.date.isAfter(current)) continue;
      if (day.busy.inMinutes >= dailyCapacityMinutes) continue;
      if (best == null || day.busy < best.busy) best = day;
    }
    return best;
  }

  CalendarOverlap? _firstOverlap(List<CalendarEvent> events) {
    for (var index = 0; index < events.length; index++) {
      for (var other = index + 1; other < events.length; other++) {
        if (events[index].overlaps(events[other])) {
          return CalendarOverlap(first: events[index], second: events[other]);
        }
      }
    }
    return null;
  }

  Duration _unionDuration(List<CalendarEvent> events) {
    if (events.isEmpty) return Duration.zero;

    final sorted = events.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    var start = sorted.first.startTime;
    var end = sorted.first.endTime;
    var total = Duration.zero;

    for (final event in sorted.skip(1)) {
      if (event.startTime.isAfter(end)) {
        total += end.difference(start);
        start = event.startTime;
        end = event.endTime;
        continue;
      }
      if (event.endTime.isAfter(end)) end = event.endTime;
    }

    return total + end.difference(start);
  }

  int _priorityWeight(CalendarEventPriority priority) => switch (priority) {
    CalendarEventPriority.low => 0,
    CalendarEventPriority.medium => 1,
    CalendarEventPriority.high => 2,
    CalendarEventPriority.urgent => 3,
  };

  String _priorityLabel(CalendarEventPriority priority) =>
      priority.name.toLowerCase();

  String _weekdayLabel(DateTime date) {
    const weekdays = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return weekdays[date.weekday - 1];
  }

  String _timeLabel(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
