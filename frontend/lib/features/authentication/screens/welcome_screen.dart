import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import 'login_screen.dart';

/// Legacy entry point kept for older links and imports.
///
/// New launches are handled by [StartupGate], which shows onboarding on first
/// run and this sign-in screen on later runs. The class delegates to
/// [LoginScreen] so there is only one authentication implementation.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.auth});

  final AuthService? auth;

  @override
  Widget build(BuildContext context) {
    return LoginScreen(auth: auth);
  }
}
