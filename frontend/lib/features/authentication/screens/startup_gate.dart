import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../home/data/task_store.dart';
import '../../home/screens/home_screen.dart';
import '../../onboarding/data/onboarding_store.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import '../data/auth_service.dart';
import '../data/session_store.dart';
import 'login_screen.dart';

/// Decides what the application should show after a secure session restore.
///
/// Authenticated users go straight to the dashboard. Everyone else sees the
/// introduction once, then the sign-in screen on subsequent launches.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key, this.auth, this.store, this.onboarding});

  final AuthService? auth;
  final TaskStore? store;
  final OnboardingStore? onboarding;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late final AuthService _auth = widget.auth ?? AuthService();
  late final OnboardingStore _onboarding =
      widget.onboarding ?? OnboardingStore();
  Session? _session;
  bool _onboardingComplete = false;
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
    } on SessionException {
      session = null;
    } catch (_) {
      session = null;
    }

    bool onboardingComplete = true;
    if (session == null) {
      try {
        onboardingComplete = await _onboarding.isComplete().timeout(
          const Duration(seconds: 2),
          onTimeout: () => false,
        );
      } catch (_) {
        onboardingComplete = false;
      }
    }

    if (!mounted) return;
    setState(() {
      _session = session;
      _onboardingComplete = onboardingComplete;
      _restored = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_restored) return const _SplashView();

    final session = _session;
    if (session != null) {
      return HomeScreen(
        ownerId: session.email,
        displayName: session.displayName,
        session: session,
        store: widget.store,
      );
    }

    if (!_onboardingComplete) return const OnboardingScreen();

    return const LoginScreen();
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.softGrey,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const BrandMark(size: 56),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppConstants.tagline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Preparing your workspace...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
