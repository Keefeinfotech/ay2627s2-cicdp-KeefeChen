import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('welcome screen exposes the main entry points', (tester) async {
    await tester.pumpWidget(const AuxiliaApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Auxilia'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Continue offline'), findsOneWidget);
  });

  testWidgets('welcome screen states that tasks work offline', (tester) async {
    await tester.pumpWidget(const AuxiliaApp());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Your tasks stay on this device'),
      findsOneWidget,
    );
  });
}
