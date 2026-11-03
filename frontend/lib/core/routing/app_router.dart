import 'package:flutter/material.dart';

import '../../features/assistant/screens/ai_chat_screen.dart';
import '../../features/authentication/models/session.dart';
import '../../features/authentication/screens/login_screen.dart';
import '../../features/authentication/screens/signup_screen.dart';
import '../../features/authentication/screens/startup_gate.dart';
import '../../features/authentication/screens/welcome_screen.dart';
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
  static const String home = '/home';
  static const String assistant = '/assistant';
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
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const OnboardingScreen(),
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
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => AiChatScreen(
            session: args is AssistantArgs ? args.session : null,
          ),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const StartupGate(),
        );
    }
  }
}
