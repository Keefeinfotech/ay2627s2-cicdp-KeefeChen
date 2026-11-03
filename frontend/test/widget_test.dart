import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('first launch opens the product introduction', (tester) async {
    await tester.pumpWidget(const AuxiliaApp());
    await tester.pumpAndSettle();

    expect(find.text('Your responsibilities, organised.'), findsOneWidget);
    expect(find.text('Help Anywhere, Learn Together'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('skipping onboarding opens the separate login screen', (
    tester,
  ) async {
    await tester.pumpWidget(const AuxiliaApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Auxilia'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Your responsibilities, organised.'), findsNothing);
  });
}
