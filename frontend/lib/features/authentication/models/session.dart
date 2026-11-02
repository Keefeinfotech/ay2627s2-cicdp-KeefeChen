class SessionException implements Exception {
  SessionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class Session {
  const Session({required this.token, required this.email, this.name});

  final String token;
  final String email;
  final String? name;

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
    return Session(
      token: token,
      email: email,
      name: name is String ? name : null,
    );
  }
}
