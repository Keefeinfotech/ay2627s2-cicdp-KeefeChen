import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/groups/data/groups_repository.dart';

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

GroupsRepository _repository(MockClient client, {String token = 'token-1'}) {
  return GroupsRepository(
    token: token,
    api: ApiClient(baseUrl: 'https://auxilia.test', client: client),
  );
}

void main() {
  test('lists groups with the caller role', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/groups');
      expect(request.headers['Authorization'], 'Bearer token-1');
      return _json(<String, dynamic>{
        'data': <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'groupId': 'group-1',
              'name': 'COMP 2101',
              'description': 'Algorithms team',
              'visibility': 'PRIVATE',
              'ownerId': 'user-1',
              'role': 'OWNER',
              'createdAt': '2026-01-01T09:00:00.000Z',
              'updatedAt': '2026-01-01T09:00:00.000Z',
            },
          ],
          'pagination': <String, dynamic>{'page': 1, 'totalItems': 1},
        },
      });
    });

    final groups = await _repository(client).list();

    expect(groups, hasLength(1));
    expect(groups.single.id, 'group-1');
    expect(groups.single.name, 'COMP 2101');
    expect(groups.single.isOwner, isTrue);
    expect(groups.single.canManage, isTrue);
    expect(groups.single.isPublic, isFalse);
  });

  test('creates a group with the requested visibility', () async {
    Map<String, dynamic>? body;
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return _json(<String, dynamic>{
        'data': <String, dynamic>{
          'groupId': 'group-2',
          'name': 'Study crew',
          'visibility': 'PUBLIC',
          'ownerId': 'user-1',
          'createdAt': '2026-01-01T09:00:00.000Z',
          'updatedAt': '2026-01-01T09:00:00.000Z',
        },
      }, statusCode: 201);
    });

    final group = await _repository(
      client,
    ).create(name: ' Study crew ', isPublic: true);

    expect(body?['name'], 'Study crew');
    expect(body?['visibility'], 'PUBLIC');
    expect(group.id, 'group-2');
    expect(group.isPublic, isTrue);
  });

  test('rejects an incomplete group response', () async {
    final client = MockClient((_) async {
      return _json(<String, dynamic>{'data': <String, dynamic>{}});
    });

    expect(
      () => _repository(client).create(name: 'Team'),
      throwsA(isA<ApiException>()),
    );
  });

  test('parses the member roster', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/groups/group-1/members');
      return _json(<String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'userId': 'user-1',
            'role': 'OWNER',
            'status': 'ACTIVE',
            'name': 'Sam Lee',
            'email': 'sam@example.com',
            'joinedAt': '2026-01-01T09:00:00.000Z',
          },
        ],
        'pagination': <String, dynamic>{'page': 1, 'totalItems': 1},
      });
    });

    final members = await _repository(client).members('group-1');

    expect(members, hasLength(1));
    expect(members.single.displayName, 'Sam Lee');
    expect(members.single.initials, 'SL');
    expect(members.single.role, 'OWNER');
  });

  test('creates an invitation and exposes the one-time token', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/invitations');
      return _json(<String, dynamic>{
        'data': <String, dynamic>{
          'invitation': <String, dynamic>{
            'invitationId': 'invite-1',
            'groupId': 'group-1',
            'email': 'teammate@example.com',
            'role': 'MEMBER',
            'expiresAt': '2026-02-01T09:00:00.000Z',
          },
          'invitationToken': 'raw-token-value',
        },
      }, statusCode: 201);
    });

    final invitation = await _repository(
      client,
    ).invite(groupId: 'group-1', email: 'Teammate@Example.com');

    expect(invitation.invitationId, 'invite-1');
    expect(invitation.email, 'teammate@example.com');
    expect(invitation.token, 'raw-token-value');
  });

  test('accepts an invitation token', () async {
    Map<String, dynamic>? body;
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/invitations/accept');
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return _json(<String, dynamic>{'message': 'Accepted'});
    });

    await _repository(client).accept('  token-value  ');

    expect(body?['token'], 'token-value');
  });

  test('surfaces API error messages', () async {
    final client = MockClient((_) async {
      return _json(<String, dynamic>{
        'code': 'GROUP_ACCESS_DENIED',
        'message': 'You do not have permission to view this group.',
      }, statusCode: 403);
    });

    await expectLater(
      _repository(client).members('group-1'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 403)
            .having(
              (error) => error.message,
              'message',
              'You do not have permission to view this group.',
            ),
      ),
    );
  });
}
