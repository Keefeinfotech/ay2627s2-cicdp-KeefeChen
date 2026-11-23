/// File Name: reminder_repository.dart
/// Description: Repository for managing reminders against the Auxilia API.
/// Author: Keefe Chen
library;

import 'package:dio/dio.dart';

import '../../authentication/data/session_store.dart';
import '../models/reminder_model.dart';

class ReminderRepository {
  final Dio _dio;
  final SessionStore _sessionStore;

  ReminderRepository({Dio? dio, SessionStore? sessionStore})
    : _dio = dio ?? Dio(),
      _sessionStore = sessionStore ?? SessionStore() {
    _dio.options.baseUrl =
        "${const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000')}/api/v1";
    _dio.options.connectTimeout = const Duration(seconds: 12);
    _dio.options.receiveTimeout = const Duration(seconds: 12);
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final session = await _sessionStore.read();
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.token}';
          }
          handler.next(options);
        },
      ),
    );
  }

  /// Unwraps the `{ message, data }` envelope returned by the API.
  List<dynamic> _listFrom(dynamic body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is List) return data;
    }
    if (body is List) return body; // tolerate legacy bare arrays
    return const [];
  }

  Map<String, dynamic> _objectFrom(dynamic body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return body; // tolerate legacy flat objects
    }
    return <String, dynamic>{};
  }

  /// Get all reminders for the user
  Future<List<ReminderModel>> fetchAll() async {
    final response = await _dio.get('/reminders');
    if (response.statusCode == 200) {
      return _listFrom(response.data)
          .map((json) => ReminderModel.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to fetch reminders');
  }

  /// Create a new reminder
  Future<ReminderModel> create(String message, DateTime dueAt) async {
    final response = await _dio.post(
      '/reminders',
      data: {'message': message, 'dueAt': dueAt.toIso8601String()},
    );
    if (response.statusCode == 201) {
      return ReminderModel.fromJson(_objectFrom(response.data));
    }
    throw Exception('Failed to create reminder');
  }

  /// Mark a reminder as completed
  Future<ReminderModel> complete(String id) async {
    final response = await _dio.post('/reminders/$id/complete');
    if (response.statusCode == 200) {
      return ReminderModel.fromJson(_objectFrom(response.data));
    }
    throw Exception('Failed to complete reminder');
  }

  /// Delete a reminder
  Future<void> delete(String id) async {
    final response = await _dio.delete('/reminders/$id');
    final code = response.statusCode ?? 0;
    if (code != 200 && code != 204) {
      throw Exception('Failed to delete reminder');
    }
  }

  /// Get pending reminders
  Future<List<ReminderModel>> fetchPending() async {
    final response = await _dio.get('/reminders/pending');
    if (response.statusCode == 200) {
      return _listFrom(response.data)
          .map((json) => ReminderModel.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to fetch pending reminders');
  }
}
