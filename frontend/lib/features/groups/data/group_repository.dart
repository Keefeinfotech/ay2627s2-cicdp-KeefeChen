/// File Name: group_repository.dart
/// Description: Repository for managing groups (local + API).
/// Author: Keefe Chen
library;

import 'package:dio/dio.dart';
import '../models/group_model.dart';

class GroupRepository {
  final Dio _dio = Dio();

  GroupRepository() {
    _dio.options.baseUrl = 'http://localhost:3000/api';
  }

  /// Get all groups for the user
  Future<List<GroupModel>> fetchAll() async {
    final response = await _dio.get('/groups');
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((json) => GroupModel.fromJson(json)).toList();
    }
    throw Exception('Failed to fetch groups');
  }

  /// Create a new group
  Future<GroupModel> create(String name, String description) async {
    final response = await _dio.post(
      '/groups',
      data: {'name': name, 'description': description},
    );
    if (response.statusCode == 201) {
      return GroupModel.fromJson(response.data);
    }
    throw Exception('Failed to create group');
  }

  /// Get group by ID
  Future<GroupModel?> fetchById(String id) async {
    final response = await _dio.get('/groups/$id');
    if (response.statusCode == 200) {
      return GroupModel.fromJson(response.data);
    }
    return null;
  }

  /// Update a group
  Future<GroupModel?> update(String id, String name, String description) async {
    final response = await _dio.put(
      '/groups/$id',
      data: {'name': name, 'description': description},
    );
    if (response.statusCode == 200) {
      return GroupModel.fromJson(response.data);
    }
    return null;
  }

  /// Delete a group
  Future<void> delete(String id) async {
    final response = await _dio.delete('/groups/$id');
    if (response.statusCode != 200) {
      throw Exception('Failed to delete group');
    }
  }
}
