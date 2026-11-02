import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the product introduction has been completed.
///
/// The key is versioned so a future onboarding redesign can intentionally show
/// the introduction again without clearing unrelated preferences.
class OnboardingStore {
  OnboardingStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String storageKey = 'auxilia.onboarding.completed.v1';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? await SharedPreferences.getInstance();

  Future<bool> isComplete() async {
    final prefs = await _prefs;
    return prefs.getBool(storageKey) ?? false;
  }

  Future<void> complete() async {
    final prefs = await _prefs;
    await prefs.setBool(storageKey, true);
  }
}
