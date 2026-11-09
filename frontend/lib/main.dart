import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/url_strategy.dart';

import 'app.dart';

export 'app.dart';

void main() {
  // On web, use the path URL strategy so routes are clean (no '#' fragment)
  // and deep links resolve correctly when served from a sub-path.
  if (kIsWeb) {
    setPathUrlStrategy();
  }

  runApp(const ProviderScope(child: AuxiliaApp()));
}
