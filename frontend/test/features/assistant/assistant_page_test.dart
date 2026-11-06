import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/assistant/presentation/pages/assistant_page.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';
import 'package:frontend/features/home/models/task.dart';

import '../../helpers.dart';

Future<TaskStore> _pumpAssistant(
  WidgetTester tester, {
  List<Task> seed = const <Task>[],
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final repository = InMemoryTaskRepository(
    seed: <String, List<Task>>{'owner': seed},
  );
  final store = TaskStore(repository: repository, ownerId: 'owner');
  await store.load();

  await tester.pumpWidget(
    MaterialApp(
      theme: AuxiliaTheme.light(),
      home: AssistantPage(ownerId: 'owner', store: store),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Future<void> _send(WidgetTester tester, String message) async {
  await tester.enterText(find.byType(TextField), message);
  await tester.tap(find.byTooltip('Send message'));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the exact quick prompts and sign-in hint', (tester) async {
    await _pumpAssistant(tester);

    expect(find.text('How can I help?'), findsOneWidget);
    expect(find.byTooltip('Start voice input'), findsOneWidget);
    for (final prompt in <String>[
      'What should I work on today?',
      'Create a task',
      'Plan my week',
      'Summarise my progress',
      'Break down a project',
    ]) {
      expect(find.widgetWithText(ActionChip, prompt), findsOneWidget);
    }
    expect(
      find.text('Sign in for AI replies. Local task previews still work.'),
      findsOneWidget,
    );
  });

  testWidgets('creates a task after an explicit confirmation', (tester) async {
    final store = await _pumpAssistant(tester);

    await tester.tap(find.widgetWithText(ActionChip, 'Create a task'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tell me what the task is'), findsOneWidget);

    await _send(tester, 'Revise calculus tomorrow high priority');

    expect(find.text('Create task'), findsOneWidget);
    expect(find.text('AI-assisted · Review before adding'), findsOneWidget);
    expect(find.text('Revise calculus'), findsOneWidget);
    expect(find.textContaining('Due Tomorrow'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(store.tasks, isEmpty, reason: 'nothing is saved before approval');

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(store.tasks, hasLength(1));
    final task = store.tasks.single;
    expect(task.title, 'Revise calculus');
    expect(task.priority, TaskPriority.high);
    expect(task.dueDate, isNotNull);
    expect(find.text('Task created: Revise calculus.'), findsOneWidget);
    expect(find.text('Applied'), findsOneWidget);
    expect(find.text('This change has been applied.'), findsOneWidget);
  });

  testWidgets('cancelling a preview leaves tasks untouched', (tester) async {
    final store = await _pumpAssistant(tester);

    await _send(tester, 'Create a task to buy milk');
    expect(find.text('Buy milk'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(store.tasks, isEmpty);
    expect(find.text('Cancelled. Nothing was changed.'), findsOneWidget);
    expect(find.text('No changes were made.'), findsOneWidget);
    expect(find.text('Confirm'), findsNothing);
  });

  testWidgets('lets the user edit a draft before confirming it', (
    tester,
  ) async {
    final store = await _pumpAssistant(tester);
    await _send(tester, 'Create a task to buy milk');

    await tester.tap(find.text('Edit draft'));
    await tester.pumpAndSettle();
    final titleField = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        )
        .first;
    await tester.enterText(titleField, 'Buy oat milk');
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();

    expect(find.text('Buy oat milk'), findsOneWidget);
    expect(store.tasks, isEmpty);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(store.tasks.single.title, 'Buy oat milk');
  });

  testWidgets('updates a matched task only after confirmation', (tester) async {
    final store = await _pumpAssistant(
      tester,
      seed: <Task>[
        makeTask(
          id: 'calculus',
          title: 'Revise calculus',
          priority: TaskPriority.low,
        ),
      ],
    );

    await _send(tester, 'Update task Revise calculus tomorrow high priority');

    expect(find.text('Update task'), findsOneWidget);
    expect(find.text('Current title: Revise calculus'), findsOneWidget);
    expect(store.tasks.single.priority, TaskPriority.low);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(store.tasks.single.priority, TaskPriority.high);
    expect(store.tasks.single.dueDate, isNotNull);
    expect(find.text('Task updated: Revise calculus.'), findsOneWidget);
  });

  testWidgets('deletes a matched task and offers undo', (tester) async {
    final store = await _pumpAssistant(
      tester,
      seed: <Task>[makeTask(id: 'old-note', title: 'Old note')],
    );

    await _send(tester, 'Delete task Old note');
    expect(find.text('Delete task'), findsOneWidget);
    expect(store.tasks, hasLength(1));

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(store.tasks, isEmpty);
    expect(find.text('Task deleted: Old note.'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(store.tasks, hasLength(1));
    expect(store.tasks.single.title, 'Old note');
    expect(find.text('Task restored.'), findsOneWidget);
  });

  testWidgets('asks for clarification instead of updating an ambiguous match', (
    tester,
  ) async {
    final store = await _pumpAssistant(
      tester,
      seed: <Task>[
        makeTask(id: 'calc-1', title: 'Revise calculus chapter 1'),
        makeTask(id: 'calc-2', title: 'Revise calculus chapter 2'),
      ],
    );

    await _send(tester, 'Update task calculus tomorrow high priority');

    expect(find.textContaining('several matching tasks'), findsOneWidget);
    expect(find.text('Confirm'), findsNothing);
    expect(store.tasks, hasLength(2));
    expect(
      store.tasks.every((task) => task.priority == TaskPriority.medium),
      isTrue,
    );
  });
}
