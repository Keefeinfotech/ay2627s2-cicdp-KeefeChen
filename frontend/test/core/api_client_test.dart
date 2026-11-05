import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/core/network/api_client.dart';

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

ApiClient _client(
  MockClient client, {
  String baseUrl = 'https://auxilia.test',
  Duration? timeout,
}) {
  return ApiClient(baseUrl: baseUrl, client: client, timeout: timeout);
}

void main() {
  group('transport security', () {
    test('accepts HTTPS and loopback HTTP origins', () {
      expect(
        () => ApiClient(baseUrl: 'https://api.auxilia.app'),
        returnsNormally,
      );
      expect(
        () => ApiClient(baseUrl: 'http://localhost:3000'),
        returnsNormally,
      );
      expect(() => ApiClient(baseUrl: 'http://10.0.2.2:3000'), returnsNormally);
    });

    test('rejects plaintext non-loopback origins', () {
      expect(
        () => ApiClient(baseUrl: 'http://api.auxilia.app'),
        throwsArgumentError,
      );
      expect(() => ApiClient(baseUrl: 'not-a-url'), throwsArgumentError);
      expect(
        () => ApiClient(baseUrl: 'ftp://auxilia.app'),
        throwsArgumentError,
      );
    });
  });

  group('requests', () {
    test('sends a bearer token only when one is available', () async {
      String? authorization;
      final client = _client(
        MockClient((request) async {
          authorization = request.headers['Authorization'];
          return _json(<String, dynamic>{'ok': true});
        }),
      );

      await client.getJson('/api/tasks', token: 'token-1');
      expect(authorization, 'Bearer token-1');

      await client.getJson('/api/tasks', token: '');
      expect(authorization, isNull);

      await client.getJson('/api/tasks');
      expect(authorization, isNull);
    });

    test('serialises JSON bodies for POST and PATCH', () async {
      final bodies = <String>[];
      final client = _client(
        MockClient((request) async {
          bodies.add(request.body);
          return _json(<String, dynamic>{'ok': true});
        }),
      );

      await client.postJson('/api/tasks', <String, dynamic>{'title': 'One'});
      await client.patchJson('/api/tasks/1', <String, dynamic>{'title': 'Two'});

      expect(jsonDecode(bodies[0]), <String, dynamic>{'title': 'One'});
      expect(jsonDecode(bodies[1]), <String, dynamic>{'title': 'Two'});
    });

    test('builds query strings', () async {
      Uri? uri;
      final client = _client(
        MockClient((request) async {
          uri = request.url;
          return _json(<String, dynamic>{'ok': true});
        }),
      );

      await client.getJson(
        '/api/tasks',
        query: <String, String>{'page': '2', 'limit': '20'},
      );

      expect(uri?.path, '/api/tasks');
      expect(uri?.queryParameters, <String, String>{
        'page': '2',
        'limit': '20',
      });
    });
  });

  group('errors', () {
    test('surfaces 4xx messages from the server', () async {
      final client = _client(
        MockClient((_) async {
          return _json(<String, dynamic>{
            'code': 'VALIDATION_ERROR',
            'message': 'Task title is required.',
          }, statusCode: 422);
        }),
      );

      await expectLater(
        client.postJson('/api/tasks', <String, dynamic>{}),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 422)
              .having((error) => error.code, 'code', 'VALIDATION_ERROR')
              .having(
                (error) => error.message,
                'message',
                'Task title is required.',
              ),
        ),
      );
    });

    test('never renders raw 5xx bodies', () async {
      final client = _client(
        MockClient((_) async {
          return _json(<String, dynamic>{
            'code': 'INTERNAL_ERROR',
            'message': 'MongoServerError at /srv/app/db.ts:42',
          }, statusCode: 500);
        }),
      );

      await expectLater(
        client.getJson('/api/tasks'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 500)
              .having((error) => error.code, 'code', 'INTERNAL_ERROR')
              .having(
                (error) => error.message,
                'message',
                isNot(contains('MongoServerError')),
              ),
        ),
      );
    });

    test('reports timeouts without leaking the endpoint', () async {
      final client = _client(
        MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 60));
          return _json(<String, dynamic>{'ok': true});
        }),
        timeout: const Duration(milliseconds: 5),
      );

      await expectLater(
        client.getJson('/api/private'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('took too long'),
          ),
        ),
      );
    });

    test('reports connection failures as retryable messages', () async {
      final client = _client(
        MockClient((_) async => throw http.ClientException('boom')),
      );

      await expectLater(
        client.getJson('/api/tasks'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('Could not reach the server'),
          ),
        ),
      );
    });

    test('rejects a success response that is not JSON', () async {
      final client = _client(
        MockClient((_) async => http.Response('<html>proxy</html>', 200)),
      );

      await expectLater(
        client.getJson('/api/tasks'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('unexpected response'),
          ),
        ),
      );
    });

    test('delete succeeds on an empty 204 response', () async {
      final client = _client(MockClient((_) async => http.Response('', 204)));

      await expectLater(client.deleteJson('/api/tasks/1'), completes);
    });
  });
}
