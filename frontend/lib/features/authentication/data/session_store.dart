import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/session.dart';

export '../models/session.dart';

/// Stores the session token in platform secure storage rather than plain
/// preferences or source code.
class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _tokenKey = 'auxilia.session.token';
  static const String _emailKey = 'auxilia.session.email';
  static const String _nameKey = 'auxilia.session.name';

  final FlutterSecureStorage _storage;

  Future<Session?> read() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final email = await _storage.read(key: _emailKey);
      if (token == null || token.isEmpty || email == null || email.isEmpty) {
        return null;
      }
      final name = await _storage.read(key: _nameKey);
      return Session(token: token, email: email, name: name);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(Session session) async {
    try {
      await _storage.write(key: _tokenKey, value: session.token);
      await _storage.write(key: _emailKey, value: session.email);
      if (session.name == null) {
        await _storage.delete(key: _nameKey);
      } else {
        await _storage.write(key: _nameKey, value: session.name);
      }
    } catch (_) {
      throw SessionException(
        'Signed in, but the session could not be stored securely on this device.',
      );
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _emailKey);
      await _storage.delete(key: _nameKey);
    } catch (_) {
      throw SessionException(
        'The session could not be removed from this device.',
      );
    }
  }
}
