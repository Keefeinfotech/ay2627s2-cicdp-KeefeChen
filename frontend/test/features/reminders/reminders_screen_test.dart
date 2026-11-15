import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';
import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/reminders/screens/reminders_screen.dart';

import '../../helpers.dart';

TaskStore _store(List<Task> tasks) {
  return TaskStore(
    repository: InMemoryTaskRepository(
      seed: <String, List<Task>>{'owner': tasks},
    ),
    ownerId: 'owner',
  );
}

Future<void> _pump(WidgetTester tester, TaskStore store) async {
  await tester.pumpWidget(MaterialApp(home: RemindersScreen(store: store)));
  await tester.pumpAndSettle();
}

void main() {
  group('RemindersScreen', () {
    testWidgets('shows the empty state with an add action when quiet', (
      tester,
    ) async {
      final store = _store(<Task>[makeTask(id: '1')]);
      await store.load();

      await _pump(tester, store);

      expect(find.text('No reminders yet'), findsOneWidget);
      expect(find.text('Add reminder'), findsOneWidget);
    });

    testWidgets(
      'loads a cold store itself instead of showing the empty state',
      (tester) async {
        // Deep links to /reminders build an unloaded store; the screen must
        // trigger the load and surface persisted reminders.
        final store = _store(<Task>[
          makeTask(
            id: '1',
            title: 'Revise chapter 4',
            reminderAt: DateTime.now().add(const Duration(hours: 5)),
          ),
        ]);

        await _pump(tester, store);

        expect(find.text('Revise chapter 4'), findsOneWidget);
        expect(find.text('No reminders yet'), findsNothing);
      },
    );

    testWidgets('groups overdue and upcoming reminders by urgency', (
      tester,
    ) async {
      final store = _store(<Task>[
        makeTask(
          id: 'overdue',
          title: 'Revise chapter 4',
          reminderAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        makeTask(
          id: 'upcoming',
          title: 'Submit lab report',
          reminderAt: DateTime.now().add(const Duration(days: 2)),
        ),
      ]);
      await store.load();

      await _pump(tester, store);

      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Revise chapter 4'), findsOneWidget);
      expect(find.text('Submit lab report'), findsOneWidget);
    });

    testWidgets('completing a reminder removes it from the open list', (
      tester,
    ) async {
      final store = _store(<Task>[
        makeTask(
          id: '1',
          title: 'Submit lab report',
          reminderAt: DateTime.now().add(const Duration(hours: 2)),
        ),
      ]);
      await store.load();

      await _pump(tester, store);
      expect(find.text('Submit lab report'), findsOneWidget);

      await tester.tap(find.byTooltip('Complete task'));
      await tester.pumpAndSettle();

      expect(store.tasks.single.isCompleted, isTrue);
      expect(find.text('No reminders yet'), findsOneWidget);
    });

    testWidgets('snoozing moves the reminder ten minutes into the future', (
      tester,
    ) async {
      final store = _store(<Task>[
        makeTask(
          id: '1',
          title: 'Revise chapter 4',
          reminderAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      ]);
      await store.load();

      await _pump(tester, store);

      await tester.tap(find.byTooltip('Snooze 10 minutes'));
      await tester.pumpAndSettle();

      expect(
        store.tasks.single.reminderAt!.isAfter(
          DateTime.now().add(const Duration(minutes: 9)),
        ),
        isTrue,
      );
    });

    testWidgets('add-reminder dialog creates a stand-alone reminder task', (
      tester,
    ) async {
      final store = _store(<Task>[]);
      await store.load();

      await _pump(tester, store);

      await tester.tap(find.byTooltip('Add reminder'));
      await tester.pumpAndSettle();

      expect(find.text('Add reminder'), findsWidgets);

      await tester.enterText(
        find.byType(TextFormField),
        'Revise ST0529 chapter 4',
      );
      await tester.tap(find.text('Save reminder'));
      await tester.pumpAndSettle();

      expect(store.tasks, hasLength(1));
      expect(store.tasks.single.title, 'Revise ST0529 chapter 4');
      expect(store.tasks.single.reminderAt, isNotNull);
      expect(store.tasks.single.dueDate, isNotNull);
    });
  });
}
