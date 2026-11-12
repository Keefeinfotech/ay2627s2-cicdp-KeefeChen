import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/admin/data/admin_repository.dart';

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

const Map<String, dynamic> _statsPayload = <String, dynamic>{
  'users': <String, dynamic>{
    'total': 42,
    'active': 30,
    'disabled': 10,
    'pending': 2,
    'newLast7Days': 5,
  },
  'tasks': <String, dynamic>{
    'total': 130,
    'todo': 40,
    'inProgress': 20,
    'completed': 60,
    'archived': 10,
    'completionRate': 0.5,
    'createdLast7Days': 12,
    'completedLast7Days': 9,
  },
  'taskCreationTrend': <Map<String, dynamic>>[
    <String, dynamic>{'date': '2026-11-01', 'count': 3},
  ],
  'taskCompletionTrend': <Map<String, dynamic>>[
    <String, dynamic>{'date': '2026-11-01', 'count': 2},
  ],
};

AdminRepository _repo(MockClient client) => AdminRepository(
  token: 'demo-token',
  api: ApiClient(baseUrl: 'https://auxilia.test', client: client),
);

void main() {
  group('AdminRepository', () {
    test('fetches and parses platform statistics', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/admin/stats');
        expect(request.headers['authorization'], 'Bearer demo-token');
        return _json(<String, dynamic>{'message': 'ok', 'data': _statsPayload});
      });

      final stats = await _repo(client).fetchStats();

      expect(stats.users.total, 42);
      expect(stats.users.active, 30);
      expect(stats.tasks.total, 130);
      expect(stats.tasks.completionRate, 0.5);
      expect(stats.taskCreationTrend.single.count, 3);
      expect(stats.taskCompletionTrend.single.date, '2026-11-01');
    });

    test('sends search, status, page and limit as query parameters', () async {
      final client = MockClient((request) async {
        final query = request.url.queryParameters;
        expect(request.url.path, '/api/admin/users');
        expect(query['search'], 'keefe');
        expect(query['status'], 'active');
        expect(query['page'], '2');
        expect(query['limit'], '10');
        return _json(<String, dynamic>{
          'message': 'ok',
          'data': <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'user-1',
                'name': 'Keefe',
                'email': 'keefe@auxilia.demo',
                'role': 'admin',
                'status': 'active',
                'createdAt': '2026-10-01T00:00:00.000Z',
                'lastLoginAt': '2026-11-10T08:00:00.000Z',
              },
            ],
            'total': 37,
            'page': 2,
            'limit': 10,
            'totalPages': 4,
          },
        });
      });

      final page = await _repo(client)
          .fetchUsers(search: 'keefe', status: 'active', page: 2, limit: 10);

      expect(page.total, 37);
      expect(page.totalPages, 4);
      expect(page.items.single.email, 'keefe@auxilia.demo');
      expect(page.items.single.isAdmin, isTrue);
    });

    test('wraps a 401 response in AdminException', () async {
      final client = MockClient(
        (_) async => _json(<String, dynamic>{
          'error': 'Authentication required',
        }, statusCode: 401),
      );

      await expectLater(
        () => _repo(client).fetchStats(),
        throwsA(
          isA<AdminException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('wraps a 403 response in AdminException', () async {
      final client = MockClient(
        (_) async => _json(<String, dynamic>{
          'error': 'Insufficient permissions',
        }, statusCode: 403),
      );

      await expectLater(
        () => _repo(client).fetchStats(),
        throwsA(
          isA<AdminException>().having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });

    test('updates a user status through PATCH', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/admin/users/user-1/status');
        return _json(<String, dynamic>{
          'message': 'ok',
          'data': <String, dynamic>{
            'id': 'user-1',
            'name': 'Wei',
            'email': 'wei@auxilia.demo',
            'role': 'user',
            'status': 'disabled',
            'createdAt': '2026-10-01T00:00:00.000Z',
            'lastLoginAt': null,
          },
        });
      });

      final updated = await _repo(client)
          .updateUserStatus('user-1', 'disabled');

      expect(updated.status, 'disabled');
      expect(updated.id, 'user-1');
    });
  });
}
