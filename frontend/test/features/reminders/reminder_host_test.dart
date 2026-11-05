import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';
import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/reminders/widgets/reminder_host.dart';

import '../../helpers.dart';

TaskStore _store(List<Task> tasks) {
  return TaskStore(
    repository: InMemoryTaskRepository(
      seed: <String, List<Task>>{'owner': tasks},
    ),
    ownerId: 'owner',
  );
}

void main() {
  testWidgets('ReminderSection lists scheduled reminders and snoozes one', (
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReminderSection(store: store)),
      ),
    );

    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('1 scheduled'), findsOneWidget);
    expect(find.text('Submit lab report'), findsOneWidget);

    await tester.tap(find.byTooltip('Snooze 10 minutes'));
    await tester.pump();

    expect(
      store.tasks.single.reminderAt!.isAfter(
        DateTime.now().add(const Duration(minutes: 9)),
      ),
      isTrue,
    );
  });

  testWidgets('ReminderSection hides itself when nothing is scheduled', (
    tester,
  ) async {
    final store = _store(<Task>[makeTask(id: '1')]);
    await store.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReminderSection(store: store)),
      ),
    );

    expect(find.text('Reminders'), findsNothing);
  });

  testWidgets('ReminderHost presents a due reminder as a banner', (
    tester,
  ) async {
    final store = _store(<Task>[
      makeTask(
        id: '1',
        title: 'Hand in assignment',
        reminderAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    ]);
    await store.load();

    await tester.pumpWidget(
      MaterialApp(
        home: ReminderHost(
          store: store,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reminder: Hand in assignment'), findsOneWidget);
    expect(find.text('Snooze 10 min'), findsOneWidget);
    expect(find.text('Mark done'), findsOneWidget);

    await tester.tap(find.text('Mark done'));
    await tester.pumpAndSettle();

    expect(store.tasks.single.isCompleted, isTrue);
    expect(find.text('Reminder: Hand in assignment'), findsNothing);
  });

  testWidgets('ReminderHost does not repeat a dismissed reminder', (
    tester,
  ) async {
    final store = _store(<Task>[
      makeTask(
        id: '1',
        title: 'One-off reminder',
        reminderAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    ]);
    await store.load();

    await tester.pumpWidget(
      MaterialApp(
        home: ReminderHost(
          store: store,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 31));
    expect(find.text('Reminder: One-off reminder'), findsNothing);
  });
}
