import 'dart:math';

enum TaskPriority { low, medium, high }

extension TaskPriorityLabel on TaskPriority {
  String get label => switch (this) {
    TaskPriority.low => 'Low',
    TaskPriority.medium => 'Medium',
    TaskPriority.high => 'High',
  };

  static TaskPriority fromName(String? name) {
    return TaskPriority.values.firstWhere(
      (value) => value.name == name,
      orElse: () => TaskPriority.medium,
    );
  }
}

enum TaskStatus { pending, completed }

extension TaskStatusLabel on TaskStatus {
  String get label => switch (this) {
    TaskStatus.pending => 'Pending',
    TaskStatus.completed => 'Completed',
  };

  static TaskStatus fromName(String? name) {
    return TaskStatus.values.firstWhere(
      (value) => value.name == name,
      orElse: () => TaskStatus.pending,
    );
  }
}

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.notes,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.course = '',
    this.dueDate,
    this.reminderAt,
    this.completedAt,
    this.xpAwarded = false,
  });

  static const Object _unset = Object();
  static final Random _random = Random();
  static int _sequence = 0;

  final String id;
  final String title;
  final String notes;
  final String course;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime? dueDate;
  final DateTime? reminderAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  /// Set once when a task is first completed and never cleared, so XP cannot be
  /// awarded twice and is never deducted for reopened or overdue tasks.
  final bool xpAwarded;

  bool get isCompleted => status == TaskStatus.completed;

  bool get isOverdue =>
      !isCompleted && dueDate != null && dueDate!.isBefore(DateTime.now());

  factory Task.create({
    required String title,
    String notes = '',
    String course = '',
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
    DateTime? reminderAt,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return Task(
      id: _generateId(timestamp),
      title: title.trim(),
      notes: notes.trim(),
      course: course.trim(),
      priority: priority,
      status: TaskStatus.pending,
      dueDate: dueDate,
      reminderAt: reminderAt,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  Task copyWith({
    String? title,
    String? notes,
    String? course,
    TaskPriority? priority,
    TaskStatus? status,
    DateTime? updatedAt,
    Object? dueDate = _unset,
    Object? reminderAt = _unset,
    Object? completedAt = _unset,
    bool? xpAwarded,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      course: course ?? this.course,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as DateTime?,
      reminderAt: identical(reminderAt, _unset)
          ? this.reminderAt
          : reminderAt as DateTime?,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      xpAwarded: xpAwarded ?? this.xpAwarded,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'notes': notes,
      'course': course,
      'priority': priority.name,
      'status': status.name,
      'dueDate': dueDate?.toUtc().toIso8601String(),
      'reminderAt': reminderAt?.toUtc().toIso8601String(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'completedAt': completedAt?.toUtc().toIso8601String(),
      'xpAwarded': xpAwarded,
    };
  }

  /// Returns null instead of throwing so a single corrupt local record cannot
  /// prevent the rest of the task list from loading.
  static Task? tryFromJson(Object? raw) {
    if (raw is! Map) return null;

    final id = raw['id'];
    final title = raw['title'];
    final createdAt = raw['createdAt'];
    final updatedAt = raw['updatedAt'];

    if (id is! String || id.isEmpty) return null;
    if (title is! String || title.trim().isEmpty) return null;
    if (createdAt is! String || DateTime.tryParse(createdAt) == null) {
      return null;
    }
    if (updatedAt is! String || DateTime.tryParse(updatedAt) == null) {
      return null;
    }

    return Task(
      id: id,
      title: title.trim(),
      notes: raw['notes'] is String ? raw['notes'] as String : '',
      course: raw['course'] is String ? (raw['course'] as String).trim() : '',
      priority: TaskPriorityLabel.fromName(raw['priority'] as String?),
      status: TaskStatusLabel.fromName(raw['status'] as String?),
      dueDate: _parseDate(raw['dueDate']),
      reminderAt: _parseDate(raw['reminderAt']),
      createdAt: DateTime.parse(createdAt).toLocal(),
      updatedAt: DateTime.parse(updatedAt).toLocal(),
      completedAt: _parseDate(raw['completedAt']),
      xpAwarded: raw['xpAwarded'] == true,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  static String _generateId(DateTime timestamp) {
    final sequence = (_sequence++).toRadixString(36);
    final random = _random.nextInt(0x7fffffff).toRadixString(36);
    return '${timestamp.microsecondsSinceEpoch}-$sequence-$random';
  }

  @override
  String toString() => 'Task(id: $id, title: $title, status: ${status.name})';
}

/// User-editable task fields, used by the editor and by validation.
class TaskDraft {
  const TaskDraft({
    required this.title,
    this.notes = '',
    this.course = '',
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.reminderAt,
  });

  final String title;
  final String notes;
  final String course;
  final TaskPriority priority;
  final DateTime? dueDate;
  final DateTime? reminderAt;

  TaskDraft copyWith({
    String? title,
    String? notes,
    String? course,
    TaskPriority? priority,
    Object? dueDate = Task._unset,
    Object? reminderAt = Task._unset,
  }) {
    return TaskDraft(
      title: title ?? this.title,
      notes: notes ?? this.notes,
      course: course ?? this.course,
      priority: priority ?? this.priority,
      dueDate: identical(dueDate, Task._unset)
          ? this.dueDate
          : dueDate as DateTime?,
      reminderAt: identical(reminderAt, Task._unset)
          ? this.reminderAt
          : reminderAt as DateTime?,
    );
  }
}
