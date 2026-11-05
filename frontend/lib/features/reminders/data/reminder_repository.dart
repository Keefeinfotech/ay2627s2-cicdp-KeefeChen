/// File Name: reminder_repository.dart
/// Description: Repository for managing reminders (local + API).
/// Author: Keefe Chen
library;

import 'package:dio/dio.dart';
import '../models/reminder_model.dart';

class ReminderRepository {
  final Dio _dio = Dio();

  ReminderRepository() {
    _dio.options.baseUrl = 'http://localhost:3000/api';
  }

  /// Get all reminders for the user
  Future<List<ReminderModel>> fetchAll() async {
    final response = await _dio.get('/reminders');
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((json) => ReminderModel.fromJson(json)).toList();
    }
    throw Exception('Failed to fetch reminders');
  }

  /// Create a new reminder
  Future<ReminderModel> create(String message, DateTime dueAt) async {
    final response = await _dio.post('/reminders', data: {
      'message': message,
      'dueAt': dueAt.toIso8601String(),
    });
    if (response.statusCode == 201) {
      return ReminderModel.fromJson(response.data);
    }
    throw Exception('Failed to create reminder');
  }

  /// Mark a reminder as completed
  Future<ReminderModel> complete(String id) async {
    final response = await _dio.post('/reminders/$id/complete');
    if (response.statusCode == 200) {
      return ReminderModel.fromJson(response.data);
    }
    throw Exception('Failed to complete reminder');
  }

  /// Delete a reminder
  Future<void> delete(String id) async {
    final response = await _dio.delete('/reminders/$id');
    if (response.statusCode != 200) {
      throw Exception('Failed to delete reminder');
    }
  }

  /// Get pending reminders
  Future<List<ReminderModel>> fetchPending() async {
    final response = await _dio.get('/reminders/pending');
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((json) => ReminderModel.fromJson(json)).toList();
    }
    throw Exception('Failed to fetch pending reminders');
  }
}