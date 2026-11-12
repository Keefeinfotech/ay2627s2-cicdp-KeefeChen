import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A failed API call with a message that is safe to show to a user.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  bool get isUnauthorized => statusCode == 401;

  /// Server-side failures are retryable; the body is never surfaced because it
  /// can contain stack traces or infrastructure details.
  bool get isServerError => statusCode != null && statusCode! >= 500;

  @override
  String toString() => message;
}

/// Small JSON client shared by the authentication and feature services.
///
/// Transport, timeout and error shape are consistent across features. The
/// client also refuses to send credentials to a plaintext non-loopback origin,
/// so a misconfigured `API_BASE_URL` cannot silently downgrade transport
/// security in a release build.
///
/// When a [tokenRefresher] is registered (see `main.dart`), a request that is
/// rejected with a 401 is retried once with a silently renewed access token;
/// concurrent 401s share a single renewal. Without a registered refresher the
/// client behaves exactly as a plain HTTP wrapper.
typedef TokenRefresher = Future<String?> Function();

class ApiClient {
  ApiClient({String? baseUrl, http.Client? client, Duration? timeout})
    : baseUrl = _validateBaseUrl(baseUrl ?? defaultBaseUrl),
      _client = client ?? http.Client(),
      _timeout = timeout ?? const Duration(seconds: 12);

  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  /// Registered once at startup (see `main.dart`); when null, 401s surface
  /// immediately exactly as before.
  static TokenRefresher? tokenRefresher;

  /// Newest access token issued to this device, remembered after each
  /// successful renewal so stale copies held by screens can be upgraded.
  static String? _latestToken;

  /// Single-flight renewal: concurrent 401s await the same future instead of
  /// firing duplicate refresh requests (which would invalidate each other).
  static Future<String?>? _pendingRefresh;

  /// Forgets the remembered access token — called on logout and after a
  /// failed renewal so a signed-out device never reuses old credentials.
  static void resetTokenCache() {
    _latestToken = null;
    _pendingRefresh = null;
  }

  /// Loopback hosts allowed to use plain HTTP for local development.
  static const Set<String> _loopbackHosts = <String>{
    'localhost',
    '127.0.0.1',
    '::1',
    '10.0.2.2', // Android emulator's host alias.
  };

  final String baseUrl;
  final http.Client _client;
  final Duration _timeout;

  /// Returns [value] when it is an absolute HTTPS URL or a loopback HTTP URL.
  ///
  /// Throws [ArgumentError] otherwise. Keep local development on
  /// `http://localhost`, and configure deployed builds with an HTTPS origin.
  static String _validateBaseUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ArgumentError.value(
        value,
        'baseUrl',
        'API_BASE_URL must be an absolute URL such as https://api.example.com.',
      );
    }

    final bool isHttps = uri.scheme == 'https';
    final bool isLoopbackHttp =
        uri.scheme == 'http' && _loopbackHosts.contains(uri.host);

    if (!isHttps && !isLoopbackHttp) {
      throw ArgumentError.value(
        value,
        'baseUrl',
        'Use HTTPS for API traffic. Plain HTTP is only allowed for localhost.',
      );
    }
    return value;
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? token,
  }) {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);

    return _send(
      token,
      (effective) => _client.get(uri, headers: _headers(token: effective)),
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) {
    final uri = Uri.parse('$baseUrl$path');
    return _send(token, (effective) {
      return _client.post(
        uri,
        headers: _headers(token: effective, json: true),
        body: jsonEncode(body),
      );
    });
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) {
    final uri = Uri.parse('$baseUrl$path');
    return _send(token, (effective) {
      return _client.patch(
        uri,
        headers: _headers(token: effective, json: true),
        body: jsonEncode(body),
      );
    });
  }

  Future<void> deleteJson(String path, {String? token}) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _exchange(
      token,
      (effective) => _client.delete(uri, headers: _headers(token: effective)),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    throw _errorFor(response, _decodeBody(response.body));
  }

  Map<String, String> _headers({String? token, bool json = false}) {
    return <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Decodes a successful response, first renewing the access token once if
  /// the server rejected the original attempt with a 401.
  Future<Map<String, dynamic>> _send(
    String? token,
    Future<http.Response> Function(String? token) request,
  ) async {
    final response = await _exchange(token, request);
    return _handleResponse(response);
  }

  /// Runs [request] with the effective token; on 401, with a renewed token.
  ///
  /// Only requests that carried a bearer token are renewed — that keeps the
  /// refresh call itself (which is sent without one) from ever recursing —
  /// and only ever one retry is made, so a genuinely dead session surfaces
  /// the second 401 instead of looping.
  Future<http.Response> _exchange(
    String? token,
    Future<http.Response> Function(String? token) request,
  ) async {
    final effective = _effectiveToken(token);
    final response = await _execute(() => request(effective));

    if (response.statusCode != 401) return response;
    if (effective == null || effective.isEmpty || tokenRefresher == null) {
      return response;
    }

    final renewed = await _renewToken();
    if (renewed == null || renewed.isEmpty) return response;

    return _execute(() => request(renewed));
  }

  /// Renews the access token, sharing one in-flight renewal across every
  /// request that hits a 401 at the same time.
  static Future<String?> _renewToken() {
    final pending = _pendingRefresh;
    if (pending != null) return pending;

    final refresher = tokenRefresher;
    if (refresher == null) return Future<String?>.value(null);

    // Failures resolve to null so the caller surfaces the original 401
    // rather than whatever went wrong inside the refresher.
    final renewal = () async {
      try {
        final token = await refresher();
        if (token != null && token.isNotEmpty) _latestToken = token;
        return token;
      } catch (_) {
        return null;
      }
    }();

    // Clear only after this call stack has stored the future, and only if it
    // is still the current one.
    renewal.then((_) {
      if (identical(_pendingRefresh, renewal)) _pendingRefresh = null;
    });
    _pendingRefresh = renewal;
    return renewal;
  }

  /// The token to send: upgrades a stale copy of the caller's token to the
  /// newest one, but only when both belong to the same user — a previous
  /// account's token is never silently substituted.
  static String? _effectiveToken(String? token) {
    if (token == null || token.isEmpty) return token;
    final latest = _latestToken;
    if (latest == null || latest.isEmpty || latest == token) return token;
    return _sameSubject(token, latest) ? latest : token;
  }

  /// True when both JWTs are well-formed and carry the same `sub` claim.
  static bool _sameSubject(String token, String other) {
    final subject = _subjectOf(token);
    return subject != null && subject == _subjectOf(other);
  }

  /// Reads the (unverified) `sub` claim of a JWT for identity matching only.
  static String? _subjectOf(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is Map && payload['sub'] is String) {
        return payload['sub'] as String;
      }
    } catch (_) {
      // Not a JWT (or corrupt): treated as non-matchable.
    }
    return null;
  }

  Future<http.Response> _execute(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException(
        'The server took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw ApiException(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final data = _decodeBody(response.body);
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

    if (isSuccess) {
      if (data == null) {
        // 204 No Content (and other body-less successes) decode to an empty
        // map so callers can inspect fields without a null check. A non-empty
        // body that is not JSON is still an error.
        if (response.body.isEmpty) return <String, dynamic>{};
        throw ApiException(
          'The server returned an unexpected response.',
          statusCode: response.statusCode,
        );
      }
      return data;
    }

    throw _errorFor(response, data);
  }

  ApiException _errorFor(http.Response response, Map<String, dynamic>? data) {
    final statusCode = response.statusCode;
    final code = data?['code'] as String?;

    // 5xx bodies are untrusted server internals. Keep the code for retry and
    // conflict logic but never render the raw message.
    if (statusCode >= 500) {
      return ApiException(
        'The server could not complete the request. Please try again shortly.',
        statusCode: statusCode,
        code: code,
      );
    }

    final message =
        data?['error'] as String? ??
        data?['message'] as String? ??
        'Request failed ($statusCode). Please try again.';

    return ApiException(message, statusCode: statusCode, code: code);
  }

  Map<String, dynamic>? _decodeBody(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } on FormatException {
      return null;
    }
    return null;
  }

  void close() => _client.close();
}
