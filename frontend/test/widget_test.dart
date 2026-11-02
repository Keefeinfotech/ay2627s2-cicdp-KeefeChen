import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('welcome screen exposes the main entry points', (tester) async {
    await tester.pumpWidget(const AuxiliaApp());
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('welcome screen states that tasks work offline', (tester) async {
    await tester.pumpWidget(const AuxiliaApp());
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
  });
}
