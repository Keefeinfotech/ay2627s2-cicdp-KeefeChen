import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/avatar_style.dart';

/// Durable, per-workspace avatar preference.
///
/// The store is a [ChangeNotifier] so the sidebar, dashboard and profile can
/// all reflect a change immediately without a global singleton.
class AvatarStore extends ChangeNotifier {
  AvatarStore({required this.ownerId, SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _keyPrefix = 'auxilia.avatar.v1.';
  static const int schemaVersion = 1;

  final String ownerId;
  SharedPreferences? _preferences;

  AvatarStyle _style = const AvatarStyle();
  bool _loaded = false;

  AvatarStyle get style => _style;
  bool get isLoaded => _loaded;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  String get _key => '$_keyPrefix$ownerId';

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await _prefs;
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final version = decoded['version'];
          if (version is int && version <= schemaVersion) {
            final parsed = AvatarStyle.tryFromJson(decoded['style']);
            if (parsed != null) _style = parsed;
          }
        }
      }
    } on FormatException {
      // A malformed preference falls back to the default avatar rather than
      // blocking sign-in.
      _style = const AvatarStyle();
    } catch (_) {
      _style = const AvatarStyle();
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> save(AvatarStyle style) async {
    _style = style;
    _loaded = true;
    notifyListeners();
    try {
      final prefs = await _prefs;
      await prefs.setString(
        _key,
        jsonEncode(<String, dynamic>{
          'version': schemaVersion,
          'style': style.toJson(),
        }),
      );
    } catch (_) {
      // Persistence is best-effort: the in-memory avatar still updates for the
      // current session.
    }
  }

  Future<void> reset() => save(const AvatarStyle());
}
