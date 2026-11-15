import '../../../../core/network/api_client.dart';
import '../../../home/data/task_store.dart';
import '../../../home/models/task.dart';
import '../datasources/calendar_api_data_source.dart';
import '../models/calendar_event.dart';

/// Result of loading a calendar range.
class CalendarLoadResult {
  const CalendarLoadResult({
    required this.events,
    this.isRemote = false,
    this.warning,
  });

  final List<CalendarEvent> events;
  final bool isRemote;
  final String? warning;
}

/// Result of writing one event.
class CalendarWriteResult {
  const CalendarWriteResult({
    required this.event,
    this.synced = false,
    this.warning,
  });

  final CalendarEvent event;
  final bool synced;
  final String? warning;
}

/// Calendar repository that combines the backend calendar with local,
/// task-derived events.
///
/// Tasks remain offline-first. When the user is signed in the repository asks
/// the backend for the visible range and merges those events with local task
/// deadlines. If the API is unavailable, local events are still shown instead
/// of replacing the screen with a hard failure.
class CalendarRepository {
  CalendarRepository({required this._store, CalendarApiDataSource? api})
    : _api = api ?? CalendarApiDataSource();

  final TaskStore _store;
  final CalendarApiDataSource _api;
  final Map<String, CalendarEvent> _localEvents = <String, CalendarEvent>{};
  final Map<String, CalendarEvent> _movedEvents = <String, CalendarEvent>{};

  /// Optimistically repositions an event on the device.
  ///
  /// This powers the schedule optimization preview without inventing a backend
  /// update contract. The original event is hidden while the preview is active.
  CalendarWriteResult applyLocalMove(CalendarEvent event, DateTime newStart) {
    final duration = event.duration;
    final moved = event.copyWith(
      id: 'moved-${event.id}',
      startTime: newStart,
      endTime: newStart.add(duration),
      status: CalendarEventStatus.scheduled,
    );
    _movedEvents[event.id] = moved;
    return CalendarWriteResult(
      event: moved,
      warning: 'Schedule preview updated on this device.',
    );
  }

  Future<CalendarLoadResult> loadEvents({
    required DateTime startDate,
    required DateTime endDate,
    String? groupId,
    String? token,
  }) async {
    final local = _localEventsInRange(startDate, endDate, groupId);

    if (token == null || token.isEmpty) {
      return CalendarLoadResult(events: local);
    }

    try {
      final remote = await _api.fetchEvents(
        token: token,
        startDate: startDate,
        endDate: endDate,
        groupId: _remoteGroupId(groupId),
      );
      return CalendarLoadResult(events: _merge(remote, local), isRemote: true);
    } on ApiException catch (err) {
      return CalendarLoadResult(
        events: local,
        warning: err.isUnauthorized
            ? 'Your session expired. Showing tasks saved on this device.'
            : '${err.message} Showing tasks saved on this device.',
      );
    } catch (_) {
      return CalendarLoadResult(
        events: local,
        warning: 'The calendar could not be refreshed. Showing local tasks.',
      );
    }
  }

  Future<CalendarWriteResult> createEvent({
    required CalendarEvent event,
    String? token,
  }) async {
    if (token != null && token.isNotEmpty) {
      try {
        final created = await _api.createEvent(token: token, event: event);
        _localEvents[created.id] = created;
        return CalendarWriteResult(event: created, synced: true);
      } on ApiException catch (err) {
        return _createLocally(
          event,
          warning: err.isUnauthorized
              ? 'Session expired. The event was saved on this device only.'
              : '${err.message} The event was saved on this device only.',
        );
      } catch (_) {
        return _createLocally(
          event,
          warning: 'The event was saved on this device only.',
        );
      }
    }

    return _createLocally(event);
  }

  Future<List<CalendarEvent>> checkConflicts({
    required DateTime startTime,
    required DateTime endTime,
    String? token,
    String? excludeId,
  }) async {
    if (token == null || token.isEmpty) return const <CalendarEvent>[];

    try {
      return await _api.checkConflicts(
        token: token,
        startTime: startTime,
        endTime: endTime,
        excludeId: excludeId,
      );
    } catch (_) {
      return const <CalendarEvent>[];
    }
  }

  void removeLocalEvent(String id) {
    _localEvents.remove(id);
  }

  List<String> get projects {
    final values = <String>{
      for (final task in _store.tasks)
        if (task.course.trim().isNotEmpty) task.course.trim(),
      for (final event in _localEvents.values)
        if (event.groupId?.trim().isNotEmpty == true) event.groupId!.trim(),
    };
    final sorted = values.toList()..sort();
    return sorted;
  }

  CalendarWriteResult _createLocally(CalendarEvent event, {String? warning}) {
    final local = CalendarEvent(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      title: event.title,
      description: event.description,
      startTime: event.startTime,
      endTime: event.endTime,
      isAllDay: event.isAllDay,
      priority: event.priority,
      status: event.status,
      location: event.location,
      groupId: event.groupId,
      taskId: event.taskId,
    );
    _localEvents[local.id] = local;
    return CalendarWriteResult(event: local, warning: warning);
  }

  List<CalendarEvent> _localEventsInRange(
    DateTime start,
    DateTime end,
    String? groupId,
  ) {
    final events = <CalendarEvent>[
      for (final task in _store.tasks)
        if (task.dueDate != null)
          ..._taskEvents(task).where(
            (event) =>
                event.endTime.isAfter(start) &&
                event.startTime.isBefore(end) &&
                _matchesGroup(event, groupId) &&
                !_movedEvents.containsKey(event.id),
          ),
      for (final event in _localEvents.values)
        if (event.endTime.isAfter(start) &&
            event.startTime.isBefore(end) &&
            _matchesGroup(event, groupId) &&
            !_movedEvents.containsKey(event.id))
          event,
      for (final event in _movedEvents.values)
        if (event.endTime.isAfter(start) &&
            event.startTime.isBefore(end) &&
            _matchesGroup(event, groupId))
          event,
    ];
    events.sort((a, b) => a.startTime.compareTo(b.startTime));
    return events;
  }

  Iterable<CalendarEvent> _taskEvents(Task task) sync* {
    final due = task.dueDate;
    if (due == null) {
      return;
    }

    if (task.isCompleted) {
      yield CalendarEvent(
        id: 'task-${task.id}',
        title: task.title,
        description: task.notes,
        startTime: due,
        endTime: due.add(const Duration(minutes: 45)),
        priority: _priorityForTask(task),
        status: CalendarEventStatus.completed,
        location: task.course.isEmpty ? null : task.course,
        groupId: task.course.isEmpty ? null : task.course,
        taskId: task.id,
      );
      return;
    }

    yield calendarEventFromTask(
      id: task.id,
      title: task.title,
      dueDate: due,
      project: task.course,
    ).copyWith(
      description: task.notes,
      priority: _priorityForTask(task),
      status: CalendarEventStatus.scheduled,
    );
  }

  CalendarEventPriority _priorityForTask(Task task) {
    return switch (task.priority) {
      TaskPriority.low => CalendarEventPriority.low,
      TaskPriority.medium => CalendarEventPriority.medium,
      TaskPriority.high => CalendarEventPriority.high,
    };
  }

  bool _matchesGroup(CalendarEvent event, String? groupId) {
    if (groupId == null || groupId.isEmpty) return true;
    return event.groupId == groupId || event.location == groupId;
  }

  String? _remoteGroupId(String? groupId) {
    if (groupId == null) return null;
    final isMongoId = RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(groupId);
    return isMongoId ? groupId : null;
  }

  List<CalendarEvent> _merge(
    List<CalendarEvent> remote,
    List<CalendarEvent> local,
  ) {
    final byId = <String, CalendarEvent>{
      for (final event in remote) event.id: event,
      for (final event in local) event.id: event,
    };
    final merged = byId.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return merged;
  }
}
