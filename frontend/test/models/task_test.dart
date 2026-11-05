import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/home/models/task.dart';

void main() {
  group('Task', () {
    test('creates a pending task with a stable timestamp', () {
      final now = DateTime(2026, 10, 29, 12);
      final task = Task.create(title: '  Buy milk  ', now: now);

      expect(task.title, 'Buy milk');
      expect(task.status, TaskStatus.pending);
      expect(task.priority, TaskPriority.medium);
      expect(task.xpAwarded, isFalse);
      expect(task.createdAt, now);
      expect(task.updatedAt, now);
    });

    test('serialises and restores every field', () {
      final due = DateTime(2026, 11, 2, 14, 30);
      final reminder = DateTime(2026, 11, 2, 10);
      final task = Task.create(title: 'Submit assignment', course: 'COMP 2101')
          .copyWith(
            notes: 'Check references',
            priority: TaskPriority.high,
            dueDate: due,
            reminderAt: reminder,
            status: TaskStatus.completed,
            completedAt: DateTime(2026, 11, 1),
            xpAwarded: true,
          );

      final restored = Task.tryFromJson(task.toJson());

      expect(restored, isNotNull);
      expect(restored!.id, task.id);
      expect(restored.title, task.title);
      expect(restored.notes, task.notes);
      expect(restored.course, 'COMP 2101');
      expect(restored.priority, TaskPriority.high);
      expect(restored.status, TaskStatus.completed);
      expect(restored.dueDate!.isAtSameMomentAs(due), isTrue);
      expect(restored.reminderAt!.isAtSameMomentAs(reminder), isTrue);
      expect(restored.xpAwarded, isTrue);
    });

    test('ignores malformed records instead of throwing', () {
      expect(Task.tryFromJson(null), isNull);
      expect(Task.tryFromJson('not a map'), isNull);
      expect(Task.tryFromJson(<String, dynamic>{}), isNull);
      expect(
        Task.tryFromJson(<String, dynamic>{
          'id': 'x',
          'title': '   ',
          'createdAt': DateTime(2026).toIso8601String(),
          'updatedAt': DateTime(2026).toIso8601String(),
        }),
        isNull,
      );
      expect(
        Task.tryFromJson(<String, dynamic>{
          'id': 'x',
          'title': 'Valid',
          'createdAt': 'not-a-date',
          'updatedAt': DateTime(2026).toIso8601String(),
        }),
        isNull,
      );
    });

    test('falls back to a safe priority for unknown values', () {
      final task = Task.tryFromJson(<String, dynamic>{
        'id': 'x',
        'title': 'Valid',
        'priority': 'urgent',
        'status': 'unknown',
        'createdAt': DateTime(2026).toIso8601String(),
        'updatedAt': DateTime(2026).toIso8601String(),
      });

      expect(task!.priority, TaskPriority.medium);
      expect(task.status, TaskStatus.pending);
    });

    test('can clear optional dates with copyWith', () {
      final task = makeTask(dueDate: DateTime(2026, 11, 1));
      expect(task.copyWith(dueDate: null).dueDate, isNull);
    });

    test('generates unique identifiers', () {
      final ids = <String>{
        for (var i = 0; i < 10000; i++) Task.create(title: 'Task $i').id,
      };
      expect(ids, hasLength(10000));
    });
  });
}

Task makeTask({DateTime? dueDate}) {
  return Task(
    id: 'task-1',
    title: 'Task',
    notes: '',
    priority: TaskPriority.medium,
    status: TaskStatus.pending,
    dueDate: dueDate,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}
