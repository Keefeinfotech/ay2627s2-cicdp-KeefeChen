import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/authentication/models/session.dart';
import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/home/screens/home_screen.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';

import '../helpers.dart';

const Session _session = Session(
  token: 'token-123',
  email: 'student@example.com',
  name: 'Sam',
);

Future<TaskStore> _pumpHome(
  WidgetTester tester, {
  Session? session = _session,
  String? displayName = 'Sam',
}) async {
  final repository = InMemoryTaskRepository(
    seed: <String, List<Task>>{
      'owner': <Task>[
        makeTask(
          title: 'Profile task',
          status: TaskStatus.completed,
          xpAwarded: true,
          completedAt: DateTime.now(),
        ),
      ],
    },
  );
  final store = TaskStore(repository: repository, ownerId: 'owner');

  await tester.pumpWidget(
    wrapApp(
      HomeScreen(
        ownerId: 'owner',
        displayName: displayName,
        session: session,
        store: store,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('opens the profile sheet with existing account actions', (
    tester,
  ) async {
    await _pumpHome(tester);

    await tester.tap(find.byTooltip('Profile and settings'));
    await tester.pumpAndSettle();

    expect(find.text('Sam'), findsWidgets);
    expect(find.text('student@example.com'), findsOneWidget);
    expect(find.text('Total XP'), findsWidgets);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Achievements'), findsNWidgets(2));
    expect(find.text('AI assistant'), findsOneWidget);
    expect(find.text('Remove all local tasks'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('guest profile offers sign in instead of sign out', (
    tester,
  ) async {
    await _pumpHome(tester, session: null, displayName: null);

    await tester.tap(find.byTooltip('Profile and settings'));
    await tester.pumpAndSettle();

    expect(find.text('Guest workspace'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('opens achievements from the profile sheet', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.byTooltip('Profile and settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Achievements').last);
    await tester.pumpAndSettle();

    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('First step'), findsOneWidget);
  });
}
