import '../models/task.dart';

/// Converts between the local task model and the backend task contract.
///
/// Keeping the mapping in one place means the offline queue and the online
/// repository cannot drift apart as fields are added.
abstract final class TaskApiMapper {
  static Task? fromApi(Object? raw) {
    if (raw is! Map) return null;
    return Task.tryFromBackend(raw.cast<String, dynamic>());
  }

  static List<Task> listFromApi(Object? raw) {
    if (raw is! List) return const <Task>[];
    return raw
        .map((item) => fromApi(item))
        .whereType<Task>()
        .toList(growable: false);
  }

  static Map<String, dynamic> toCreateJson(Task task) => <String, dynamic>{
    'id': task.id,
    'title': task.title,
    'description': task.notes.isEmpty ? null : task.notes,
    'course': task.course,
    'tags': task.tags,
    'groupId': task.groupId,
    'assigneeId': task.assigneeId,
    'assigneeName': task.assigneeName,
    'reminderAt': task.reminderAt?.toUtc().toIso8601String(),
    'priority': priorityName(task.priority),
    'dueDate': task.dueDate?.toUtc().toIso8601String(),
  };

  static Map<String, dynamic> toUpdateJson(Task task) => <String, dynamic>{
    'title': task.title,
    'description': task.notes.isEmpty ? null : task.notes,
    'course': task.course,
    'tags': task.tags,
    'groupId': task.groupId,
    'assigneeId': task.assigneeId,
    'assigneeName': task.assigneeName,
    'reminderAt': task.reminderAt?.toUtc().toIso8601String(),
    'priority': priorityName(task.priority),
    'status': task.isCompleted ? 'completed' : 'todo',
    'dueDate': task.dueDate?.toUtc().toIso8601String(),
  };

  static String priorityName(TaskPriority priority) => switch (priority) {
    TaskPriority.low => 'low',
    TaskPriority.medium => 'medium',
    TaskPriority.high => 'high',
  };
}
