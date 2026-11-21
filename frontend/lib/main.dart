import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'features/authentication/data/auth_service.dart';

export 'app.dart';

void main() {
  // Silent renewal: one refresher shared by every ApiClient instance, so any
  // request that hits an expired access token refreshes once and retries.
  ApiClient.tokenRefresher = AuthService().refreshSilently;

  // Enterprise resilience: surface build-time errors in release instead of
  // the raw red error screen.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  ErrorWidget.builder = (details) => const Material(
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Something went wrong. Please restart the screen.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );

  runApp(const ProviderScope(child: AuxiliaApp()));
}
