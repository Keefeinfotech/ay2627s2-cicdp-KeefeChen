import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/home/data/task_validation.dart';

void main() {
  group('TaskValidationException', () {
    test('instantiates and formats toString correctly', () {
      final exception = TaskValidationException('Custom error');
      expect(exception.message, 'Custom error');
      expect(exception.toString(), 'Custom error');
    });
  });

  group('validateTitle', () {
    test('returns error for empty or whitespace-only title', () {
      expect(validateTitle(null), 'Enter a task title');
      expect(validateTitle(''), 'Enter a task title');
      expect(validateTitle('   '), 'Enter a task title');
    });

    test('returns error when title exceeds maxTitleLength', () {
      final longTitle = 'a' * (maxTitleLength + 1);
      expect(
        validateTitle(longTitle),
        'Keep the title under $maxTitleLength characters',
      );
    });

    test('returns null for valid titles', () {
      expect(validateTitle('Study for exam'), isNull);
      expect(validateTitle('a' * maxTitleLength), isNull);
    });
  });

  group('validateNotes', () {
    test('returns error when notes exceed maxNotesLength', () {
      final longNotes = 'a' * (maxNotesLength + 1);
      expect(
        validateNotes(longNotes),
        'Keep notes under $maxNotesLength characters',
      );
    });

    test('returns null for valid notes or null/empty values', () {
      expect(validateNotes(null), isNull);
      expect(validateNotes(''), isNull);
      expect(validateNotes('Chapter 1 to 4'), isNull);
      expect(validateNotes('a' * maxNotesLength), isNull);
    });
  });

  group('validateCourse', () {
    test('returns error when course exceeds maxCourseLength', () {
      final longCourse = 'a' * (maxCourseLength + 1);
      expect(
        validateCourse(longCourse),
        'Keep the course under $maxCourseLength characters',
      );
    });

    test('returns null for valid course or null/empty values', () {
      expect(validateCourse(null), isNull);
      expect(validateCourse(''), isNull);
      expect(validateCourse('CS101'), isNull);
      expect(validateCourse('a' * maxCourseLength), isNull);
    });
  });

  group('validateSchedule', () {
    test('returns error when reminder is set without a due date', () {
      final reminder = DateTime.now();
      expect(
        validateSchedule(reminderAt: reminder),
        'Add a due date before setting a reminder',
      );
    });

    test('returns error when reminder is set after due date', () {
      final due = DateTime(2026, 11, 1, 10, 0);
      final reminder = DateTime(2026, 11, 1, 11, 0);
      expect(
        validateSchedule(dueDate: due, reminderAt: reminder),
        'The reminder must be at or before the due date',
      );
    });

    test('returns null when reminder is before or equal to due date', () {
      final due = DateTime(2026, 11, 1, 10, 0);
      final validReminder = DateTime(2026, 11, 1, 9, 0);

      expect(validateSchedule(dueDate: due, reminderAt: validReminder), isNull);
      expect(validateSchedule(dueDate: due, reminderAt: due), isNull);
      expect(validateSchedule(dueDate: due), isNull);
      expect(validateSchedule(), isNull);
    });
  });

  group('validateDraft', () {
    test('returns error string when title is invalid', () {
      const draft = TaskDraft(title: '');
      expect(validateDraft(draft), 'Enter a task title');
    });

    test('returns error string when notes are invalid', () {
      final draft = TaskDraft(
        title: 'Valid Title',
        notes: 'a' * (maxNotesLength + 1),
      );
      expect(
        validateDraft(draft),
        'Keep notes under $maxNotesLength characters',
      );
    });

    test('returns error string when course is invalid', () {
      final draft = TaskDraft(
        title: 'Valid Title',
        course: 'a' * (maxCourseLength + 1),
      );
      expect(
        validateDraft(draft),
        'Keep the course under $maxCourseLength characters',
      );
    });

    test('returns error string when schedule is invalid', () {
      final draft = TaskDraft(title: 'Valid Title', reminderAt: DateTime.now());
      expect(validateDraft(draft), 'Add a due date before setting a reminder');
    });

    test('returns null when draft is completely valid', () {
      final draft = TaskDraft(
        title: 'Finish Assignment',
        notes: 'Read chapter 3',
        course: 'MATH101',
        dueDate: DateTime(2026, 11, 2, 12, 0),
        reminderAt: DateTime(2026, 11, 1, 12, 0),
      );
      expect(validateDraft(draft), isNull);
    });
  });
}
