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
  runApp(const ProviderScope(child: AuxiliaApp()));
}
