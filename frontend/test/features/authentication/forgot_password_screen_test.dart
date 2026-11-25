import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/routing/app_router.dart';
import 'package:frontend/features/authentication/data/auth_service.dart';
import 'package:frontend/features/authentication/screens/forgot_password_screen.dart';

class _FakeAuth extends AuthService {
  _FakeAuth({this.onForgot});
  final Future<void> Function({required String email})? onForgot;

  @override
  Future<void> forgotPassword({required String email}) async {
    if (onForgot != null) return onForgot!(email: email);
  }
}

Widget _app(AuthService auth) => MaterialApp(
  routes: {AppRoutes.login: (_) => const Scaffold(body: Text('login'))},
  home: ForgotPasswordScreen(auth: auth),
);

void main() {
  testWidgets('validates email and submits successfully', (tester) async {
    String? sentEmail;
    final auth = _FakeAuth(
      onForgot: ({required String email}) async {
        sentEmail = email;
      },
    );

    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    expect(find.text('Enter your email address'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'bad');
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    expect(find.text('Enter a valid email address'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(sentEmail, 'user@example.com');
    expect(find.text('Check your inbox'), findsOneWidget);
    await tester.tap(find.text('Back to sign in').last);
    await tester.pumpAndSettle();
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('shows ApiException message on failure', (tester) async {
    final auth = _FakeAuth(
      onForgot: ({required String email}) async {
        throw ApiException('Nope', code: 'X');
      },
    );

    await tester.pumpWidget(_app(auth));
    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Nope'), findsOneWidget);
  });

  testWidgets('shows generic error on unexpected failure', (tester) async {
    final auth = _FakeAuth(
      onForgot: ({required String email}) async {
        throw Exception('boom');
      },
    );

    await tester.pumpWidget(_app(auth));
    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('Something went wrong'), findsOneWidget);
  });
}
