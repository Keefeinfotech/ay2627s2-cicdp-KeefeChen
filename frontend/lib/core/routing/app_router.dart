import 'package:flutter/material.dart';
import 'package:frontend/features/reminders/screens/reminders_screen.dart';

import '../../features/assistant/presentation/pages/assistant_page.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/authentication/data/auth_service.dart';
import '../../features/authentication/models/session.dart';
import '../../features/authentication/screens/forgot_password_screen.dart';
import '../../features/authentication/screens/login_screen.dart';
import '../../features/authentication/screens/reset_password_screen.dart';
import '../../features/authentication/screens/signup_screen.dart';
import '../../features/authentication/screens/startup_gate.dart';
import '../../features/authentication/screens/welcome_screen.dart';
import '../../features/groups/presentation/pages/groups_page.dart';
import '../../features/home/data/api_task_repository.dart';
import '../../features/home/data/task_store.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../constants/app_constants.dart';
import '../layout/app_shell.dart';

/// Named routes keep navigation, arguments and back-stack behaviour in one
/// place instead of duplicating [MaterialPageRoute] construction in screens.
abstract final class AppRoutes {
  static const String startup = '/';
  static const String onboarding = '/onboarding';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String home = '/home';
  static const String assistant = '/assistant';
  static const String reminders = '/reminders';
  static const String groups = '/groups';
  static const String admin = '/admin';
}

class HomeArgs {
  const HomeArgs({required this.ownerId, this.displayName, this.session});

  final String ownerId;
  final String? displayName;
  final Session? session;
}

class AssistantArgs {
  const AssistantArgs({required this.session});

  final Session session;
}

class OnboardingArgs {
  const OnboardingArgs({this.returnToPrevious = false});

  /// Pop back to the existing screen when onboarding is opened from Settings.
  final bool returnToPrevious;
}

class AdminArgs {
  const AdminArgs({required this.session});

  final Session session;
}

/// Restores the persisted session once and supplies a correctly authenticated
/// [TaskStore] to standalone feature routes.
///
/// Deep links must not construct a guest store: doing so made `/reminders`
/// show its informational empty state and `/groups` show guest data even for a
/// signed-in user. The store is disposed with the route.
class PersistedSessionStoreBuilder extends StatefulWidget {
  const PersistedSessionStoreBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, TaskStore store, Session? session)
  builder;

  @override
  State<PersistedSessionStoreBuilder> createState() =>
      _PersistedSessionStoreBuilderState();
}

class _PersistedSessionStoreBuilderState
    extends State<PersistedSessionStoreBuilder> {
  final AuthService _auth = AuthService();
  Session? _session;
  TaskStore? _store;
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    Session? session;
    try {
      session = await _auth.restore().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      if (session != null) {
        session = await _auth
            .validateSession(session)
            .timeout(const Duration(seconds: 5), onTimeout: () => session);
      }
    } on SessionException {
      session = null;
    } catch (_) {
      session = null;
    }

    if (!mounted) return;
    final store = TaskStore(
      repository: ApiTaskRepository(token: session?.token ?? ''),
      ownerId: session?.email ?? AppConstants.guestOwnerId,
    );
    if (!store.hasLoaded && !store.isLoading) store.load();
    setState(() {
      _session = session;
      _store = store;
      _restored = true;
    });
  }

  @override
  void dispose() {
    _store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_restored || _store == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return widget.builder(context, _store!, _session);
  }
}

/// Subtle cross-fade between screens. Keeps the Trust Blue identity calm and
/// avoids abrupt jumps for navigation that is not tabbed.
Route<void> _fadeRoute({
  required RouteSettings settings,
  required WidgetBuilder builder,
}) {
  return PageRouteBuilder<void>(
    settings: settings,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

/// Resolves the reset token from a route argument (in-app navigation) or the
/// `token` query parameter (an emailed link such as `/reset-password?token=…`).
String? _resetTokenFrom(RouteSettings settings) {
  final Object? arguments = settings.arguments;
  if (arguments is String && arguments.trim().isNotEmpty) {
    return arguments.trim();
  }

  final Uri uri = Uri.tryParse(settings.name ?? '') ?? Uri();
  final String? queryToken = uri.queryParameters['token'];
  if (queryToken != null && queryToken.trim().isNotEmpty) {
    return queryToken.trim();
  }

  return null;
}

/// Central route table for the whole application.
///
/// The startup route restores a secure session before choosing onboarding,
/// sign-in or the dashboard. Unknown routes fall back to the startup gate so a
/// stale deep link cannot leave the app on a blank page.
class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.startup:
        return _fadeRoute(
          settings: settings,
          builder: (_) => const StartupGate(),
        );
      case AppRoutes.onboarding:
        final args = settings.arguments;
        return _fadeRoute(
          settings: settings,
          builder: (context) => OnboardingScreen(
            onComplete: args is OnboardingArgs && args.returnToPrevious
                ? () => Navigator.of(context).pop()
                : null,
          ),
        );
      case AppRoutes.welcome:
        return _fadeRoute(
          settings: settings,
          builder: (_) => const WelcomeScreen(),
        );
      case AppRoutes.login:
        return _fadeRoute(
          settings: settings,
          builder: (_) => const LoginScreen(),
        );
      case AppRoutes.signup:
        return _fadeRoute(
          settings: settings,
          builder: (_) => const SignupScreen(),
        );
      case AppRoutes.forgotPassword:
        return _fadeRoute(
          settings: settings,
          builder: (_) => const ForgotPasswordScreen(),
        );
      case AppRoutes.resetPassword:
        return _fadeRoute(
          settings: settings,
          builder: (_) => ResetPasswordScreen(token: _resetTokenFrom(settings)),
        );
      case AppRoutes.home:
        final args = settings.arguments;
        final homeArgs = args is HomeArgs
            ? args
            : const HomeArgs(ownerId: AppConstants.guestOwnerId);
        return _fadeRoute(
          settings: settings,
          builder: (_) => AppShell(
            ownerId: homeArgs.ownerId,
            displayName: homeArgs.displayName,
            session: homeArgs.session,
          ),
        );
      case AppRoutes.assistant:
        final args = settings.arguments;
        final session = args is AssistantArgs ? args.session : null;
        return _fadeRoute(
          settings: settings,
          builder: (_) => AssistantPage(
            ownerId: session?.email ?? AppConstants.guestOwnerId,
            session: session,
          ),
        );
      case AppRoutes.reminders:
        return _fadeRoute(
          settings: settings,
          builder: (_) => PersistedSessionStoreBuilder(
            builder: (context, store, _) => RemindersScreen(store: store),
          ),
        );
      case AppRoutes.groups:
        return _fadeRoute(
          settings: settings,
          builder: (_) => PersistedSessionStoreBuilder(
            builder: (context, store, session) =>
                GroupsPage(store: store, session: session),
          ),
        );
      case AppRoutes.admin:
        final args = settings.arguments;
        if (args is AdminArgs) {
          return _fadeRoute(
            settings: settings,
            builder: (_) => AdminDashboardPage(session: args.session),
          );
        }
        return _fadeRoute(
          settings: settings,
          builder: (_) => const StartupGate(),
        );
      default:
        return _fadeRoute(
          settings: settings,
          builder: (_) => const StartupGate(),
        );
    }
  }
}
