/*
 * File Name: integration_test.dart
 * Description: Flutter drive target for the integration suite. Launches the
 * real app on a device/emulator (or Chrome) and runs
 * ../integration_test/app_test.dart against it. This file was referenced by
 * docs/testing/TESTING_STRATEGY.md for local runs but was never committed,
 * which is why `flutter drive` could not be used.
 *
 * CI: see .github/workflows/integration.yml.
 */

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
