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
class ApiClient {
  ApiClient({String? baseUrl, http.Client? client, Duration? timeout})
    : baseUrl = _validateBaseUrl(baseUrl ?? defaultBaseUrl),
      _client = client ?? http.Client(),
      _timeout = timeout ?? const Duration(seconds: 12);

  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

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

    return _send(() => _client.get(uri, headers: _headers(token: token)));
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) {
    final uri = Uri.parse('$baseUrl$path');
    return _send(
      () => _client.post(
        uri,
        headers: _headers(token: token, json: true),
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) {
    final uri = Uri.parse('$baseUrl$path');
    return _send(
      () => _client.patch(
        uri,
        headers: _headers(token: token, json: true),
        body: jsonEncode(body),
      ),
    );
  }

  Future<void> deleteJson(String path, {String? token}) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _execute(
      () => _client.delete(uri, headers: _headers(token: token)),
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

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    final response = await _execute(request);
    return _handleResponse(response);
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
