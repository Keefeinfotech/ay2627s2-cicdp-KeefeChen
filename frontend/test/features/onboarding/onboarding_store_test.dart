import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/features/onboarding/data/onboarding_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('defaults to incomplete and persists completion', () async {
    final store = OnboardingStore();

    expect(await store.isComplete(), isFalse);

    await store.complete();

    expect(await store.isComplete(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(OnboardingStore.storageKey), isTrue);
  });

  test('reads an existing completion flag', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      OnboardingStore.storageKey: true,
    });

    expect(await OnboardingStore().isComplete(), isTrue);
  });
}
