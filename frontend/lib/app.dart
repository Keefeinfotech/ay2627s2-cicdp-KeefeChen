import 'package:flutter/material.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

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
      initialRoute: AppRoutes.startup,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
