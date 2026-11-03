import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/features/onboarding/data/onboarding_store.dart';
import 'package:frontend/features/onboarding/screens/onboarding_screen.dart';
import 'package:frontend/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('moves through the pages and completes onboarding', (
    tester,
  ) async {
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AuxiliaTheme.light(),
        home: OnboardingScreen(onComplete: () => completed = true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('STAY ORGANISED'), findsOneWidget);
    expect(find.text('Your responsibilities, organised.'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('PLAN YOUR TIME'), findsOneWidget);

    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();
    expect(find.text('STAY ORGANISED'), findsOneWidget);

    for (var index = 0; index < 3; index++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);

    await tester.tap(find.text('Get Started'));
    await tester.pump();

    expect(completed, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(OnboardingStore.storageKey), isTrue);
  });

  testWidgets('skip also persists completion', (tester) async {
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AuxiliaTheme.light(),
        home: OnboardingScreen(onComplete: () => completed = true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(completed, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(OnboardingStore.storageKey), isTrue);
  });

  testWidgets('remains usable at 200% text scaling on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AuxiliaTheme.light(),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(textScaler: const TextScaler.linear(2)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const OnboardingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Your responsibilities, organised.'), findsOneWidget);
  });
}
