import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/home/screens/home_screen.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/home/widgets/dashboard_header.dart';

import '../helpers.dart';

Future<TaskStore> pumpDashboard(
  WidgetTester tester, {
  List<Task> seed = const <Task>[],
  ThemeData? theme,
}) async {
  final repository = InMemoryTaskRepository(
    seed: <String, List<Task>>{'owner': seed},
  );
  final store = TaskStore(repository: repository, ownerId: 'owner');

  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AuxiliaTheme.light(),
      home: HomeScreen(ownerId: 'owner', store: store),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('renders the dashboard header, stats and task section', (
    tester,
  ) async {
    await pumpDashboard(tester);

    expect(find.text('Your tasks'), findsOneWidget);
    expect(find.text('No tasks yet'), findsOneWidget);
  });

  testWidgets('updates the header stats when a task is completed', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      seed: <Task>[
        makeTask(title: 'Finish assignment', priority: TaskPriority.high),
      ],
    );

    final header = find.byType(DashboardHeader);
    expect(
      find.descendant(of: header, matching: find.text('Total XP')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: find.text('Done')),
      findsOneWidget,
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(DashboardHeader),
        matching: find.text('30'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DashboardHeader),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders in the dark theme without layout errors', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      theme: AuxiliaTheme.dark(),
      seed: <Task>[makeTask(title: 'Dark mode task')],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Dark mode task'), findsOneWidget);
  });
}
