import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/home/screens/home_screen.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';

import '../helpers.dart';

Future<TaskStore> pumpHome(
  WidgetTester tester, {
  List<Task> seed = const <Task>[],
  bool failOnLoad = false,
  int pageSize = 20,
  double textScale = 1,
}) async {
  final repository = InMemoryTaskRepository(
    seed: <String, List<Task>>{'owner': seed},
  )..failOnLoad = failOnLoad;
  final store = TaskStore(
    repository: repository,
    ownerId: 'owner',
    pageSize: pageSize,
  );

  await tester.pumpWidget(
    wrapApp(
      HomeScreen(ownerId: 'owner', store: store),
      textScaler: textScale == 1 ? null : TextScaler.linear(textScale),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('shows an empty state that explains what to do', (tester) async {
    await pumpHome(tester);

    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.text('Create your first task'), findsOneWidget);
    expect(find.text('Total XP'), findsOneWidget);
    expect(find.text('To do'), findsOneWidget);
  });

  testWidgets('creates a task through the editor', (tester) async {
    final store = await pumpHome(tester);

    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Buy milk');
    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();

    expect(store.tasks, hasLength(1));
    expect(store.tasks.single.title, 'Buy milk');
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.textContaining('Task created'), findsOneWidget);
  });

  testWidgets('shows a validation message for a blank title', (tester) async {
    final store = await pumpHome(tester);

    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create task'));
    await tester.pump();

    expect(find.text('Enter a task title'), findsOneWidget);
    expect(store.tasks, isEmpty);
  });

  testWidgets('completes a task and awards XP once', (tester) async {
    final store = await pumpHome(
      tester,
      seed: <Task>[
        makeTask(title: 'Finish assignment', priority: TaskPriority.high),
      ],
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(store.tasks.single.isCompleted, isTrue);
    expect(store.totalXp, 30);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.textContaining('Task completed'), findsOneWidget);
  });

  testWidgets('confirms before deleting a task', (tester) async {
    final store = await pumpHome(
      tester,
      seed: <Task>[makeTask(title: 'Delete me')],
    );

    await tester.tap(find.byTooltip('Delete Delete me'));
    await tester.pumpAndSettle();

    expect(find.text('Delete task?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(store.tasks, isEmpty);
    expect(find.text('Delete me'), findsNothing);
  });

  testWidgets('undoes a deletion from the snackbar', (tester) async {
    final store = await pumpHome(
      tester,
      seed: <Task>[makeTask(title: 'Delete me')],
    );

    await tester.tap(find.byTooltip('Delete Delete me'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(store.tasks, isEmpty);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(store.tasks, hasLength(1));
    expect(find.text('Delete me'), findsOneWidget);
    expect(find.textContaining('Task restored'), findsOneWidget);
  });

  testWidgets('undoes completion without double-awarding XP', (tester) async {
    final store = await pumpHome(
      tester,
      seed: <Task>[
        makeTask(title: 'Finish assignment', priority: TaskPriority.high),
      ],
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(store.totalXp, 30);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(store.tasks.single.isCompleted, isFalse);
    expect(store.totalXp, 30);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(store.totalXp, 30);
  });

  testWidgets('edits a task and keeps the course tag', (tester) async {
    final store = await pumpHome(
      tester,
      seed: <Task>[makeTask(title: 'Draft essay', course: 'COMP 2101')],
    );

    await tester.tap(find.byTooltip('Edit Draft essay'));
    await tester.pumpAndSettle();

    expect(find.text('Edit task'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'HIST 1050');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(store.tasks.single.course, 'HIST 1050');
    expect(find.text('HIST 1050'), findsOneWidget);
  });

  testWidgets('surfaces overdue and due-today work', (tester) async {
    final now = DateTime.now();
    await pumpHome(
      tester,
      seed: <Task>[
        makeTask(
          id: 'late',
          title: 'Late essay',
          dueDate: now.subtract(const Duration(days: 2)),
        ),
        makeTask(
          id: 'today',
          title: 'Today quiz',
          dueDate: DateTime(now.year, now.month, now.day, 23, 59),
        ),
      ],
    );

    expect(find.text('Overdue (1)'), findsOneWidget);
    expect(find.text('Due today'), findsOneWidget);
    expect(find.text('Late essay'), findsOneWidget);

    await tester.tap(find.text('Overdue (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Late essay'), findsOneWidget);
    expect(find.text('Today quiz'), findsNothing);
  });

  testWidgets('shows a retryable error when loading fails', (tester) async {
    final store = await pumpHome(tester, failOnLoad: true);

    expect(store.error, isNotNull);
    expect(find.textContaining('Simulated read failure'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('paginates long task lists', (tester) async {
    await pumpHome(
      tester,
      pageSize: 10,
      seed: <Task>[
        for (var i = 0; i < 25; i++) makeTask(id: 'task-$i', title: 'Task $i'),
      ],
    );

    expect(find.text('Page 1 of 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();

    expect(find.text('Page 2 of 3'), findsOneWidget);
  });

  testWidgets('filters tasks by status', (tester) async {
    await pumpHome(
      tester,
      seed: <Task>[
        makeTask(id: '1', title: 'Pending task'),
        makeTask(
          id: '2',
          title: 'Finished task',
          status: TaskStatus.completed,
          xpAwarded: true,
        ),
      ],
    );

    await tester.tap(find.text('To do (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Pending task'), findsOneWidget);
    expect(find.text('Finished task'), findsNothing);
  });

  testWidgets('opens the achievements list', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byIcon(Icons.emoji_events_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('First step'), findsOneWidget);
    expect(find.text('Locked'), findsWidgets);
  });

  testWidgets('remains usable at 200% text scaling on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await pumpHome(
      tester,
      textScale: 2,
      seed: <Task>[
        makeTask(
          title: 'A very long task title that should wrap rather than overflow',
          priority: TaskPriority.high,
          dueDate: DateTime(2026, 12, 1, 9),
        ),
      ],
    );

    expect(find.textContaining('A very long task title'), findsOneWidget);
  });
}
