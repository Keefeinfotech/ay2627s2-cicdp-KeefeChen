import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/routing/app_router.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/authentication/data/auth_service.dart';
import 'package:frontend/features/authentication/data/session_store.dart';
import 'package:frontend/features/authentication/screens/signup_screen.dart';

/// A controllable AuthService that records signup calls.
class FakeAuthService extends AuthService {
  FakeAuthService({this.shouldFail = false, this.session})
      : super(api: ApiClient(), sessions: SessionStore());

  final bool shouldFail;
  final Session? session;
  final List<Map<String, dynamic>> calls = <Map<String, dynamic>>[];

  @override
  Future<Session> signup({
    String? name,
    required String email,
    required String password,
  }) async {
    calls.add(<String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
    });
    if (shouldFail) {
      throw ApiException('Signup failed');
    }
    return session ??
        const Session(
          token: 'token',
          email: 'alice@example.com',
          name: 'Alice Chen',
        );
  }
}

Widget pumpSignup({FakeAuthService? auth}) => MaterialApp(
      theme: AuxiliaTheme.light(),
      home: SignupScreen(auth: auth),
    );

// Field order in the form: name(0), email(1), password(2), confirm(3).
const int kName = 0;
const int kEmail = 1;
const int kPassword = 2;
const int kConfirm = 3;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows the name, email, password and confirm password fields', (
    tester,
  ) async {
    await tester.pumpWidget(pumpSignup());
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Already have an account?'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('Create Account is disabled until a strong password is set', (
    tester,
  ) async {
    await tester.pumpWidget(pumpSignup());
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    // A weak password keeps the button disabled.
    await tester.enterText(
      find.byType(TextFormField).at(kPassword),
      'weak',
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('password strength bar and requirements appear when typing', (
    tester,
  ) async {
    await tester.pumpWidget(pumpSignup());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(kPassword),
      'Str0ng!Passw0rd',
    );
    await tester.pumpAndSettle();

    // Requirements render once the password field has text.
    expect(find.text('At least 12 characters'), findsOneWidget);
    expect(find.text('At least one uppercase letter'), findsOneWidget);
    expect(find.text('At least one lowercase letter'), findsOneWidget);
    expect(find.text('At least one number'), findsOneWidget);
    expect(find.text('At least one special character'), findsOneWidget);
    expect(find.text('Not a commonly used password'), findsOneWidget);
  });

  testWidgets('reports a too-short strength for a weak password', (
    tester,
  ) async {
    await tester.pumpWidget(pumpSignup());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(kPassword),
      'weak',
    );
    await tester.pumpAndSettle();

    expect(find.text('Too short'), findsOneWidget);
  });

  testWidgets('confirms matching passwords and shows a match indicator', (
    tester,
  ) async {
    await tester.pumpWidget(pumpSignup());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(kPassword),
      'Str0ng!Passw0rd',
    );
    await tester.enterText(
      find.byType(TextFormField).at(kConfirm),
      'Different1!',
    );
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(kConfirm),
      'Str0ng!Passw0rd',
    );
    await tester.pumpAndSettle();

    expect(find.text('Passwords match'), findsOneWidget);
  });

  testWidgets('rejects a name longer than 80 characters (overflow)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(pumpSignup());
    await tester.pumpAndSettle();

    // Enable the Create Account button with valid email/password/confirm first.
    await tester.enterText(
      find.byType(TextFormField).at(kEmail),
      'alice@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).at(kPassword),
      'Str0ng!Passw0rd',
    );
    await tester.enterText(
      find.byType(TextFormField).at(kConfirm),
      'Str0ng!Passw0rd',
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );

    // Overflow the name field, then submit: validation rejects it.
    await tester.enterText(
      find.byType(TextFormField).at(kName),
      'A' * 81,
    );
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Keep your name under 80 characters'), findsOneWidget);
  });

  testWidgets('accepts a name of exactly 80 characters', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = FakeAuthService();
    await tester.pumpWidget(pumpSignup(auth: auth));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(kName),
      'A' * 80,
    );
    await tester.enterText(
      find.byType(TextFormField).at(kEmail),
      'alice@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).at(kPassword),
      'Str0ng!Passw0rd',
    );
    await tester.enterText(
      find.byType(TextFormField).at(kConfirm),
      'Str0ng!Passw0rd',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(auth.calls, hasLength(1));
    expect(find.text('Keep your name under 80 characters'), findsNothing);
  });

  testWidgets('toggles password visibility for both password fields', (
    tester,
  ) async {
    await tester.pumpWidget(pumpSignup());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Show password'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Show password').first);
    await tester.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(find.byTooltip('Show password'), findsNWidgets(2));
  });

  testWidgets('calls auth.signup and navigates home on successful signup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = FakeAuthService();
    String? pushedRoute;

    await tester.pumpWidget(
      MaterialApp(
        theme: AuxiliaTheme.light(),
        home: SignupScreen(auth: auth),
        onGenerateRoute: (settings) {
          pushedRoute = settings.name;
          return MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('home')),
            settings: settings,
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(kName),
      'Alice Chen',
    );
    await tester.enterText(
      find.byType(TextFormField).at(kEmail),
      'alice@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).at(kPassword),
      'Str0ng!Passw0rd',
    );
    await tester.enterText(
      find.byType(TextFormField).at(kConfirm),
      'Str0ng!Passw0rd',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(auth.calls, hasLength(1));
    expect(auth.calls.first['email'], 'alice@example.com');
    expect(auth.calls.first['password'], 'Str0ng!Passw0rd');
    expect(auth.calls.first['name'], 'Alice Chen');
    expect(pushedRoute, AppRoutes.home);
  });

  testWidgets('shows an error snackbar when signup fails', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = FakeAuthService(shouldFail: true);

    await tester.pumpWidget(pumpSignup(auth: auth));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(kEmail),
      'alice@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).at(kPassword),
      'Str0ng!Passw0rd',
    );
    await tester.enterText(
      find.byType(TextFormField).at(kConfirm),
      'Str0ng!Passw0rd',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Signup failed'), findsOneWidget);
  });

  testWidgets('remains usable at 200% text scaling on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(pumpSignup());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });
}
