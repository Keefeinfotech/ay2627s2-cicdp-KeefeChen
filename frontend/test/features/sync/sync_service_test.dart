import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/sync/data/sync_queue_store.dart';
import 'package:frontend/features/sync/data/sync_service.dart';
import 'package:frontend/features/sync/models/sync_conflict.dart';
import 'package:frontend/features/sync/models/sync_operation.dart';
import 'package:frontend/features/sync/models/sync_snapshot.dart';

import '../../helpers.dart';

SyncService _service(
  MockClient client, {
  String? token = 'token-1',
  SyncQueueStore? store,
}) {
  return SyncService(
    api: ApiClient(baseUrl: 'https://auxilia.test', client: client),
    ownerId: 'owner',
    tokenProvider: () async => token,
    store: store,
  );
}

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

Map<String, dynamic> _remote(Task task, {DateTime? updatedAt}) {
  return <String, dynamic>{
    '_id': task.id,
    'title': task.title,
    'description': task.notes,
    'course': task.course,
    'tags': task.tags,
    'groupId': task.groupId,
    'assigneeId': task.assigneeId,
    'assigneeName': task.assigneeName,
    'priority': task.priority.name,
    'status': task.isCompleted ? 'completed' : 'todo',
    'dueDate': task.dueDate?.toUtc().toIso8601String(),
    'reminderAt': task.reminderAt?.toUtc().toIso8601String(),
    'createdAt': task.createdAt.toUtc().toIso8601String(),
    'updatedAt': (updatedAt ?? task.updatedAt).toUtc().toIso8601String(),
  };
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('coalesces repeated edits of the same task into one create', () async {
    final service = _service(
      MockClient((_) async => _json(<String, dynamic>{})),
    );
    final task = makeTask(id: 'task-a');

    await service.enqueue(type: SyncOperationType.create, task: task);
    await service.enqueue(
      type: SyncOperationType.update,
      task: task.copyWith(
        title: 'Write the final report',
        tags: const <String>['Maths', 'Urgent'],
        updatedAt: DateTime(2026, 1, 2),
      ),
    );

    expect(service.operations, hasLength(1));
    expect(service.operations.single.type, SyncOperationType.create);
    expect(service.operations.single.task?.title, 'Write the final report');
    expect(service.operations.single.task?.tags, <String>['Maths', 'Urgent']);
  });

  test('persists the queue across service instances', () async {
    final client = MockClient((_) async => _json(<String, dynamic>{}));
    final first = _service(client);
    await first.enqueue(
      type: SyncOperationType.create,
      task: makeTask(id: 'task-a'),
    );

    final second = _service(client);
    await second.load();

    expect(second.operations, hasLength(1));
    expect(second.operations.single.taskId, 'task-a');
    expect(second.snapshot.value.phase, SyncPhase.pending);
  });

  test('flush replays a create and marks the queue synced', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return _json(<String, dynamic>{
        'data': <String, dynamic>{},
      }, statusCode: 201);
    });
    final service = _service(client);
    await service.enqueue(
      type: SyncOperationType.create,
      task: makeTask(id: 'task-a'),
    );

    await service.flush();

    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/tasks');
    expect(requests.single.headers['Authorization'], 'Bearer token-1');
    expect(service.operations, isEmpty);
    expect(service.snapshot.value.phase, SyncPhase.synced);
    expect(service.snapshot.value.lastSyncedAt, isNotNull);
  });

  test('a create collision becomes a user-facing conflict', () async {
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        return _json(<String, dynamic>{
          'code': 'TASK_ALREADY_EXISTS',
          'message': 'Task already exists.',
        }, statusCode: 409);
      }
      return _json(<String, dynamic>{
        'data': _remote(makeTask(id: 'task-a', title: 'Server copy')),
      });
    });
    final service = _service(client);
    await service.enqueue(
      type: SyncOperationType.create,
      task: makeTask(id: 'task-a', title: 'Local copy'),
    );

    await service.flush();

    expect(service.operations, isEmpty);
    expect(service.conflicts, hasLength(1));
    final conflict = service.conflicts.single;
    expect(conflict.kind, SyncConflictKind.createCollision);
    expect(conflict.localTask.title, 'Local copy');
    expect(conflict.remoteTask?.title, 'Server copy');
    expect(service.snapshot.value.phase, SyncPhase.conflict);
  });

  test(
    'an update is queued when the remote task changed concurrently',
    () async {
      final requests = <http.Request>[];
      final base = DateTime(2026, 1, 1, 9);
      final local = makeTask(
        id: 'task-a',
        title: 'Local title',
        updatedAt: DateTime(2026, 1, 2),
      );
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return _json(<String, dynamic>{
            'data': _remote(
              makeTask(id: 'task-a', title: 'Remote title'),
              updatedAt: DateTime(2026, 1, 3),
            ),
          });
        }
        return _json(<String, dynamic>{'data': <String, dynamic>{}});
      });
      final service = _service(client);
      await service.enqueue(
        type: SyncOperationType.update,
        task: local,
        baseUpdatedAt: base,
      );

      await service.flush();

      expect(requests.where((request) => request.method == 'PATCH'), isEmpty);
      expect(service.conflicts, hasLength(1));
      expect(service.conflicts.single.kind, SyncConflictKind.updateCollision);
      expect(service.conflicts.single.remoteTask?.title, 'Remote title');
      expect(service.snapshot.value.phase, SyncPhase.conflict);
    },
  );

  test(
    'an update wins when remote content matches the local snapshot',
    () async {
      final requests = <http.Request>[];
      final local = makeTask(id: 'task-a', title: 'Same title');
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return _json(<String, dynamic>{
            'data': _remote(
              makeTask(id: 'task-a', title: 'Same title'),
              updatedAt: DateTime(2026, 1, 3),
            ),
          });
        }
        return _json(<String, dynamic>{'data': <String, dynamic>{}});
      });
      final service = _service(client);
      await service.enqueue(
        type: SyncOperationType.update,
        task: local,
        baseUpdatedAt: DateTime(2026, 1, 1),
      );

      await service.flush();

      expect(
        requests.where((request) => request.method == 'PATCH'),
        hasLength(1),
      );
      expect(service.conflicts, isEmpty);
      expect(service.operations, isEmpty);
      expect(service.snapshot.value.phase, SyncPhase.synced);
    },
  );

  test(
    'a network failure keeps the change queued and reports offline',
    () async {
      final client = MockClient((_) async {
        throw http.ClientException('offline');
      });
      final service = _service(client);
      await service.enqueue(
        type: SyncOperationType.create,
        task: makeTask(id: 'task-a'),
      );

      await service.flush();

      expect(service.operations, hasLength(1));
      expect(service.operations.single.attempts, 1);
      expect(service.operations.single.lastError, isNotNull);
      expect(service.snapshot.value.phase, SyncPhase.offline);
      expect(service.snapshot.value.pendingCount, 1);
    },
  );

  test('a missing token keeps everything local-only', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return _json(<String, dynamic>{});
    });
    final service = _service(client, token: null);
    await service.enqueue(
      type: SyncOperationType.create,
      task: makeTask(id: 'task-a'),
    );

    await service.flush();

    expect(calls, 0);
    expect(service.operations, hasLength(1));
    expect(service.snapshot.value.phase, SyncPhase.localOnly);
  });

  test('a delete that is already gone counts as applied', () async {
    final client = MockClient((_) async {
      return _json(<String, dynamic>{
        'message': 'Task was not found.',
      }, statusCode: 404);
    });
    final service = _service(client);
    await service.enqueue(
      type: SyncOperationType.delete,
      task: makeTask(id: 'task-a'),
    );

    await service.flush();

    expect(service.operations, isEmpty);
    expect(service.snapshot.value.phase, SyncPhase.synced);
  });

  test('keep remote clears the conflict without another request', () async {
    var writes = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        return _json(<String, dynamic>{
          'code': 'TASK_ALREADY_EXISTS',
          'message': 'Task already exists.',
        }, statusCode: 409);
      }
      if (request.method == 'GET') {
        return _json(<String, dynamic>{
          'data': _remote(makeTask(id: 'task-a', title: 'Server copy')),
        });
      }
      writes++;
      return _json(<String, dynamic>{});
    });
    final service = _service(client);
    await service.enqueue(
      type: SyncOperationType.create,
      task: makeTask(id: 'task-a', title: 'Local copy'),
    );
    await service.flush();
    final conflict = service.conflicts.single;

    final result = await service.resolveConflict(
      conflict,
      ConflictResolution.keepRemote,
    );

    expect(result.success, isTrue);
    expect(result.remoteTask?.title, 'Server copy');
    expect(writes, 0);
    expect(service.conflicts, isEmpty);
  });

  test(
    'keep local overwrites the server copy and clears the conflict',
    () async {
      final patches = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          return _json(<String, dynamic>{
            'code': 'TASK_ALREADY_EXISTS',
            'message': 'Task already exists.',
          }, statusCode: 409);
        }
        if (request.method == 'GET') {
          return _json(<String, dynamic>{
            'data': _remote(makeTask(id: 'task-a', title: 'Server copy')),
          });
        }
        if (request.method == 'PATCH') {
          patches.add(jsonDecode(request.body) as Map<String, dynamic>);
          return _json(<String, dynamic>{'data': <String, dynamic>{}});
        }
        return _json(<String, dynamic>{});
      });
      final service = _service(client);
      await service.enqueue(
        type: SyncOperationType.create,
        task: makeTask(id: 'task-a', title: 'Local copy'),
      );
      await service.flush();

      final result = await service.resolveConflict(
        service.conflicts.single,
        ConflictResolution.keepLocal,
      );

      expect(result.success, isTrue);
      expect(patches, hasLength(1));
      expect(patches.single['title'], 'Local copy');
      expect(service.conflicts, isEmpty);
    },
  );

  test('an update to a task deleted elsewhere surfaces a conflict', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return _json(<String, dynamic>{
          'message': 'Task was not found.',
        }, statusCode: 404);
      }
      return _json(<String, dynamic>{'data': <String, dynamic>{}});
    });
    final service = _service(client);
    await service.enqueue(
      type: SyncOperationType.update,
      task: makeTask(id: 'task-a', title: 'Edited offline'),
      baseUpdatedAt: DateTime(2026, 1, 1),
    );

    await service.flush();

    expect(requests.where((request) => request.method == 'PATCH'), isEmpty);
    expect(requests.where((request) => request.method == 'POST'), isEmpty);
    expect(service.conflicts, hasLength(1));
    final conflict = service.conflicts.single;
    expect(conflict.kind, SyncConflictKind.deleteCollision);
    expect(conflict.localTask.title, 'Edited offline');
    expect(conflict.remoteTask, isNull);
    expect(service.snapshot.value.phase, SyncPhase.conflict);
  });

  test('keeping local in a delete conflict recreates the task', () async {
    final bodies = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return _json(<String, dynamic>{
          'message': 'Task was not found.',
        }, statusCode: 404);
      }
      if (request.method == 'POST') {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return _json(<String, dynamic>{
          'data': <String, dynamic>{},
        }, statusCode: 201);
      }
      return _json(<String, dynamic>{});
    });
    final service = _service(client);
    await service.enqueue(
      type: SyncOperationType.update,
      task: makeTask(id: 'task-a', title: 'Edited offline'),
      baseUpdatedAt: DateTime(2026, 1, 1),
    );
    await service.flush();

    final result = await service.resolveConflict(
      service.conflicts.single,
      ConflictResolution.keepLocal,
    );

    expect(result.success, isTrue);
    expect(bodies, hasLength(1));
    expect(bodies.single['title'], 'Edited offline');
    expect(service.conflicts, isEmpty);
  });

  test(
    'a permanently rejected change dead-letters after retries and can be discarded',
    () async {
      var attempts = 0;
      final client = MockClient((request) async {
        attempts += 1;
        return _json(<String, dynamic>{
          'message': 'Invalid task.',
        }, statusCode: 400);
      });
      final service = _service(client);
      await service.enqueue(
        type: SyncOperationType.create,
        task: makeTask(id: 'task-a', title: 'Rejected offline'),
      );

      await service.retry();
      await service.retry();
      await service.retry();

      expect(attempts, 3);
      expect(service.operations.single.attempts, 3);
      expect(service.operations.single.isDeadLetter, isTrue);

      // Automatic flushes skip dead-lettered work until the user intervenes.
      await service.flush();
      expect(attempts, 3);

      await service.discard(service.operations.single.id);
      expect(service.operations, isEmpty);
      expect(attempts, 3);
    },
  );

  test('keeping remote in a delete conflict drops the local copy', () async {
    var writes = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return _json(<String, dynamic>{
          'message': 'Task was not found.',
        }, statusCode: 404);
      }
      writes += 1;
      return _json(<String, dynamic>{});
    });
    final service = _service(client);
    await service.enqueue(
      type: SyncOperationType.update,
      task: makeTask(id: 'task-a', title: 'Edited offline'),
      baseUpdatedAt: DateTime(2026, 1, 1),
    );
    await service.flush();

    final result = await service.resolveConflict(
      service.conflicts.single,
      ConflictResolution.keepRemote,
    );

    expect(result.success, isTrue);
    expect(result.deleteLocal, isTrue);
    expect(writes, 0);
    expect(service.conflicts, isEmpty);
  });
}
