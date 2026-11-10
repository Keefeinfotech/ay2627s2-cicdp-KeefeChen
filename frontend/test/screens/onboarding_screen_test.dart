import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/features/onboarding/data/onboarding_store.dart';
import 'package:frontend/features/onboarding/screens/onboarding_screen.dart';
import 'package:frontend/core/theme/app_theme.dart';

class _FailingOnboardingStore extends OnboardingStore {
  @override
  Future<void> complete() async => throw StateError('storage unavailable');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows three product-led slides and completes onboarding', (
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

    expect(find.text('ORGANISE YOUR WORK'), findsOneWidget);
    expect(find.text('Everything you need, in one place.'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Back'), findsNothing);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('STAY AHEAD OF DEADLINES'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('ORGANISE YOUR WORK'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('COLLABORATE WITH OTHERS'), findsOneWidget);
    expect(
      find.text('Stay in sync with the people who matter.'),
      findsOneWidget,
    );

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

  testWidgets('skip remains available on the last slide', (tester) async {
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AuxiliaTheme.light(),
        home: OnboardingScreen(onComplete: () => completed = true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(completed, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(OnboardingStore.storageKey), isTrue);
  });

  testWidgets('shows a retryable message when completion cannot be saved', (
    tester,
  ) async {
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AuxiliaTheme.light(),
        home: OnboardingScreen(
          store: _FailingOnboardingStore(),
          onComplete: () => completed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Could not save your progress. Check your device storage and try again.',
      ),
      findsOneWidget,
    );
    expect(completed, isFalse);
    expect(find.text('Skip'), findsOneWidget);
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
    expect(find.text('Everything you need, in one place.'), findsOneWidget);
  });
}
