class SessionException implements Exception {
  SessionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class Session {
  const Session({
    required this.token,
    required this.email,
    this.name,
    this.refreshToken,
  });

  final String token;
  final String email;
  final String? name;

  /// Opaque refresh token bound to this device's session.
  ///
  /// Kept in secure storage next to the access token so the app can renew the
  /// session silently instead of signing the user out when the (short-lived)
  /// access token expires. Null for sessions stored before refresh tokens
  /// existed; those are renewed by signing in again.
  final String? refreshToken;

  String get displayName {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return email;
    return trimmed;
  }

  factory Session.fromApi(Map<String, dynamic> data) {
    final token = data['token'];
    final user = data['user'];
    if (token is! String || token.isEmpty || user is! Map) {
      throw SessionException(
        'The server returned an incomplete sign-in response.',
      );
    }

    final email = user['email'];
    if (email is! String || email.isEmpty) {
      throw SessionException(
        'The server returned an incomplete sign-in response.',
      );
    }

    final name = user['name'];
    final refreshToken = data['refreshToken'];
    return Session(
      token: token,
      email: email,
      name: name is String ? name : null,
      refreshToken: refreshToken is String && refreshToken.isNotEmpty
          ? refreshToken
          : null,
    );
  }
}
