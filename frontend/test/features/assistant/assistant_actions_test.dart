import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/assistant/presentation/pages/assistant_page.dart';
import 'package:frontend/features/authentication/models/session.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';


const Session _session = Session(token: 'token-123', email: 'a@b.c');

Future<(TaskStore, List<http.Request>)> _pumpAuthed(
  WidgetTester tester, {
  required Future<http.Response> Function(http.Request) handler,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final requests = <http.Request>[];
  final client = MockClient((request) async {
    requests.add(request);
    return handler(request);
  });
  final api = ApiClient(baseUrl: 'https://auxilia.test', client: client);
  final repository = InMemoryTaskRepository();
  final store = TaskStore(repository: repository, ownerId: 'a@b.c');
  await store.load();

  await tester.pumpWidget(
    MaterialApp(
      theme: AuxiliaTheme.light(),
      home: AssistantPage(ownerId: 'a@b.c', session: _session, store: store, api: api),
    ),
  );
  await tester.pumpAndSettle();
  return (store, requests);
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: <String, String>{'content-type': 'application/json'});

Future<void> _send(WidgetTester tester, String message) async {
  await tester.enterText(find.byType(TextField), message);
  await tester.tap(find.byTooltip('Send message'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('authenticated NL create executes on backend and shows applied action', (tester) async {
    final (store, requests) = await _pumpAuthed(
      tester,
      handler: (request) async => _json(<String, dynamic>{
        'reply': 'Created task "Finish my CI/CD report" (due 2026-11-28, high priority).',
        'kind': 'action',
        'intent': 'create_task',
        'status': 'executed',
        'executed': true,
        'changed': true,
        'task': <String, dynamic>{
          'id': 'task-9',
          'title': 'Finish my CI/CD report',
          'status': 'todo',
          'priority': 'high',
          'dueDate': '2026-11-28T00:00:00.000Z',
          'reminderAt': null,
          'course': '',
          'description': null,
          'tags': <String>[],
        },
        'tasks': <dynamic>[],
        'refresh': <String, bool>{'tasks': true, 'reminders': false},
      }),
    );

    await _send(tester, 'Create a task to finish my CI/CD report by tomorrow, high priority.');

    // Hit the genuine backend pipeline with auth + idempotency key.
    final act = requests.firstWhere((r) => r.url.path == '/api/assistant/act');
    expect(act.headers['Authorization'], 'Bearer token-123');
    final payload = jsonDecode(act.body) as Map<String, dynamic>;
    expect(payload['message'], 'Create a task to finish my CI/CD report by tomorrow, high priority.');
    expect(payload['clientRequestId'], isNotEmpty);

    // Truthful confirmation + distinct executed-action card with real details.
    expect(find.textContaining('Created task'), findsWidgets);
    expect(find.text('Task created'), findsOneWidget);
    expect(find.text('Finish my CI/CD report'), findsWidgets);
    expect(find.text('Applied'), findsWidgets);
    expect(store, isNotNull);
  });

  testWidgets('ordinary conversation is not shown as an executed action', (tester) async {
    await _pumpAuthed(
      tester,
      handler: (request) async => _json(<String, dynamic>{
        'reply': 'Break your report into an outline first.',
        'kind': 'conversation',
        'intent': 'conversation',
        'status': 'conversation',
        'executed': false,
        'changed': false,
        'task': null,
        'tasks': <dynamic>[],
        'refresh': <String, bool>{'tasks': false, 'reminders': false},
      }),
    );

    await _send(tester, 'Any tips for writing my report?');

    expect(find.textContaining('Break your report into an outline first.'), findsOneWidget);
    expect(find.text('Task created'), findsNothing);
    expect(find.text('Applied'), findsNothing);
  });

  testWidgets('delete requires confirmation then confirms on backend', (tester) async {
    final (_, requests) = await _pumpAuthed(
      tester,
      handler: (request) async {
        if (request.url.path == '/api/assistant/confirm-action') {
          return _json(<String, dynamic>{
            'reply': 'Deleted task "Presentation".',
            'kind': 'action',
            'intent': 'delete_task',
            'status': 'executed',
            'executed': true,
            'changed': true,
            'task': <String, dynamic>{'id': 'p1', 'title': 'Presentation', 'status': 'archived', 'priority': 'medium'},
            'tasks': <dynamic>[],
            'refresh': <String, bool>{'tasks': true, 'reminders': false},
          });
        }
        return _json(<String, dynamic>{
          'reply': 'I found "Presentation". Confirm to delete it, or cancel. Nothing has been changed yet.',
          'kind': 'action',
          'intent': 'delete_task',
          'status': 'confirmation_required',
          'executed': false,
          'changed': false,
          'task': <String, dynamic>{'id': 'p1', 'title': 'Presentation', 'status': 'todo', 'priority': 'medium'},
          'tasks': <dynamic>[],
          'confirmation': <String, dynamic>{
            'pendingActionId': 'pending-1',
            'type': 'delete_task',
            'summary': 'Delete task "Presentation"',
            'task': <String, dynamic>{'id': 'p1', 'title': 'Presentation', 'status': 'todo', 'priority': 'medium'},
            'expiresAt': '2026-11-27T12:10:00.000Z',
          },
          'refresh': <String, bool>{'tasks': false, 'reminders': false},
        });
      },
    );

    await _send(tester, 'Delete my presentation task.');

    // Confirmation gate: nothing executed yet.
    expect(find.text('Confirmation required'), findsOneWidget);
    expect(find.textContaining('Nothing has been changed yet'), findsWidgets);
    expect(find.text('Delete task "Presentation"'), findsOneWidget);
    expect(requests.any((r) => r.url.path == '/api/assistant/confirm-action'), isFalse);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    final confirm = requests.firstWhere((r) => r.url.path == '/api/assistant/confirm-action');
    expect(jsonDecode(confirm.body)['pendingActionId'], 'pending-1');
    expect(find.text('Task deleted'), findsOneWidget);
  });

  testWidgets('cancel a pending confirmation changes nothing', (tester) async {
    final (_, requests) = await _pumpAuthed(
      tester,
      handler: (request) async {
        if (request.url.path == '/api/assistant/cancel-action') {
          return _json(<String, dynamic>{'reply': 'Cancelled. Nothing was changed.', 'kind': 'action', 'intent': 'delete_task', 'status': 'executed', 'executed': false, 'changed': false, 'tasks': <dynamic>[], 'refresh': <String, bool>{'tasks': false, 'reminders': false}});
        }
        return _json(<String, dynamic>{
          'reply': 'Confirm to delete "Presentation".',
          'kind': 'action',
          'intent': 'delete_task',
          'status': 'confirmation_required',
          'executed': false,
          'changed': false,
          'tasks': <dynamic>[],
          'confirmation': <String, dynamic>{'pendingActionId': 'pending-1', 'type': 'delete_task', 'summary': 'Delete task "Presentation"'},
          'refresh': <String, bool>{'tasks': false, 'reminders': false},
        });
      },
    );

    await _send(tester, 'Delete my presentation task.');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(requests.any((r) => r.url.path == '/api/assistant/cancel-action'), isTrue);
    expect(requests.any((r) => r.url.path == '/api/assistant/confirm-action'), isFalse);
    expect(find.text('Cancelled. Nothing was changed.'), findsWidgets);
  });

  testWidgets('failed action is reported as an error, not success', (tester) async {
    await _pumpAuthed(
      tester,
      handler: (request) async => _json(<String, dynamic>{
        'reply': 'I could not complete that action. Nothing has been confirmed as changed.',
        'kind': 'action',
        'intent': 'update_task',
        'status': 'failed',
        'executed': false,
        'changed': false,
        'tasks': <dynamic>[],
        'refresh': <String, bool>{'tasks': false, 'reminders': false},
      }),
    );

    await _send(tester, 'Change my report deadline to Friday');

    expect(find.textContaining('could not complete'), findsOneWidget);
    expect(find.text('Applied'), findsNothing);
  });

  testWidgets('server error does not claim anything changed', (tester) async {
    await _pumpAuthed(tester, handler: (request) async => _json(<String, String>{'error': 'boom'}, 500));

    await _send(tester, 'Create a task to buy milk');

    expect(find.textContaining('Nothing was changed'), findsOneWidget);
    expect(find.text('Task created'), findsNothing);
  });
}
