import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/animated_gradient_background.dart';

/// Resolves the route for a fresh page load on the web.
///
/// `initialRoute` used to always be `/`, so opening `/login` (or a shared
/// `/signup` link) showed the onboarding gate instead of the requested screen.
/// Flutter's hash routing keeps the server path (`/login`) and puts the SPA
/// route in the fragment (`/login#/signup`), so both are considered. Only the
/// public auth screens are handled here: everything else still goes through
/// the startup gate so secure-session restoration keeps working.
String _initialRoute() {
  if (!kIsWeb) return AppRoutes.startup;
  return resolveInitialRoute(Uri.base);
}

/// Pure helper so deep-link resolution is unit-testable without a browser.
String resolveInitialRoute(Uri uri) {
  const authRoutes = <String>[
    AppRoutes.login,
    AppRoutes.signup,
    AppRoutes.forgotPassword,
    AppRoutes.resetPassword,
  ];

  for (final raw in <String>[uri.fragment, uri.path]) {
    if (raw.isEmpty) continue;
    final candidate = Uri.tryParse(raw.startsWith('/') ? raw : '/$raw');
    if (candidate == null || !authRoutes.contains(candidate.path)) continue;
    return candidate.hasQuery
        ? '${candidate.path}?${candidate.query}'
        : candidate.path;
  }
  return AppRoutes.startup;
}

/// Root widget for Auxilia.
///
/// Routing is handled by [AppRouter] using standard named routes. This keeps
/// the existing route names and arguments while removing the duplicated
/// GoRouter configuration that previously lived in `main.dart`.
class AuxiliaApp extends StatelessWidget {
  const AuxiliaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auxilia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      initialRoute: _initialRoute(),
      onGenerateRoute: AppRouter.onGenerateRoute,
      builder: (context, child) =>
          AnimatedGradientBackground(child: child ?? const SizedBox.shrink()),
    );
  }
}
