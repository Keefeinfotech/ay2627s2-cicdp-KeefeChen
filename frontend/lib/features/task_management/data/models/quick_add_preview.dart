import '../../../home/models/task.dart';

/// Domain-level aliases keep the task-management feature decoupled from the
/// persistence model while still sharing one source of truth.
typedef TaskEntity = Task;
typedef TaskDraftEntity = TaskDraft;

/// A parsed natural-language task with the fields the quick-add sheet shows as
/// preview tags before creating anything.
class QuickAddPreview {
  const QuickAddPreview({
    required this.title,
    required this.priority,
    required this.dueDate,
    required this.project,
    required this.originalText,
    this.confidence = 0.8,
  });

  final String title;
  final TaskPriority priority;
  final DateTime? dueDate;
  final String? project;
  final String originalText;
  final double confidence;

  bool get isTitleEmpty => title.trim().isEmpty;

  String get priorityLabel => priority.label;

  String get dueLabel {
    final date = dueDate;
    if (date == null) return 'No due date';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final difference = target.difference(today).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference == -1) return 'Yesterday';
    if (difference > 1 && difference < 7) {
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
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  QuickAddPreview copyWith({
    String? title,
    TaskPriority? priority,
    Object? dueDate = _unset,
    Object? project = _unset,
  }) {
    return QuickAddPreview(
      title: title ?? this.title,
      priority: priority ?? this.priority,
      dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as DateTime?,
      project: identical(project, _unset) ? this.project : project as String?,
      originalText: originalText,
      confidence: confidence,
    );
  }

  static const Object _unset = Object();
}
