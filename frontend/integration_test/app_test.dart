/*
 * File Name: app_test.dart
 * Description: End-to-end (integration) test for the Auxilia app. Boots the
 * real application — providers, router, theme, onboarding and startup gate —
 * and verifies the critical first-run path:
 *
 *   cold start → intro visible → onboarding skipped → login screen
 *
 * This suite runs on a real device/emulator or Chrome, unlike the headless
 * widget tests under test/. Run it with:
 *
 *   flutter test integration_test/app_test.dart            # supported hosts
 *   flutter drive --driver=test_driver/integration_test.dart \
 *     --target=integration_test/app_test.dart               # device/web
 *
 * In CI it is intentionally not wired into the blocking gate because it needs
 * a device/browser; the docker-compose based Playwright suite covers the
 * same user path headlessly (see e2e/).
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cold start boots into intro then reaches login', (tester) async {
    app.main();

    // The startup gate restores the session with internal timeouts (~3–5s)
    // and perpetual video animations never "settle", so pump manually.
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    // First-run intro page is visible for a fresh install.
    expect(find.text('Everything you need, in one place.'), findsOneWidget);

    // Skip the intro; the session is absent so the login screen appears.
    await tester.tap(find.text('Skip'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('Welcome to Auxilia'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
