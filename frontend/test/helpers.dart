import 'package:flutter/material.dart';

import 'package:frontend/features/home/models/task.dart';

Task makeTask({
  String id = 'task-1',
  String title = 'Write report',
  String notes = '',
  String course = '',
  List<String> tags = const <String>[],
  String? groupId,
  String? assigneeId,
  String? assigneeName,
  TaskPriority priority = TaskPriority.medium,
  TaskStatus status = TaskStatus.pending,
  DateTime? dueDate,
  DateTime? reminderAt,
  DateTime? completedAt,
  DateTime? createdAt,
  DateTime? updatedAt,
  bool xpAwarded = false,
}) {
  return Task(
    id: id,
    title: title,
    notes: notes,
    course: course,
    tags: tags,
    groupId: groupId,
    assigneeId: assigneeId,
    assigneeName: assigneeName,
    priority: priority,
    status: status,
    dueDate: dueDate,
    reminderAt: reminderAt,
    createdAt: createdAt ?? DateTime(2026, 1, 1, 9),
    updatedAt: updatedAt ?? DateTime(2026, 1, 1, 9),
    completedAt: completedAt,
    xpAwarded: xpAwarded,
  );
}

Widget wrapApp(Widget child, {TextScaler? textScaler}) {
  return MaterialApp(
    home: child,
    builder: textScaler == null
        ? null
        : (context, widget) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(textScaler: textScaler),
              child: widget ?? const SizedBox.shrink(),
            );
          },
  );
}
