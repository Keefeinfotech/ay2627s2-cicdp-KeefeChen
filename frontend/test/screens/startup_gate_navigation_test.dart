import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/features/authentication/data/auth_service.dart';
import 'package:frontend/features/authentication/models/session.dart';
import 'package:frontend/features/authentication/screens/startup_gate.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';
import 'package:frontend/features/onboarding/data/onboarding_store.dart';
import 'package:frontend/core/theme/app_theme.dart';

class _FakeAuth extends AuthService {
  _FakeAuth(this.session);

  final Session? session;

  @override
  Future<Session?> restore() async => session;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('unauthenticated first launch shows onboarding', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AuxiliaTheme.light(),
        home: StartupGate(auth: _FakeAuth(null)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your responsibilities, organised.'), findsOneWidget);
  });

  testWidgets('returning unauthenticated user goes straight to login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      OnboardingStore.storageKey: true,
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AuxiliaTheme.light(),
        home: StartupGate(auth: _FakeAuth(null)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Auxilia'), findsOneWidget);
    expect(find.text('Your responsibilities, organised.'), findsNothing);
  });

  testWidgets('authenticated launch restores the dashboard', (tester) async {
    final store = TaskStore(
      repository: InMemoryTaskRepository(),
      ownerId: 'student@example.com',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AuxiliaTheme.light(),
        home: StartupGate(
          auth: _FakeAuth(
            const Session(
              token: 'token-123',
              email: 'student@example.com',
              name: 'Sam',
            ),
          ),
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Auxilia'), findsOneWidget);
    expect(find.byTooltip('Profile and settings'), findsOneWidget);
    expect(find.text('No tasks yet'), findsOneWidget);
  });
}
