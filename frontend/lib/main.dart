import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/url_strategy.dart';

import 'app.dart';

export 'app.dart';

void main() {
  setPathUrlStrategy();
  runApp(const ProviderScope(child: AuxiliaApp()));
}
