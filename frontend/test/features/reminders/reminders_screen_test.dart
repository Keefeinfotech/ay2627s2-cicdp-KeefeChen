import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/routing/app_router.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';
import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/reminders/screens/reminders_screen.dart';

import '../../helpers.dart';

TaskStore _store(List<Task> seed) => TaskStore(
  repository: InMemoryTaskRepository(seed: <String, List<Task>>{'u': seed}),
  ownerId: 'u',
);

Widget _app(Widget child) {
  return MaterialApp(
    routes: {AppRoutes.home: (_) => const Scaffold(body: Text('home'))},
    home: child,
  );
}

void main() {
  testWidgets('shows safe empty state when no store is provided', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const RemindersScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Reminders live with your tasks'), findsOneWidget);
    expect(find.text('Go to tasks'), findsOneWidget);

    await tester.tap(find.text('Go to tasks'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('shows empty state when store has no reminders', (tester) async {
    final store = _store([makeTask(id: '1', title: 'No reminder')]);
    await tester.pumpWidget(_app(RemindersScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('No reminders yet'), findsOneWidget);
    await tester.tap(find.text('Go to tasks'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('renders overdue and upcoming reminders', (tester) async {
    final now = DateTime.now();
    final store = _store([
      // ensure loaded

      makeTask(
        id: '1',
        title: 'Overdue task',
        reminderAt: now.subtract(const Duration(days: 1)),
        status: TaskStatus.pending,
      ),
      makeTask(
        id: '2',
        title: 'Upcoming task',
        reminderAt: now.add(const Duration(days: 1)),
        status: TaskStatus.pending,
      ),
      makeTask(
        id: '3',
        title: 'Done task',
        reminderAt: now.add(const Duration(days: 2)),
        status: TaskStatus.completed,
        completedAt: now,
      ),
    ]);
    await store.load();

    await tester.pumpWidget(_app(RemindersScreen(store: store)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Overdue task'), findsOneWidget);
    expect(find.text('Upcoming task'), findsOneWidget);
    expect(find.text('Done task'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });
}
