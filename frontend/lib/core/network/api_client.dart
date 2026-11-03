import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Small JSON client shared by the authentication and assistant features.
///
/// The request format, timeout, base URL and error shape are unchanged from the
/// original implementation; only the location and endpoint constants moved.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? client, Duration? timeout})
    : baseUrl = baseUrl ?? defaultBaseUrl,
      _client = client ?? http.Client(),
      _timeout = timeout ?? const Duration(seconds: 12);

  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  final String baseUrl;
  final http.Client _client;
  final Duration _timeout;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? token,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);

    late final http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: <String, String>{
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw ApiException(
        'The server took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw ApiException(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');

    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw ApiException(
        'The server took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw ApiException(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');

    late final http.Response response;
    try {
      response = await _client
          .patch(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw ApiException(
        'The server took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw ApiException(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    return _handleResponse(response);
  }

  Future<void> deleteJson(String path, {String? token}) async {
    final uri = Uri.parse('$baseUrl$path');

    late final http.Response response;
    try {
      response = await _client
          .delete(
            uri,
            headers: <String, String>{
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw ApiException(
        'The server took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw ApiException(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final data = _decodeBody(response.body);
    throw ApiException(
      data?['error'] as String? ??
          data?['message'] as String? ??
          'Request failed (${response.statusCode}). Please try again.',
      statusCode: response.statusCode,
      code: data?['code'] as String?,
    );
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

    throw ApiException(
      data?['error'] as String? ??
          data?['message'] as String? ??
          'Request failed (${response.statusCode}). Please try again.',
      statusCode: response.statusCode,
      code: data?['code'] as String?,
    );
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
