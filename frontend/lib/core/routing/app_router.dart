import 'package:flutter/material.dart';
import 'package:frontend/features/reminders/screens/reminders_screen.dart';

import '../../features/assistant/presentation/pages/assistant_page.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
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

/// Shares the caller's live [TaskStore] with the full-screen reminders hub.
///
/// Navigators that already hold a store (the shell, the dashboard) pass it
/// through so completing a reminder there is reflected everywhere without a
/// reload. Without arguments the route builds an isolated guest store.
class RemindersArgs {
  const RemindersArgs({this.store, this.session});

  final TaskStore? store;
  final Session? session;
}

/// Same pattern for the groups workspace: signed-in callers pass their live
/// store and session instead of the route building a blank guest context.
class GroupsArgs {
  const GroupsArgs({this.store, this.session});

  final TaskStore? store;
  final Session? session;
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

/// Returns the caller-provided store, or builds one scoped to [session]
/// (guest when absent). Mirrors how the shell wires its own store.
TaskStore _storeFor({TaskStore? store, Session? session}) {
  if (store != null) return store;
  return TaskStore(
    repository: ApiTaskRepository(token: session?.token ?? ''),
    ownerId: session?.email ?? AppConstants.guestOwnerId,
  );
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
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const StartupGate(),
        );
      case AppRoutes.onboarding:
        final args = settings.arguments;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => OnboardingScreen(
            onComplete: args is OnboardingArgs && args.returnToPrevious
                ? () => Navigator.of(context).pop()
                : null,
          ),
        );
      case AppRoutes.welcome:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const WelcomeScreen(),
        );
      case AppRoutes.login:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const LoginScreen(),
        );
      case AppRoutes.signup:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SignupScreen(),
        );
      case AppRoutes.forgotPassword:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ForgotPasswordScreen(),
        );
      case AppRoutes.resetPassword:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ResetPasswordScreen(token: _resetTokenFrom(settings)),
        );
      case AppRoutes.home:
        final args = settings.arguments;
        final homeArgs = args is HomeArgs
            ? args
            : const HomeArgs(ownerId: AppConstants.guestOwnerId);
        return MaterialPageRoute<void>(
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
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => AssistantPage(
            ownerId: session?.email ?? AppConstants.guestOwnerId,
            session: session,
          ),
        );
      case AppRoutes.reminders:
        final args = settings.arguments;
        final remindersArgs = args is RemindersArgs ? args : null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => RemindersScreen(
            store: _storeFor(
              store: remindersArgs?.store,
              session: remindersArgs?.session,
            ),
          ),
        );
      case AppRoutes.groups:
        final args = settings.arguments;
        final groupsArgs = args is GroupsArgs ? args : null;
        final store = _storeFor(
          store: groupsArgs?.store,
          session: groupsArgs?.session,
        );
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) =>
              GroupsPage(store: store, session: groupsArgs?.session),
        );
      case AppRoutes.admin:
        final args = settings.arguments;
        if (args is AdminArgs) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => AdminDashboardPage(session: args.session),
          );
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const StartupGate(),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const StartupGate(),
        );
    }
  }
}
