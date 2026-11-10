import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'features/authentication/data/session_store.dart';

export 'app.dart';

void main() {
  ApiClient.onUnauthorized = () async {
    try {
      await SessionStore().clear();
    } catch (_) {}
  };
  runApp(const ProviderScope(child: AuxiliaApp()));
}
