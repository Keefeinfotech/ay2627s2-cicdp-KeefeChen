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

    test('a success with an empty body decodes to an empty map', () async {
      final client = _client(MockClient((_) async => http.Response('', 200)));

      await expectLater(
        client.postJson('/api/auth/logout', <String, dynamic>{}),
        completion(<String, dynamic>{}),
      );
    });
  });

  group('silent token refresh', () {
    /// A syntactically valid JWT with the given subject, so the client's
    /// same-user matching logic can decode it.
    ///
    /// [jti] makes otherwise identical tokens distinct while keeping the same
    /// `sub` — the claim the upgrade logic matches on.
    String jwt(String sub, {String? jti}) {
      String encode(Map<String, Object> value) {
        return base64Url
            .encode(utf8.encode(jsonEncode(value)))
            .replaceAll('=', '');
      }

      final claims = <String, Object>{'sub': sub};
      if (jti != null) claims['jti'] = jti;
      return '${encode(<String, Object>{'alg': 'none'})}.'
          '${encode(claims)}.sig';
    }

    setUp(() {
      ApiClient.resetTokenCache();
      ApiClient.tokenRefresher = null;
    });

    tearDown(() {
      ApiClient.tokenRefresher = null;
      ApiClient.resetTokenCache();
    });

    test('retries the request once with the renewed token', () async {
      final seen = <String?>[];
      final client = _client(
        MockClient((request) async {
          seen.add(request.headers['Authorization']);
          if (seen.length == 1) {
            return _json(<String, dynamic>{
              'code': 'UNAUTHORIZED',
            }, statusCode: 401);
          }
          return _json(<String, dynamic>{'ok': true});
        }),
      );
      ApiClient.tokenRefresher = () async => 'renewed';

      final result = await client.getJson('/api/tasks', token: 'expired');

      expect(result, <String, dynamic>{'ok': true});
      expect(seen, <String?>['Bearer expired', 'Bearer renewed']);
    });

    test('shares a single refresh across concurrent 401s', () async {
      var refreshCalls = 0;
      final unauthorized = _json(<String, dynamic>{
        'code': 'UNAUTHORIZED',
      }, statusCode: 401);
      final client = _client(
        MockClient((request) async {
          if (request.headers['Authorization'] == 'Bearer renewed') {
            return _json(<String, dynamic>{'ok': true});
          }
          return unauthorized;
        }),
      );
      ApiClient.tokenRefresher = () async {
        refreshCalls += 1;
        // Give both requests time to hit their 401 before renewal finishes.
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 'renewed';
      };

      final results = await Future.wait(<Future<Map<String, dynamic>>>[
        client.getJson('/api/a', token: 'expired'),
        client.getJson('/api/b', token: 'expired'),
      ]);

      expect(results, hasLength(2));
      expect(refreshCalls, 1);
    });

    test('does not refresh requests that carried no token', () async {
      var refreshCalls = 0;
      final client = _client(
        MockClient(
          (_) async => _json(<String, dynamic>{
            'code': 'LOGIN_REQUIRED',
          }, statusCode: 401),
        ),
      );
      ApiClient.tokenRefresher = () async {
        refreshCalls += 1;
        return 'renewed';
      };

      await expectLater(
        client.postJson('/api/auth/login', <String, dynamic>{}),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
      expect(refreshCalls, 0);
    });

    test('surfaces the second 401 instead of looping', () async {
      var refreshCalls = 0;
      final client = _client(
        MockClient(
          (_) async =>
              _json(<String, dynamic>{'code': 'UNAUTHORIZED'}, statusCode: 401),
        ),
      );
      ApiClient.tokenRefresher = () async {
        refreshCalls += 1;
        return 'renewed';
      };

      await expectLater(
        client.getJson('/api/tasks', token: 'expired'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
      // One renewal, one retry — then the failure is surfaced.
      expect(refreshCalls, 1);
    });

    test('surfaces the original 401 when renewal fails', () async {
      final client = _client(
        MockClient(
          (_) async =>
              _json(<String, dynamic>{'code': 'UNAUTHORIZED'}, statusCode: 401),
        ),
      );
      ApiClient.tokenRefresher = () async => null;

      await expectLater(
        client.getJson('/api/tasks', token: 'expired'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.code, 'code', 'UNAUTHORIZED'),
        ),
      );
    });

    test('upgrades a stale token only for the same subject', () async {
      final stale = jwt('user-1', jti: 'stale');
      final latest = jwt('user-1', jti: 'fresh');
      final other = jwt('user-2');
      final seen = <String?>[];
      final client = _client(
        MockClient((request) async {
          seen.add(request.headers['Authorization']);
          if (request.headers['Authorization'] == 'Bearer $stale') {
            return _json(<String, dynamic>{
              'code': 'UNAUTHORIZED',
            }, statusCode: 401);
          }
          return _json(<String, dynamic>{'ok': true});
        }),
      );

      // The first call is rejected; the renewal remembers `latest` for this
      // user and the retry succeeds with it.
      ApiClient.tokenRefresher = () async => latest;
      await client.getJson('/api/seed', token: stale);
      expect(seen, <String?>['Bearer $stale', 'Bearer $latest']);

      // A stale copy of the same user's token is upgraded without a 401...
      seen.clear();
      await client.getJson('/api/tasks', token: stale);
      expect(seen, <String?>['Bearer $latest']);

      // ...but another account's token is never substituted.
      seen.clear();
      await client.getJson('/api/tasks', token: other);
      expect(seen, <String?>['Bearer $other']);
    });

    test('resetTokenCache forgets the renewed token', () async {
      final stale = jwt('user-1', jti: 'stale');
      final latest = jwt('user-1', jti: 'fresh');
      final seen = <String?>[];
      // The first call is rejected so the renewal actually runs and `latest`
      // becomes the remembered token for this user.
      final client = _client(
        MockClient((request) async {
          seen.add(request.headers['Authorization']);
          if (request.headers['Authorization'] == 'Bearer $stale') {
            return _json(<String, dynamic>{
              'code': 'UNAUTHORIZED',
            }, statusCode: 401);
          }
          return _json(<String, dynamic>{'ok': true});
        }),
      );
      ApiClient.tokenRefresher = () async => latest;

      await client.getJson('/api/seed', token: stale);
      expect(seen, <String?>['Bearer $stale', 'Bearer $latest']);

      ApiClient.resetTokenCache();

      // Nothing is remembered: the stale token goes out verbatim instead of
      // being silently upgraded to the renewed one.
      seen.clear();
      final probe = _client(
        MockClient((request) async {
          seen.add(request.headers['Authorization']);
          return _json(<String, dynamic>{'ok': true});
        }),
      );
      await probe.getJson('/api/tasks', token: stale);
      expect(seen, <String?>['Bearer $stale']);
    });

    test('delete retries once after a renewal', () async {
      var refreshCalls = 0;
      var attempts = 0;
      final client = _client(
        MockClient((request) async {
          attempts += 1;
          if (attempts == 1) {
            return _json(<String, dynamic>{
              'code': 'UNAUTHORIZED',
            }, statusCode: 401);
          }
          return http.Response('', 204);
        }),
      );
      ApiClient.tokenRefresher = () async {
        refreshCalls += 1;
        return 'renewed';
      };

      await expectLater(
        client.deleteJson('/api/sessions/1', token: 'expired'),
        completes,
      );
      expect(refreshCalls, 1);
      expect(attempts, 2);
    });
  });
}
