import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/task_management/domain/usecases/parse_quick_add.dart';

void main() {
  const parser = ParseQuickAdd();
  final DateTime now = DateTime(2026, 3, 4, 10); // Wednesday.

  test('extracts title, priority, project and relative date', () {
    final preview = parser(
      'Submit lab report tomorrow high priority for COMP 2101',
      projects: const <String>['COMP 2101'],
      now: now,
    );

    expect(preview.title, 'Submit lab report');
    expect(preview.priority, TaskPriority.high);
    expect(preview.project, 'COMP 2101');
    expect(preview.dueDate, DateTime(2026, 3, 5, 17));
    expect(preview.originalText, contains('lab report'));
    expect(preview.confidence, greaterThan(0.5));
    expect(preview.isTitleEmpty, isFalse);
  });

  test('removes conversational prefixes', () {
    final preview = parser('Create a task to call the tutor', now: now);

    expect(preview.title, 'call the tutor');
    expect(preview.priority, TaskPriority.medium);
    expect(preview.dueDate, isNull);
    expect(preview.project, isNull);
    expect(preview.confidence, closeTo(0.35, 0.0001));
  });

  test('detects low priority phrases', () {
    final preview = parser('Read a novel someday', now: now);

    expect(preview.title, 'Read a novel');
    expect(preview.priority, TaskPriority.low);
  });

  test('parses weekday dates as the next occurrence', () {
    final preview = parser('Revise calculus Friday', now: now);

    expect(preview.title, 'Revise calculus');
    expect(preview.dueDate, DateTime(2026, 3, 6, 17));
  });

  test('parses offsets such as "in 3 days"', () {
    final preview = parser('Submit essay in 3 days', now: now);

    expect(preview.title, 'Submit essay');
    expect(preview.dueDate, DateTime(2026, 3, 7, 17));
  });

  test('parses numeric dates with a two digit year', () {
    final preview = parser('Pay rent 15/03/26', now: now);

    expect(preview.title, 'Pay rent');
    expect(preview.dueDate, DateTime(2026, 3, 15, 17));
  });

  test('falls back to the original text and clamps confidence', () {
    final preview = parser('   ', now: now);

    expect(preview.title, '');
    expect(preview.isTitleEmpty, isTrue);
    expect(preview.confidence, greaterThanOrEqualTo(0.25));
  });

  test('keeps untouched text and treats it as low confidence', () {
    final preview = parser('Buy milk', now: now);

    expect(preview.title, 'Buy milk');
    expect(preview.dueDate, isNull);
    expect(preview.priority, TaskPriority.medium);
    expect(preview.confidence, 0.25);
  });
}
