import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/routing/app_router.dart';
import 'package:frontend/features/authentication/screens/login_screen.dart';
import 'package:frontend/core/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows the email, password and account entry points', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AuxiliaTheme.light(), home: const LoginScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Auxilia'), findsOneWidget);
    expect(
      find.text('Sign in to continue organising your day.'),
      findsOneWidget,
    );
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Continue offline'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });

  testWidgets('validates empty credentials before calling the API', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AuxiliaTheme.light(), home: const LoginScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('toggles password visibility', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AuxiliaTheme.light(), home: const LoginScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Show password'), findsOneWidget);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('keeps the unavailable password reset action disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AuxiliaTheme.light(), home: const LoginScreen()),
    );
    await tester.pumpAndSettle();

    final resetAction = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Forgot password?'),
    );
    expect(resetAction.onPressed, isNull);
  });

  testWidgets('continuing offline keeps guest access reachable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AuxiliaTheme.light(),
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: const LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue offline'));
    await tester.pumpAndSettle();

    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('remains usable at 200% text scaling on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AuxiliaTheme.light(),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(textScaler: const TextScaler.linear(2)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Welcome to Auxilia'), findsOneWidget);
  });
}
