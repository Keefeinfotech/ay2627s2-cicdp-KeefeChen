import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/calendar/data/models/calendar_event.dart';
import 'package:frontend/features/calendar/data/repositories/calendar_repository.dart';
import 'package:frontend/features/calendar/domain/usecases/analyze_schedule.dart';
import 'package:frontend/features/calendar/presentation/controllers/calendar_controller.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';
import 'package:frontend/features/home/models/task.dart';

class _FakeCalendarRepository extends CalendarRepository {
  _FakeCalendarRepository({required super.store});

  CalendarLoadResult result = const CalendarLoadResult(
    events: <CalendarEvent>[],
  );
  Object? loadError;
  CalendarWriteResult? writeResult;
  Object? writeError;
  List<CalendarEvent> conflictList = const <CalendarEvent>[];
  int loadCount = 0;

  @override
  Future<CalendarLoadResult> loadEvents({
    required DateTime startDate,
    required DateTime endDate,
    String? groupId,
    String? token,
  }) async {
    loadCount += 1;
    if (loadError != null) throw loadError!;
    return result;
  }

  @override
  Future<CalendarWriteResult> createEvent({
    required CalendarEvent event,
    String? token,
  }) async {
    if (writeError != null) throw writeError!;
    return writeResult ??
        CalendarWriteResult(
          event: event.copyWith(id: 'created-1'),
          synced: true,
        );
  }

  @override
  Future<List<CalendarEvent>> checkConflicts({
    required DateTime startTime,
    required DateTime endTime,
    String? token,
    String? excludeId,
  }) async => conflictList;

  @override
  CalendarWriteResult applyLocalMove(CalendarEvent event, DateTime newStart) {
    return CalendarWriteResult(
      event: event.copyWith(
        id: 'moved-${event.id}',
        startTime: newStart,
        endTime: newStart.add(event.duration),
      ),
      warning: 'Preview updated.',
    );
  }

  @override
  List<String> get projects => const <String>['COMP 2101'];
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

CalendarEvent _event({
  String id = 'event-1',
  String title = 'Seminar',
  DateTime? start,
  int durationMinutes = 45,
}) {
  final startTime = start ?? DateTime(2026, 3, 4, 10);
  return CalendarEvent(
    id: id,
    title: title,
    startTime: startTime,
    endTime: startTime.add(Duration(minutes: durationMinutes)),
  );
}

void main() {
  final initial = DateTime(2026, 3, 4); // A Wednesday.

  test('computes daily, weekly and monthly ranges', () async {
    final store = await _store(const <Task>[]);
    final repository = _FakeCalendarRepository(store: store);
    final controller = CalendarController(
      repository: repository,
      store: store,
      initialDate: initial,
    );

    expect(controller.view, CalendarViewMode.weekly);
    expect(controller.rangeStart, DateTime(2026, 3, 2));
    expect(controller.rangeEnd, DateTime(2026, 3, 9));

    controller.setView(CalendarViewMode.daily);
    expect(controller.rangeStart, initial);
    expect(controller.rangeEnd, initial.add(const Duration(days: 1)));

    controller.setView(CalendarViewMode.monthly);
    expect(controller.rangeStart, DateTime(2026, 3));
    expect(controller.rangeEnd, DateTime(2026, 4));

    // Rapid view changes are queued: the pending reload runs once the
    // in-flight load finishes instead of being silently dropped.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(repository.loadCount, 2);

    controller.moveBy(1);
    expect(controller.focusDate, DateTime(2026, 4));

    controller.moveBy(-1);
    expect(controller.focusDate, DateTime(2026, 3));

    controller.setView(CalendarViewMode.weekly);
    controller.moveBy(2);
    expect(controller.focusDate, DateTime(2026, 3, 15));

    controller.setView(CalendarViewMode.daily);
    controller.moveBy(-1);
    expect(controller.focusDate, DateTime(2026, 3, 14));
  });

  test('selecting a date outside the range reloads', () async {
    final store = await _store(const <Task>[]);
    final repository = _FakeCalendarRepository(store: store);
    final controller = CalendarController(
      repository: repository,
      store: store,
      initialDate: initial,
    );

    await controller.load();
    expect(repository.loadCount, 1);

    controller.selectDate(DateTime(2026, 3, 5));
    expect(repository.loadCount, 1);
    expect(controller.focusDate, DateTime(2026, 3, 5));

    controller.selectDate(DateTime(2026, 4, 10));
    await Future<void>.delayed(Duration.zero);
    expect(repository.loadCount, 2);
    expect(controller.focusDate, DateTime(2026, 4, 10));

    controller.selectDate(DateTime(2026, 4, 10));
    await Future<void>.delayed(Duration.zero);
    expect(repository.loadCount, 2);
  });

  test('setGroup normalises blanks and reloads', () async {
    final store = await _store(const <Task>[]);
    final repository = _FakeCalendarRepository(store: store);
    final controller = CalendarController(
      repository: repository,
      store: store,
      initialDate: initial,
    );

    controller.setGroup('   ');
    expect(controller.groupId, isNull);

    controller.setGroup(' COMP 2101 ');
    expect(controller.groupId, 'COMP 2101');
    expect(repository.loadCount, 1);

    controller.setGroup('COMP 2101');
    expect(repository.loadCount, 1);
  });

  test('goToToday resets and reloads', () async {
    final store = await _store(const <Task>[]);
    final repository = _FakeCalendarRepository(store: store);
    final controller = CalendarController(
      repository: repository,
      store: store,
      initialDate: initial,
    );

    controller.goToToday();

    final now = DateTime.now();
    expect(controller.focusDate, DateTime(now.year, now.month, now.day));
    expect(repository.loadCount, 1);
  });

  test('load exposes events, warnings and the schedule analysis', () async {
    final store = await _store(const <Task>[]);
    final event = _event(start: DateTime(2026, 3, 4, 10), durationMinutes: 120);
    final repository = _FakeCalendarRepository(store: store)
      ..result = CalendarLoadResult(
        events: <CalendarEvent>[event],
        isRemote: true,
        warning: 'Offline.',
      );
    final controller = CalendarController(
      repository: repository,
      store: store,
      initialDate: initial,
    );

    await controller.load();

    expect(controller.hasLoaded, isTrue);
    expect(controller.isRemote, isTrue);
    expect(controller.warning, 'Offline.');
    expect(controller.events, contains(event));
    expect(controller.focusDay.events, contains(event));
    expect(controller.visibleDays, isNotEmpty);
    expect(controller.analysis.dayFor(initial).events, contains(event));

    controller.dismissWarning();
    expect(controller.warning, isNull);
  });

  test('load records a readable error when the repository throws', () async {
    final store = await _store(const <Task>[]);
    final repository = _FakeCalendarRepository(store: store)
      ..loadError = StateError('boom');
    final controller = CalendarController(
      repository: repository,
      store: store,
      initialDate: initial,
    );

    await controller.load();

    expect(
      controller.error,
      'The calendar could not be loaded. Please try again.',
    );

    repository.loadError = null;
    await controller.retry();
    expect(controller.error, isNull);
  });

  test('createEvent adds the new event in order', () async {
    final store = await _store(const <Task>[]);
    final repository = _FakeCalendarRepository(store: store)
      ..result = CalendarLoadResult(
        events: <CalendarEvent>[
          _event(start: DateTime(2026, 3, 4, 16), title: 'Late'),
        ],
      );
    final controller = CalendarController(
      repository: repository,
      store: store,
      initialDate: initial,
    );
    await controller.load();

    final created = await controller.createEvent(
      _event(start: DateTime(2026, 3, 4, 8), title: 'Early'),
    );

    expect(created, isNotNull);
    expect(controller.events.map((event) => event.title), <String>[
      'Early',
      'Late',
    ]);

    repository.writeError = StateError('boom');
    final failed = await controller.createEvent(
      _event(start: DateTime(2026, 3, 4, 12), title: 'Failing'),
    );
    expect(failed, isNull);
    expect(
      controller.error,
      'The event could not be created. Please try again.',
    );
  });

  test('conflictsFor prefers remote results and falls back locally', () async {
    final local = _event(id: 'local', start: DateTime(2026, 3, 4, 10));
    final store = await _store(const <Task>[]);
    final repository = _FakeCalendarRepository(store: store)
      ..result = CalendarLoadResult(events: <CalendarEvent>[local]);
    final controller = CalendarController(
      repository: repository,
      store: store,
      token: 'token-1',
      initialDate: initial,
    );
    await controller.load();

    repository.conflictList = <CalendarEvent>[
      _event(id: 'remote', start: DateTime(2026, 3, 4, 11)),
    ];
    expect(
      (await controller.conflictsFor(
        DateTime(2026, 3, 4, 9),
        DateTime(2026, 3, 4, 13),
      )).single.id,
      'remote',
    );

    repository.conflictList = const <CalendarEvent>[];
    final fallback = await controller.conflictsFor(
      DateTime(2026, 3, 4, 9),
      DateTime(2026, 3, 4, 13),
    );
    expect(fallback.single.id, 'local');

    final none = await controller.conflictsFor(
      DateTime(2026, 3, 6, 9),
      DateTime(2026, 3, 6, 10),
    );
    expect(none, isEmpty);
  });

  test('applies schedule suggestions and rejects empty ones', () async {
    final event = _event(id: 'event-1', start: DateTime(2026, 3, 4, 10));
    final store = await _store(const <Task>[]);
    final repository = _FakeCalendarRepository(store: store)
      ..result = CalendarLoadResult(events: <CalendarEvent>[event]);
    final controller = CalendarController(
      repository: repository,
      store: store,
      initialDate: initial,
    );
    await controller.load();

    final result = controller.applySuggestion(
      ScheduleSuggestion(
        id: 'move-1',
        title: 'Move',
        description: 'Move it',
        day: initial,
        event: event,
        suggestedStart: DateTime(2026, 3, 5, 9),
      ),
    );

    expect(result, isNotNull);
    expect(controller.events.single.id, 'moved-event-1');
    expect(controller.warning, 'Preview updated.');

    expect(
      controller.applySuggestion(
        ScheduleSuggestion(
          id: 'empty',
          title: 'Empty',
          description: 'Empty',
          day: DateTime(2026, 3, 4),
        ),
      ),
      isNull,
    );
  });

  test('detected overload and overlaps are exposed to the UI', () async {
    final store = await _store(const <Task>[]);
    final first = _event(
      id: 'a',
      title: 'A',
      start: DateTime(2026, 3, 4, 9),
      durationMinutes: 180,
    );
    final second = _event(
      id: 'b',
      title: 'B',
      start: DateTime(2026, 3, 4, 10),
      durationMinutes: 180,
    );
    final repository = _FakeCalendarRepository(store: store)
      ..result = CalendarLoadResult(events: <CalendarEvent>[first, second]);
    final controller = CalendarController(
      repository: repository,
      store: store,
      initialDate: initial,
    );
    await controller.load();

    expect(controller.hasOverlaps, isTrue);
    expect(controller.overloadedDayCount, greaterThan(0));
    expect(controller.analysis.overlaps, isNotEmpty);
    expect(controller.projects, <String>['COMP 2101']);
  });
}
