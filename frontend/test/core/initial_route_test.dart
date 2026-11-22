import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app.dart';
import 'package:frontend/core/routing/app_router.dart';

void main() {
  test('path deep link opens the login screen', () {
    expect(
      resolveInitialRoute(Uri.parse('https://auxilia.example/login')),
      AppRoutes.login,
    );
  });

  test('path deep link opens the sign-up screen', () {
    expect(
      resolveInitialRoute(Uri.parse('https://auxilia.example/signup')),
      AppRoutes.signup,
    );
  });

  test('Flutter hash route wins over the /login base path', () {
    expect(
      resolveInitialRoute(Uri.parse('https://auxilia.example/login#/signup')),
      AppRoutes.signup,
    );
  });

  test('reset password token survives deep-link resolution', () {
    expect(
      resolveInitialRoute(
        Uri.parse('https://auxilia.example/#/reset-password?token=abc123'),
      ),
      '${AppRoutes.resetPassword}?token=abc123',
    );
  });

  test('other routes still go through the startup gate', () {
    expect(
      resolveInitialRoute(Uri.parse('https://auxilia.example/home')),
      AppRoutes.startup,
    );
    expect(
      resolveInitialRoute(Uri.parse('https://auxilia.example/')),
      AppRoutes.startup,
    );
  });
}
