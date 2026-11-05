import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/home/data/task_validation.dart';

void main() {
  group('title validation', () {
    test('requires a non-blank title', () {
      expect(validateTitle(null), 'Enter a task title');
      expect(validateTitle(''), 'Enter a task title');
      expect(validateTitle('   '), 'Enter a task title');
    });

    test('accepts a normal title and rejects an oversized one', () {
      expect(validateTitle('Do the laundry'), isNull);
      expect(
        validateTitle('x' * (maxTitleLength + 1)),
        contains('under $maxTitleLength'),
      );
    });
  });

  group('notes validation', () {
    test('rejects notes over the limit', () {
      expect(validateNotes('x' * maxNotesLength), isNull);
      expect(
        validateNotes('x' * (maxNotesLength + 1)),
        contains('under $maxNotesLength'),
      );
    });
  });

  group('course validation', () {
    test('rejects a course over the limit', () {
      expect(validateCourse('COMP 2101'), isNull);
      expect(
        validateCourse('x' * (maxCourseLength + 1)),
        contains('under $maxCourseLength'),
      );
    });
  });

  group('schedule validation', () {
    test('requires a due date when a reminder is set', () {
      expect(
        validateSchedule(reminderAt: DateTime(2026, 1, 1, 9)),
        'Add a due date before setting a reminder',
      );
    });

    test('rejects a reminder after the due date', () {
      expect(
        validateSchedule(
          dueDate: DateTime(2026, 1, 1, 9),
          reminderAt: DateTime(2026, 1, 1, 10),
        ),
        'The reminder must be at or before the due date',
      );
    });

    test('accepts a valid schedule', () {
      expect(
        validateSchedule(
          dueDate: DateTime(2026, 1, 1, 9),
          reminderAt: DateTime(2026, 1, 1, 8),
        ),
        isNull,
      );
    });
  });

  group('draft validation', () {
    test('returns a readable validation error', () {
      expect(
        validateDraft(const TaskDraft(title: '   ')),
        'Enter a task title',
      );
    });

    test('accepts a valid draft', () {
      expect(validateDraft(const TaskDraft(title: 'Valid task')), isNull);
    });
  });
}
