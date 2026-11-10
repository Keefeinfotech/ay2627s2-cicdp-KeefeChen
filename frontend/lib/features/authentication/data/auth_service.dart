import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'captcha.dart';
import 'session_store.dart';

class AuthService {
  AuthService({ApiClient? api, SessionStore? sessions})
    : _api = api ?? ApiClient(),
      _sessions = sessions ?? SessionStore();

  /// Public Turnstile site key, supplied at build time:
  ///   flutter run --dart-define=TURNSTILE_SITE_KEY=...
  /// Empty means CAPTCHA is not used on this client (local development).
  static const String captchaSiteKey = String.fromEnvironment(
    'TURNSTILE_SITE_KEY',
  );

  bool get requiresCaptcha => isCaptchaSupported && captchaSiteKey.isNotEmpty;

  final ApiClient _api;
  final SessionStore _sessions;

  Future<Session> signup({
    String? name,
    required String email,
    required String password,
  }) async {
    String? captchaToken;
    if (requiresCaptcha) {
      try {
        captchaToken = await _captchaToken();
      } on ApiException {
        rethrow;
      }
    }

    final data = await _api.postJson(ApiEndpoints.authSignup, <String, dynamic>{
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'captchaToken': ?captchaToken,
    });
    return _persist(data);
  }

  Future<Session> login({
    required String email,
    required String password,
  }) async {
    String? captchaToken;
    if (requiresCaptcha) {
      try {
        captchaToken = await _captchaToken();
      } on ApiException {
        rethrow;
      }
    }

    final data = await _api.postJson(ApiEndpoints.authLogin, <String, dynamic>{
      'email': email.trim(),
      'password': password,
      'captchaToken': ?captchaToken,
    });
    return _persist(data);
  }

  Future<void> forgotPassword({required String email}) async {
    String? captchaToken;
    if (requiresCaptcha) {
      try {
        captchaToken = await _captchaToken();
      } on ApiException {
        rethrow;
      }
    }

    await _api.postJson(ApiEndpoints.authForgotPassword, <String, dynamic>{
      'email': email.trim(),
      'captchaToken': ?captchaToken,
    });
  }

  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    await _api.postJson(ApiEndpoints.authResetPassword, <String, dynamic>{
      'token': token.trim(),
      'password': password,
    });
  }

  Future<Session?> restore() => _sessions.read();

  /// Validates [session] against the backend. Returns the session when valid,
  /// or `null` when expired/replaced/invalid (and clears local storage).
  Future<Session?> validateSession(Session session) async {
    try {
      await _api.getJson(ApiEndpoints.authMe, token: session.token);
      return session;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await clearSession();
        return null;
      }
      // Transient/network errors: keep local session and let feature calls retry.
      return session;
    } catch (_) {
      return session;
    }
  }

  /// Clears local session state. Swallows storage errors to avoid blocking
  /// auth-recovery flows.
  Future<void> clearSession() async {
    try {
      await _sessions.clear();
    } catch (_) {}
  }

  /// Best-effort server logout, then clears local session state.
  Future<void> logout({String? token}) async {
    final bearer = token ?? (await restore())?.token;
    if (bearer != null && bearer.isNotEmpty) {
      try {
        await _api.postJson(
          ApiEndpoints.authLogout,
          const <String, dynamic>{},
          token: bearer,
        );
      } catch (_) {}
    }
    await clearSession();
  }

  Future<Session> _persist(Map<String, dynamic> data) async {
    final session = Session.fromApi(data);
    await _sessions.write(session);
    return session;
  }

  /// Requests a Turnstile token when the client is configured for CAPTCHA.
  ///
  /// Throws [ApiException] when verification cannot be completed so the user
  /// sees a clear message instead of a silent failure.
  Future<String?> _captchaToken() async {
    if (!requiresCaptcha) return null;

    final token = await requestCaptchaToken(siteKey: captchaSiteKey);
    if (token == null || token.isEmpty) {
      throw ApiException(
        'Verification could not be completed. Please try again.',
        code: 'CAPTCHA_FAILED',
      );
    }
    return token;
  }
}
