import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/network/api_endpoints.dart';
import 'package:frontend/features/authentication/data/auth_service.dart';
import 'package:frontend/features/authentication/data/session_store.dart';

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

/// In-memory stand-in for the secure store; never touches platform channels.
class _FakeSessionStore extends SessionStore {
  Session? current;

  @override
  Future<Session?> read() async => current;

  @override
  Future<void> write(Session session) async {
    current = session;
  }

  @override
  Future<void> clear() async {
    current = null;
  }
}

void main() {
  late _FakeSessionStore store;

  final loginResponse = <String, dynamic>{
    'token': 'token-1',
    'refreshToken': 'refresh-1',
    'user': <String, dynamic>{'email': 'ada@example.com', 'name': 'Ada'},
  };

  setUp(() {
    store = _FakeSessionStore();
    store.current = const Session(
      token: 'token-1',
      email: 'ada@example.com',
      name: 'Ada',
      refreshToken: 'refresh-1',
    );
    ApiClient.resetTokenCache();
    ApiClient.tokenRefresher = null;
  });

  tearDown(() {
    ApiClient.tokenRefresher = null;
    ApiClient.resetTokenCache();
  });

  AuthService service(MockClient handler) {
    return AuthService(
      api: ApiClient(baseUrl: 'https://auxilia.test', client: handler),
      sessions: store,
    );
  }

  group('refreshSilently', () {
    test(
      'exchanges the stored refresh token and persists the rotated pair',
      () async {
        final requests = <http.Request>[];
        final auth = service(
          MockClient((request) async {
            requests.add(request);
            return _json(<String, dynamic>{
              'token': 'token-2',
              'refreshToken': 'refresh-2',
              'user': <String, dynamic>{
                'email': 'ada@example.com',
                'name': 'Ada',
              },
            });
          }),
        );

        final renewed = await auth.refreshSilently();

        expect(renewed, 'token-2');
        expect(requests, hasLength(1));
        final request = requests.single;
        expect(request.url.path, ApiEndpoints.authRefresh);
        expect(request.method, 'POST');
        // The refresh token travels in the body, never as a bearer header —
        // an unauthenticated refresh call can never trigger another refresh.
        expect(request.headers['Authorization'], isNull);
        expect(jsonDecode(request.body), <String, dynamic>{
          'refreshToken': 'refresh-1',
        });

        expect(store.current?.token, 'token-2');
        expect(store.current?.refreshToken, 'refresh-2');
        expect(store.current?.email, 'ada@example.com');
      },
    );

    test('makes no request when the session has no refresh token', () async {
      store.current = const Session(
        token: 'token-1',
        email: 'ada@example.com',
        refreshToken: null,
      );
      var calls = 0;
      final auth = service(
        MockClient((_) async {
          calls += 1;
          return _json(<String, dynamic>{});
        }),
      );

      expect(await auth.refreshSilently(), isNull);
      expect(calls, 0);
      expect(store.current, isNotNull);
    });

    test(
      'clears the local session when the backend rejects the refresh token',
      () async {
        final auth = service(
          MockClient(
            (_) async => _json(<String, dynamic>{
              'code': 'UNAUTHORIZED',
              'error': 'Invalid refresh token.',
            }, statusCode: 401),
          ),
        );

        expect(await auth.refreshSilently(), isNull);
        expect(store.current, isNull);
      },
    );

    test('keeps the local session on a transient server failure', () async {
      final auth = service(
        MockClient(
          (_) async => _json(<String, dynamic>{
            'code': 'INTERNAL_ERROR',
          }, statusCode: 500),
        ),
      );

      expect(await auth.refreshSilently(), isNull);
      // A 5xx is not a verdict on the refresh token: the next attempt can
      // still succeed, so nothing is discarded.
      expect(store.current?.refreshToken, 'refresh-1');
    });

    test('keeps the local session when the device is offline', () async {
      final auth = service(
        MockClient((_) async => throw http.ClientException('offline')),
      );

      expect(await auth.refreshSilently(), isNull);
      expect(store.current?.refreshToken, 'refresh-1');
    });

    test(
      'renews a rejected API call end to end through refreshSilently',
      () async {
        var refreshCalls = 0;
        final shared = MockClient((request) async {
          if (request.url.path == ApiEndpoints.authRefresh) {
            refreshCalls += 1;
            return _json(<String, dynamic>{
              'token': 'token-2',
              'refreshToken': 'refresh-2',
              'user': <String, dynamic>{'email': 'ada@example.com'},
            });
          }
          if (request.headers['Authorization'] == 'Bearer token-2') {
            return _json(<String, dynamic>{'ok': true});
          }
          return _json(<String, dynamic>{
            'code': 'UNAUTHORIZED',
          }, statusCode: 401);
        });
        final auth = AuthService(
          api: ApiClient(baseUrl: 'https://auxilia.test', client: shared),
          sessions: store,
        );
        ApiClient.tokenRefresher = auth.refreshSilently;
        final api = ApiClient(baseUrl: 'https://auxilia.test', client: shared);

        // The call rides the stale access token; the 401 triggers exactly one
        // silent refresh and a retry with the renewed token.
        final result = await api.getJson('/api/tasks', token: 'token-1');

        expect(result, <String, dynamic>{'ok': true});
        expect(refreshCalls, 1);
        expect(store.current?.token, 'token-2');
        expect(store.current?.refreshToken, 'refresh-2');
      },
    );
  });

  group('logout', () {
    test('revokes the backend session before clearing local state', () async {
      final requests = <http.Request>[];
      final auth = service(
        MockClient((request) async {
          requests.add(request);
          return http.Response('', 204);
        }),
      );

      await auth.logout();

      expect(requests.single.url.path, ApiEndpoints.authLogout);
      expect(requests.single.method, 'POST');
      expect(requests.single.headers['Authorization'], 'Bearer token-1');
      expect(store.current, isNull);
    });

    test(
      'clears local state even when the backend rejects the token',
      () async {
        final auth = service(
          MockClient(
            (_) async => _json(<String, dynamic>{
              'code': 'UNAUTHORIZED',
            }, statusCode: 401),
          ),
        );

        await auth.logout();

        expect(store.current, isNull);
      },
    );

    test('clears local state when the device is offline', () async {
      final auth = service(
        MockClient((_) async => throw http.ClientException('offline')),
      );

      await auth.logout();

      expect(store.current, isNull);
    });

    test('still clears local state when no session is stored', () async {
      store.current = null;
      final auth = service(MockClient((_) async => http.Response('', 204)));

      await auth.logout();

      expect(store.current, isNull);
    });
  });

  group('login persists the refresh token', () {
    test(
      'signup stores the returned refresh token alongside the access token',
      () async {
        final auth = service(MockClient((_) async => _json(loginResponse)));

        final session = await auth.signup(
          email: 'ada@example.com',
          password: 'Auxilia\$ecure2026',
        );

        expect(session.token, 'token-1');
        expect(session.refreshToken, 'refresh-1');
        expect(store.current?.refreshToken, 'refresh-1');
      },
    );
  });
}
