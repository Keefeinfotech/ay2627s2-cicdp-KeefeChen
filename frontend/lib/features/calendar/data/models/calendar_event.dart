enum CalendarEventPriority { low, medium, high, urgent }

enum CalendarEventStatus { scheduled, completed, cancelled }

extension CalendarEventPriorityLabel on CalendarEventPriority {
  String get label => switch (this) {
    CalendarEventPriority.low => 'Low',
    CalendarEventPriority.medium => 'Medium',
    CalendarEventPriority.high => 'High',
    CalendarEventPriority.urgent => 'Urgent',
  };

  static CalendarEventPriority fromName(Object? value) {
    final normalized = value?.toString().toUpperCase();
    return switch (normalized) {
      'LOW' => CalendarEventPriority.low,
      'HIGH' => CalendarEventPriority.high,
      'URGENT' => CalendarEventPriority.urgent,
      _ => CalendarEventPriority.medium,
    };
  }
}

extension CalendarEventStatusLabel on CalendarEventStatus {
  String get label => switch (this) {
    CalendarEventStatus.scheduled => 'Scheduled',
    CalendarEventStatus.completed => 'Completed',
    CalendarEventStatus.cancelled => 'Cancelled',
  };

  static CalendarEventStatus fromName(Object? value) {
    final normalized = value?.toString().toUpperCase();
    return switch (normalized) {
      'COMPLETED' => CalendarEventStatus.completed,
      'CANCELLED' => CalendarEventStatus.cancelled,
      _ => CalendarEventStatus.scheduled,
    };
  }
}

/// Mirrors the backend `CalendarEvent` contract.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.description = '',
    this.isAllDay = false,
    this.priority = CalendarEventPriority.medium,
    this.status = CalendarEventStatus.scheduled,
    this.location,
    this.groupId,
    this.taskId,
  });

  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final CalendarEventPriority priority;
  final CalendarEventStatus status;
  final String? location;
  final String? groupId;
  final String? taskId;

  Duration get duration => endTime.difference(startTime);

  bool get isCompleted => status == CalendarEventStatus.completed;

  bool get isCancelled => status == CalendarEventStatus.cancelled;

  bool overlaps(CalendarEvent other) {
    return startTime.isBefore(other.endTime) &&
        other.startTime.isBefore(endTime);
  }

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    CalendarEventPriority? priority,
    CalendarEventStatus? status,
    Object? location = _unset,
    Object? groupId = _unset,
    Object? taskId = _unset,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      location: identical(location, _unset)
          ? this.location
          : location as String?,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
      taskId: identical(taskId, _unset) ? this.taskId : taskId as String?,
    );
  }

  static const Object _unset = Object();

  static CalendarEvent? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.map<String, dynamic>(
      (key, value) => MapEntry('$key', value),
    );
    final id = map['_id'] ?? map['id'];
    final title = map['title'];
    final start = DateTime.tryParse('${map['startTime'] ?? ''}');
    final end = DateTime.tryParse('${map['endTime'] ?? ''}');
    if (id == null || title is! String || title.trim().isEmpty) return null;
    if (start == null || end == null || !end.isAfter(start)) return null;

    return CalendarEvent(
      id: '$id',
      title: title.trim(),
      description: map['description'] is String
          ? map['description'] as String
          : '',
      startTime: start.toLocal(),
      endTime: end.toLocal(),
      isAllDay: map['isAllDay'] == true,
      priority: CalendarEventPriorityLabel.fromName(map['priority']),
      status: CalendarEventStatusLabel.fromName(map['status']),
      location: map['location'] is String ? map['location'] as String : null,
      groupId: map['groupId']?.toString(),
      taskId: map['taskId']?.toString(),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return <String, dynamic>{
      'title': title,
      'description': description,
      'startTime': startTime.toUtc().toIso8601String(),
      'endTime': endTime.toUtc().toIso8601String(),
      'isAllDay': isAllDay,
      'priority': priority.name.toUpperCase(),
      if (location != null && location!.isNotEmpty) 'location': location,
      if (groupId != null) 'groupId': groupId,
      if (taskId != null) 'taskId': taskId,
    };
  }
}

/// Calendar event created from a task's due date when the API is unavailable.
CalendarEvent calendarEventFromTask({
  required String id,
  required String title,
  required DateTime dueDate,
  String? project,
}) {
  return CalendarEvent(
    id: 'task-$id',
    title: title,
    startTime: dueDate,
    endTime: dueDate.add(const Duration(minutes: 45)),
    priority: CalendarEventPriority.medium,
    location: project == null || project.isEmpty ? null : project,
    taskId: id,
  );
}
