import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/home/widgets/task_card.dart';

import '../helpers.dart';

void main() {
  testWidgets('shows the task title, priority and due date', (tester) async {
    final task = makeTask(
      title: 'Submit report',
      priority: TaskPriority.high,
      dueDate: DateTime.now().add(const Duration(days: 2)),
    );

    await tester.pumpWidget(
      wrapApp(
        Scaffold(
          body: TaskCard(
            task: task,
            onToggle: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('Submit report'), findsOneWidget);
    expect(find.text('High priority'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.textContaining('Due '), findsOneWidget);
  });

  testWidgets('shows the course label when provided', (tester) async {
    final task = makeTask(title: 'Lab report', course: 'COMP 2101');

    await tester.pumpWidget(
      wrapApp(
        Scaffold(
          body: TaskCard(task: task, onToggle: () {}),
        ),
      ),
    );

    expect(find.text('COMP 2101'), findsOneWidget);
    expect(find.byIcon(Icons.school_outlined), findsOneWidget);
  });

  testWidgets('marks overdue pending tasks without relying on colour', (
    tester,
  ) async {
    final task = makeTask(
      title: 'Late task',
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
    );

    await tester.pumpWidget(
      wrapApp(
        Scaffold(
          body: TaskCard(task: task, onToggle: () {}),
        ),
      ),
    );

    expect(find.text('Overdue'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('shows a completed task as completed', (tester) async {
    final task = makeTask(
      title: 'Finished',
      status: TaskStatus.completed,
      completedAt: DateTime(2026, 1, 1),
      xpAwarded: true,
    );

    await tester.pumpWidget(
      wrapApp(
        Scaffold(
          body: TaskCard(task: task, onToggle: () {}),
        ),
      ),
    );

    expect(find.text('Completed'), findsOneWidget);
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
  });

  testWidgets('invokes callbacks from the checkbox and action buttons', (
    tester,
  ) async {
    var toggled = 0;
    var edited = 0;
    var deleted = 0;
    final task = makeTask(title: 'Interact');

    await tester.pumpWidget(
      wrapApp(
        Scaffold(
          body: TaskCard(
            task: task,
            onToggle: () => toggled++,
            onEdit: () => edited++,
            onDelete: () => deleted++,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.byTooltip('Edit Interact'));
    await tester.tap(find.byTooltip('Delete Interact'));

    expect(toggled, 1);
    expect(edited, 1);
    expect(deleted, 1);
  });

  testWidgets('exposes a descriptive semantics label', (tester) async {
    final handle = tester.ensureSemantics();
    final task = makeTask(
      title: 'Accessible task',
      priority: TaskPriority.high,
      dueDate: DateTime(2026, 12, 1, 9),
    );

    await tester.pumpWidget(
      wrapApp(
        Scaffold(
          body: TaskCard(task: task, onToggle: () {}),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp('Task: Accessible task')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Mark Accessible task as complete'),
      findsOneWidget,
    );

    handle.dispose();
  });
}
