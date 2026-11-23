import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../presentation/models/calendar_skin.dart';

/// Durable, per-workspace calendar appearance preferences.
///
/// The store owns the selected skin, the shape of the day squares and the
/// user-applied marks on individual days. It mirrors [AvatarStore]'s
/// best-effort persistence model: changes are visible in memory immediately
/// and a failure to write never blocks the UI.
class CalendarPreferencesStore extends ChangeNotifier {
  CalendarPreferencesStore({required this.ownerId, SharedPreferences? prefs})
    // ignore: prefer_initializing_formals
    : _prefs = prefs;

  static const String keyPrefix = 'auxilia.calendar.preferences.v1.';
  static const int schemaVersion = 1;

  final String ownerId;
  SharedPreferences? _prefs;

  CalendarPreferences _value = const CalendarPreferences();
  bool _loaded = false;

  CalendarPreferences get preferences => _value;
  bool get isLoaded => _loaded;

  String get _key => '$keyPrefix$ownerId';

  Future<SharedPreferences> get _sharedPreferences async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Alias kept next to the store so callers do not need the model import.
  static String dateKey(DateTime date) => calendarDateKey(date);

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await _sharedPreferences;
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['version'] is int) {
          final version = decoded['version'] as int;
          if (version <= schemaVersion) {
            final parsed = CalendarPreferences.tryFromJson(decoded['prefs']);
            if (parsed != null) _value = parsed;
          }
        }
      }
    } on FormatException {
      _value = const CalendarPreferences();
    } catch (_) {
      _value = const CalendarPreferences();
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> save(CalendarPreferences value) async {
    _value = value;
    _loaded = true;
    notifyListeners();
    try {
      final prefs = await _sharedPreferences;
      await prefs.setString(
        _key,
        jsonEncode(<String, dynamic>{
          'version': schemaVersion,
          'prefs': value.toJson(),
        }),
      );
    } catch (_) {
      // Persistence is best-effort; the current session still updates.
    }
  }

  Future<void> setSkin(CalendarSkin skin) => save(_value.copyWith(skin: skin));

  Future<void> setSquareStyle(CalendarSquareStyle style) =>
      save(_value.copyWith(squareStyle: style));

  Future<void> setMark(DateTime date, CalendarMark mark) {
    final marks = Map<String, String>.from(_value.marks);
    final key = dateKey(date);
    if (mark == CalendarMark.none) {
      marks.remove(key);
    } else {
      marks[key] = mark.name;
    }
    return save(_value.copyWith(marks: marks));
  }

  Future<void> clearMarks() =>
      save(_value.copyWith(marks: const <String, String>{}));

  Future<void> reset() => save(const CalendarPreferences());
}
