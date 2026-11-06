import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/assistant/data/assistant_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AssistantService', () {
    test('sends the original message contract and returns the reply', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(<String, String>{'reply': 'Try breaking it into steps.'}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final service = AssistantService(
        api: ApiClient(baseUrl: 'https://auxilia.test', client: client),
      );

      final reply = await service.sendMessage(
        token: 'token-123',
        message: 'Help me plan my week.',
      );

      expect(reply, 'Try breaking it into steps.');
      expect(captured.url.toString(), 'https://auxilia.test/api/ai/chat');
      expect(captured.headers['Authorization'], 'Bearer token-123');
      expect(captured.headers['Content-Type'], 'application/json');
      final payload = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(payload['message'], 'Help me plan my week.');
      expect(payload['context'], isEmpty);
    });

    test('falls back when the reply is missing', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode(<String, dynamic>{}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final service = AssistantService(
        api: ApiClient(baseUrl: 'https://auxilia.test', client: client),
      );

      expect(
        await service.sendMessage(token: 'token-123', message: 'Hello'),
        'No response received.',
      );
    });

    test('prepares a task draft from structured server output', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'reply': 'Review this draft.',
            'draft': <String, dynamic>{
              'title': 'Revise calculus',
              'description': 'Review chapter 4',
              'course': 'Maths',
              'dueDate': '2026-11-07',
              'priority': 'high',
            },
            'clarification': null,
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final service = AssistantService(
        api: ApiClient(baseUrl: 'https://auxilia.test', client: client),
      );

      final response = await service.prepareTaskDraft(
        token: 'token-123',
        message: 'Create a task to revise calculus',
        context: const <Map<String, String>>[
          <String, String>{'role': 'user', 'content': 'Create a task'},
        ],
      );

      expect(response.draft?.title, 'Revise calculus');
      expect(response.draft?.dueDate, DateTime(2026, 11, 7));
      expect(response.draft?.priority, 'high');
      expect(captured.url.toString(), 'https://auxilia.test/api/ai/draft');
      expect(captured.headers['Authorization'], 'Bearer token-123');
      final payload = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(payload['message'], 'Create a task to revise calculus');
      expect(payload['context'], <Map<String, String>>[
        <String, String>{'role': 'user', 'content': 'Create a task'},
      ]);
    });

    test('surfaces the server error message and status', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode(<String, String>{
            'error': 'Too many requests.',
            'code': 'RATE_LIMITED',
          }),
          429,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final service = AssistantService(
        api: ApiClient(baseUrl: 'https://auxilia.test', client: client),
      );

      await expectLater(
        service.sendMessage(token: 'token-123', message: 'Hello'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.message, 'message', 'Too many requests.')
              .having((error) => error.statusCode, 'statusCode', 429)
              .having((error) => error.code, 'code', 'RATE_LIMITED'),
        ),
      );
    });
  });
}
