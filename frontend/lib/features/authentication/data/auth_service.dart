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

  /// Best-effort sign-out: tells the backend to revoke this session, then
  /// always clears local state so the device signs out even offline.
  Future<void> logout() async {
    Session? session;
    try {
      session = await _sessions.read();
    } catch (_) {
      // Nothing readable; clearing below is still attempted.
    }

    try {
      final token = session?.token;
      if (token != null && token.isNotEmpty) {
        await _api.postJson(
          ApiEndpoints.authLogout,
          <String, dynamic>{},
          token: token,
        );
      }
    } on ApiException {
      // The backend may already consider the session gone (or be
      // unreachable); local sign-out must not fail because of that.
    } on SessionException {
      // Unreadable session: proceed to clear whatever is stored.
    }

    ApiClient.resetTokenCache();
    await _sessions.clear();
  }

  /// Renews the access token using the stored refresh token.
  ///
  /// Registered as [ApiClient.tokenRefresher] from `main()` so API calls that
  /// hit an expired access token are retried transparently. Returns null when
  /// renewal is impossible - no stored refresh token, or the backend rejected
  /// it - in which case the local session is dropped so the app falls back to
  /// sign-in instead of looping on 401s.
  Future<String?> refreshSilently() async {
    Session? current;
    try {
      current = await _sessions.read();
    } catch (_) {
      return null;
    }
    final refreshToken = current?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      // No bearer header: the refresh token itself is the credential, and an
      // unauthenticated refresh call can never trigger another renewal.
      final data = await _api.postJson(
        ApiEndpoints.authRefresh,
        <String, dynamic>{'refreshToken': refreshToken},
      );
      final renewed = await _persist(data);
      return renewed.token;
    } on ApiException catch (error) {
      // Only an explicit rejection from the backend means the refresh token
      // is dead (revoked, expired, replayed) - then the local session is
      // dropped so the app falls back to sign-in instead of looping on 401s.
      // A network blip or 5xx keeps the stored session; the next attempt can
      // still succeed.
      if (error.statusCode != null && error.statusCode! < 500) {
        ApiClient.resetTokenCache();
        try {
          await _sessions.clear();
        } catch (_) {
          // Best effort - the cached token state above is what matters.
        }
      }
      return null;
    } on SessionException {
      return null;
    }
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
