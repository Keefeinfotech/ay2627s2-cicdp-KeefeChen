import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/calendar/data/datasources/calendar_api_data_source.dart';
import 'package:frontend/features/calendar/data/models/calendar_event.dart';
import 'package:frontend/features/calendar/data/repositories/calendar_repository.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';
import 'package:frontend/features/home/models/task.dart';

import '../../helpers.dart';

class _FakeCalendarApi extends CalendarApiDataSource {
  _FakeCalendarApi({
    this.events = const <CalendarEvent>[],
    this.conflicts = const <CalendarEvent>[],
    this.error,
  });

  List<CalendarEvent> events;
  List<CalendarEvent> conflicts;
  Object? error;

  int fetchCount = 0;
  String? lastGroupId;
  String? lastExcludeId;

  @override
  Future<List<CalendarEvent>> fetchEvents({
    required String token,
    required DateTime startDate,
    required DateTime endDate,
    String? groupId,
  }) async {
    fetchCount += 1;
    lastGroupId = groupId;
    if (error != null) throw error!;
    return List<CalendarEvent>.of(events);
  }

  @override
  Future<CalendarEvent> createEvent({
    required String token,
    required CalendarEvent event,
  }) async {
    if (error != null) throw error!;
    return event.copyWith(id: 'remote-1');
  }

  @override
  Future<List<CalendarEvent>> checkConflicts({
    required String token,
    required DateTime startTime,
    required DateTime endTime,
    String? excludeId,
  }) async {
    lastExcludeId = excludeId;
    if (error != null) throw error!;
    return List<CalendarEvent>.of(conflicts);
  }
}

CalendarEvent _event({
  String id = 'event-1',
  String title = 'Revision block',
  DateTime? start,
  DateTime? end,
  String? groupId,
  CalendarEventStatus status = CalendarEventStatus.scheduled,
}) {
  final startTime = start ?? DateTime(2026, 3, 4, 10);
  return CalendarEvent(
    id: id,
    title: title,
    startTime: startTime,
    endTime: end ?? startTime.add(const Duration(minutes: 45)),
    groupId: groupId,
    status: status,
  );
}

Future<TaskStore> _store(List<Task> tasks) async {
  final store = TaskStore(
    repository: InMemoryTaskRepository(
      seed: <String, List<Task>>{'owner': tasks},
    ),
    ownerId: 'owner',
  );
  await store.load();
  return store;
}

void main() {
  final start = DateTime(2026, 3, 4);
  final end = DateTime(2026, 3, 5);

  test('shows task-derived events when signed out', () async {
    final store = await _store(<Task>[
      makeTask(
        id: '1',
        title: 'Submit lab',
        course: 'COMP 2101',
        dueDate: DateTime(2026, 3, 4, 14),
      ),
      makeTask(
        id: '2',
        title: 'Done elsewhere',
        dueDate: DateTime(2026, 4, 1, 10),
      ),
      makeTask(id: '3', title: 'No due date'),
    ]);
    final api = _FakeCalendarApi();
    final repository = CalendarRepository(store: store, api: api);

    final result = await repository.loadEvents(startDate: start, endDate: end);

    expect(api.fetchCount, 0);
    expect(result.isRemote, isFalse);
    expect(result.warning, isNull);
    expect(result.events, hasLength(1));
    expect(result.events.single.title, 'Submit lab');
    expect(result.events.single.taskId, '1');
    expect(result.events.single.location, 'COMP 2101');
  });

  test('marks completed task events and supports group filtering', () async {
    final store = await _store(<Task>[
      makeTask(
        id: '1',
        title: 'Maths',
        course: 'Maths',
        dueDate: DateTime(2026, 3, 4, 12),
        status: TaskStatus.completed,
        completedAt: DateTime(2026, 3, 4, 13),
      ),
      makeTask(
        id: '2',
        title: 'Chemistry',
        course: 'Chemistry',
        dueDate: DateTime(2026, 3, 4, 15),
      ),
    ]);
    final repository = CalendarRepository(
      store: store,
      api: _FakeCalendarApi(),
    );

    final mathsOnly = await repository.loadEvents(
      startDate: start,
      endDate: end,
      groupId: 'Maths',
    );
    expect(mathsOnly.events, hasLength(1));
    expect(mathsOnly.events.single.status, CalendarEventStatus.completed);

    final all = await repository.loadEvents(startDate: start, endDate: end);
    expect(all.events, hasLength(2));
  });

  test('merges remote events with local ones when signed in', () async {
    final store = await _store(<Task>[
      makeTask(
        id: '1',
        title: 'Local task',
        course: '507f1f77bcf86cd799439011',
        dueDate: DateTime(2026, 3, 4, 16),
      ),
    ]);
    final api = _FakeCalendarApi(
      events: <CalendarEvent>[_event(id: 'remote-0', title: 'Remote seminar')],
    );
    final repository = CalendarRepository(store: store, api: api);

    final result = await repository.loadEvents(
      startDate: start,
      endDate: end,
      token: 'token-1',
      groupId: '507f1f77bcf86cd799439011',
    );

    expect(api.fetchCount, 1);
    expect(api.lastGroupId, '507f1f77bcf86cd799439011');
    expect(result.isRemote, isTrue);
    expect(
      result.events.map((event) => event.title),
      containsAll(<String>['Remote seminar', 'Local task']),
    );
  });

  test('does not forward non-Mongo group ids to the API', () async {
    final store = await _store(const <Task>[]);
    final api = _FakeCalendarApi();
    final repository = CalendarRepository(store: store, api: api);

    await repository.loadEvents(
      startDate: start,
      endDate: end,
      token: 'token-1',
      groupId: 'COMP 2101',
    );

    expect(api.lastGroupId, isNull);
  });

  test('falls back to local events and reports a warning on failure', () async {
    final store = await _store(<Task>[
      makeTask(
        id: '1',
        title: 'Local task',
        course: '507f1f77bcf86cd799439011',
        dueDate: DateTime(2026, 3, 4, 16),
      ),
    ]);

    final unauthorized = _FakeCalendarApi(
      error: ApiException('Session expired.', statusCode: 401),
    );
    final expiredResult = await CalendarRepository(
      store: store,
      api: unauthorized,
    ).loadEvents(startDate: start, endDate: end, token: 'token-1');
    expect(expiredResult.warning, contains('session expired'));
    expect(expiredResult.events, hasLength(1));

    final serverError = _FakeCalendarApi(
      error: ApiException(
        'The server could not complete the request.',
        statusCode: 500,
      ),
    );
    final failedResult = await CalendarRepository(
      store: store,
      api: serverError,
    ).loadEvents(startDate: start, endDate: end, token: 'token-1');
    expect(
      failedResult.warning,
      contains('Showing tasks saved on this device.'),
    );

    final unknown = _FakeCalendarApi(error: StateError('boom'));
    final unknownResult = await CalendarRepository(
      store: store,
      api: unknown,
    ).loadEvents(startDate: start, endDate: end, token: 'token-1');
    expect(
      unknownResult.warning,
      'The calendar could not be refreshed. Showing local tasks.',
    );
  });

  test('creates events remotely when signed in', () async {
    final store = await _store(const <Task>[]);
    final api = _FakeCalendarApi();
    final repository = CalendarRepository(store: store, api: api);

    final result = await repository.createEvent(
      event: _event(),
      token: 'token-1',
    );

    expect(result.synced, isTrue);
    expect(result.event.id, 'remote-1');
    expect(result.warning, isNull);

    final loaded = await repository.loadEvents(startDate: start, endDate: end);
    expect(loaded.events.single.id, 'remote-1');
  });

  test('falls back to a local event when the API rejects the write', () async {
    final store = await _store(const <Task>[]);
    final api = _FakeCalendarApi(
      error: ApiException(
        'The server could not complete the request.',
        statusCode: 500,
      ),
    );
    final repository = CalendarRepository(store: store, api: api);

    final result = await repository.createEvent(
      event: _event(),
      token: 'token-1',
    );

    expect(result.synced, isFalse);
    expect(result.event.id, startsWith('local-'));
    expect(result.warning, isNotNull);
  });

  test('creates locally when signed out', () async {
    final store = await _store(const <Task>[]);
    final repository = CalendarRepository(
      store: store,
      api: _FakeCalendarApi(),
    );

    final result = await repository.createEvent(event: _event());

    expect(result.synced, isFalse);
    expect(result.event.id, startsWith('local-'));
  });

  test('checks conflicts only when signed in', () async {
    final store = await _store(const <Task>[]);
    final api = _FakeCalendarApi(conflicts: <CalendarEvent>[_event()]);
    final repository = CalendarRepository(store: store, api: api);

    expect(
      await repository.checkConflicts(startTime: start, endTime: end),
      isEmpty,
    );

    final conflicts = await repository.checkConflicts(
      startTime: start,
      endTime: end,
      token: 'token-1',
      excludeId: 'event-0',
    );
    expect(conflicts, hasLength(1));
    expect(api.lastExcludeId, 'event-0');

    final failing = _FakeCalendarApi(error: StateError('boom'));
    final hidden = await CalendarRepository(
      store: store,
      api: failing,
    ).checkConflicts(startTime: start, endTime: end, token: 'token-1');
    expect(hidden, isEmpty);
  });

  test('applies local moves and reports project names', () async {
    final store = await _store(<Task>[
      makeTask(id: '1', course: 'Comp 2101', dueDate: DateTime(2026, 3, 4, 16)),
    ]);
    final repository = CalendarRepository(
      store: store,
      api: _FakeCalendarApi(),
    );

    expect(repository.projects, <String>['Comp 2101']);

    final event = _event(id: 'local-1', title: 'Reschedule me');
    final moved = repository.applyLocalMove(event, DateTime(2026, 3, 6, 9));

    expect(moved.event.id, 'moved-local-1');
    expect(moved.event.startTime, DateTime(2026, 3, 6, 9));
    expect(moved.event.endTime, DateTime(2026, 3, 6, 9, 45));
    expect(moved.warning, isNotNull);

    expect(repository.projects, contains('Comp 2101'));

    repository.removeLocalEvent(moved.event.id);
    expect(repository.projects, isNot(contains('moved-local-1')));
  });

  test('moved events replace the original in range loads', () async {
    final store = await _store(const <Task>[]);
    final repository = CalendarRepository(
      store: store,
      api: _FakeCalendarApi(),
    );

    final created = await repository.createEvent(
      event: _event(id: 'keep-1', title: 'Move me'),
    );
    final before = await repository.loadEvents(startDate: start, endDate: end);
    expect(before.events.map((event) => event.title), contains('Move me'));

    repository.applyLocalMove(created.event, DateTime(2026, 3, 6, 9));
    final after = await repository.loadEvents(startDate: start, endDate: end);
    expect(after.events, isEmpty);

    final nextWeek = await repository.loadEvents(
      startDate: DateTime(2026, 3, 6),
      endDate: DateTime(2026, 3, 7),
    );
    expect(nextWeek.events.single.id, startsWith('moved-local-'));
  });
}
