import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/home/data/api_task_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('fetches every page of remote tasks for a large account', () async {
    SharedPreferences.setMockInitialValues({});
    final requestedPages = <int>[];
    final client = MockClient((request) async {
      final page = int.parse(request.url.queryParameters['page'] ?? '1');
      requestedPages.add(page);
      final hasNext = page < 3;
      final items = List<Map<String, dynamic>>.generate(
        page == 3 ? 50 : 100,
        (index) => <String, dynamic>{
          'id': 'task-$page-$index',
          'title': 'Task $index of page $page',
        },
      );
      return http.Response(
        jsonEncode(<String, dynamic>{
          'message': 'Tasks retrieved successfully.',
          'data': items,
          'pagination': <String, dynamic>{
            'page': page,
            'limit': 100,
            'totalItems': 250,
            'totalPages': 3,
            'hasNextPage': hasNext,
            'hasPreviousPage': page > 1,
          },
        }),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    final repository = ApiTaskRepository(
      token: 'token-123',
      api: ApiClient(baseUrl: 'https://auxilia.test', client: client),
    );

    final tasks = await repository.load('owner-1');

    expect(requestedPages, <int>[1, 2, 3]);
    expect(tasks.length, 250);
  });
}
