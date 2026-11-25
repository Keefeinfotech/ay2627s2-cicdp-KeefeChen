import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/routing/app_router.dart';
import 'package:frontend/features/authentication/data/auth_service.dart';
import 'package:frontend/features/authentication/screens/reset_password_screen.dart';

class _FakeAuth extends AuthService {
  _FakeAuth({this.onReset});
  final Future<void> Function({
    required String token,
    required String password,
  })?
  onReset;

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    if (onReset != null) return onReset!(token: token, password: password);
  }
}

Widget _app({AuthService? auth, String? token}) => MaterialApp(
  routes: {
    AppRoutes.login: (_) => const Scaffold(body: Text('login')),
    AppRoutes.forgotPassword: (_) => const Scaffold(body: Text('forgot')),
  },
  home: ResetPasswordScreen(auth: auth ?? _FakeAuth(), token: token),
);

void main() {
  testWidgets('shows invalid link state when token missing', (tester) async {
    await tester.pumpWidget(_app(token: null));
    await tester.pumpAndSettle();
    expect(find.text('Invalid reset link'), findsOneWidget);
    await tester.tap(find.text('Request a new link'));
    await tester.pumpAndSettle();
    expect(find.text('forgot'), findsOneWidget);
  });

  testWidgets('validates and submits new password', (tester) async {
    String? gotToken;
    String? gotPw;
    final auth = _FakeAuth(
      onReset: ({required String token, required String password}) async {
        gotToken = token;
        gotPw = password;
      },
    );
    await tester.pumpWidget(_app(auth: auth, token: 'tok123'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(find.text('Enter your new password'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'short');
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(
      find.text('Password must be at least 12 characters'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'alllowercase1!');
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(
      find.text('Password must contain at least one uppercase letter'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'ALLUPPERCASE1!');
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(
      find.text('Password must contain at least one lowercase letter'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'NoDigitsHere!!');
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(
      find.text('Password must contain at least one number'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'NoSpecial123A');
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(
      find.text('Password must contain at least one special character'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'ValidPass123!');
    await tester.enterText(find.byType(TextFormField).at(1), 'Different123!');
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(find.text('Passwords do not match'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'ValidPass123!');
    await tester.tap(find.text('Update password'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(gotToken, 'tok123');
    expect(gotPw, 'ValidPass123!');
    expect(find.text('Password updated'), findsOneWidget);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('shows ApiException on reset failure', (tester) async {
    final auth = _FakeAuth(
      onReset: ({required String token, required String password}) async {
        throw ApiException('bad token', code: 'X');
      },
    );
    await tester.pumpWidget(_app(auth: auth, token: 'tok'));
    await tester.enterText(find.byType(TextFormField).at(0), 'ValidPass123!');
    await tester.enterText(find.byType(TextFormField).at(1), 'ValidPass123!');
    await tester.tap(find.text('Update password'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('bad token'), findsOneWidget);
  });

  testWidgets('shows generic error on reset failure', (tester) async {
    final auth = _FakeAuth(
      onReset: ({required String token, required String password}) async {
        throw Exception('boom');
      },
    );
    await tester.pumpWidget(_app(auth: auth, token: 'tok'));
    await tester.enterText(find.byType(TextFormField).at(0), 'ValidPass123!');
    await tester.enterText(find.byType(TextFormField).at(1), 'ValidPass123!');
    await tester.tap(find.text('Update password'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.textContaining('Something went wrong'), findsOneWidget);
  });
}
