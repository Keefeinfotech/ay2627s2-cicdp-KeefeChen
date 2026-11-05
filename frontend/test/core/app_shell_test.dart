import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/layout/app_shell.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/app_navigation.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';
import 'package:frontend/features/home/models/task.dart';

import '../helpers.dart';

TaskStore _store({List<Task> seed = const <Task>[]}) {
  return TaskStore(
    repository: InMemoryTaskRepository(
      seed: <String, List<Task>>{'owner': seed},
    ),
    ownerId: 'owner',
  );
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Widget _app(TaskStore store, {double textScale = 1}) {
  return MaterialApp(
    theme: AuxiliaTheme.light(),
    builder: textScale == 1
        ? null
        : (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(textScaler: TextScaler.linear(textScale)),
              child: child ?? const SizedBox.shrink(),
            );
          },
    home: AppShell(ownerId: 'owner', store: store),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('phone shell exposes the five primary destinations', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final store = _store();

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Welcome back'), findsOneWidget);

    final nav = find.byType(NavigationBar);
    for (final label in <String>[
      'Home',
      'Tasks',
      'Calendar',
      'Assistant',
      'Profile',
    ]) {
      expect(
        find.descendant(of: nav, matching: find.text(label)),
        findsOneWidget,
      );
    }

    await tester.tap(find.descendant(of: nav, matching: find.text('Tasks')));
    await tester.pumpAndSettle();
    expect(find.text('Quick add'), findsOneWidget);

    // Pages are created lazily and remain offstage when not selected.
    expect(find.text('How can I help?'), findsNothing);
    await tester.tap(
      find.descendant(of: nav, matching: find.text('Assistant')),
    );
    await tester.pumpAndSettle();
    expect(find.text('How can I help?'), findsOneWidget);

    await tester.tap(find.descendant(of: nav, matching: find.text('Profile')));
    await tester.pumpAndSettle();
    expect(find.text('Account, progress and local data'), findsOneWidget);

    // Offstage pages do not leak their content into the active finder set.
    expect(find.text('Quick add'), findsNothing);
  });

  testWidgets('tablet shell uses a rail with every destination', (
    tester,
  ) async {
    _setSize(tester, const Size(800, 1000));
    final store = _store();

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.byType(AppNavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.text('No projects yet'), findsOneWidget);

    await tester.tap(find.text('Groups'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to use groups'), findsOneWidget);

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('Your progress'), findsOneWidget);
  });

  testWidgets('desktop shell uses the sidebar with all eight destinations', (
    tester,
  ) async {
    _setSize(tester, const Size(1280, 900));
    final store = _store(seed: <Task>[makeTask(title: 'Write report')]);

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('AI Assistant'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Groups'), findsOneWidget);

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Quick add'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Account, progress and local data'), findsOneWidget);
  });

  testWidgets('shell survives 200% text scaling at 360 px', (tester) async {
    _setSize(tester, const Size(360, 800));
    final store = _store();

    await tester.pumpWidget(_app(store, textScale: 2));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
