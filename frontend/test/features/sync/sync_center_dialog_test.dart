import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';
import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/sync/models/sync_conflict.dart';
import 'package:frontend/features/sync/models/sync_operation.dart';
import 'package:frontend/features/sync/models/sync_snapshot.dart';
import 'package:frontend/features/sync/widgets/sync_center_dialog.dart';

import '../../helpers.dart';

class _FakeSyncRepository implements SyncAwareTaskRepository {
  _FakeSyncRepository({
    SyncSnapshot? snapshot,
    List<SyncConflict>? conflicts,
    List<SyncOperation>? operations,
  }) : syncState = ValueNotifier<SyncSnapshot>(
         snapshot ?? const SyncSnapshot(),
       ),
       conflicts = conflicts ?? <SyncConflict>[],
       operations = operations ?? <SyncOperation>[];

  @override
  final ValueNotifier<SyncSnapshot> syncState;

  @override
  final List<SyncConflict> conflicts;

  @override
  final List<SyncOperation> operations;

  int retryCount = 0;
  ConflictResolution? lastResolution;
  bool succeed = true;

  @override
  Future<List<Task>> load(String ownerId) async => const <Task>[];

  @override
  Future<void> save(String ownerId, List<Task> tasks) async {}

  @override
  Future<void> clear(String ownerId) async {}

  @override
  Future<void> discardOperation(String operationId) async {
    operations.removeWhere((operation) => operation.id == operationId);
  }

  @override
  Future<void> retrySync() async {
    retryCount += 1;
  }

  @override
  Future<SyncResolutionResult> resolveConflict(
    SyncConflict conflict,
    ConflictResolution resolution,
  ) async {
    lastResolution = resolution;
    if (!succeed) {
      return const SyncResolutionResult(
        success: false,
        error: 'Could not reach the server.',
      );
    }
    conflicts.remove(conflict);
    return SyncResolutionResult(success: true, remoteTask: conflict.remoteTask);
  }
}

TaskStore _store(_FakeSyncRepository repository) {
  return TaskStore(repository: repository, ownerId: 'owner');
}

Widget _host(TaskStore store) {
  return MaterialApp(
    theme: AuxiliaTheme.light(),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showSyncCenterDialog(context, store),
          child: const Text('Open sync'),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester, TaskStore store) async {
  await tester.pumpWidget(_host(store));
  await tester.tap(find.text('Open sync'));
  await tester.pumpAndSettle();
}

SyncConflict _conflict({Task? remote}) {
  return SyncConflict(
    id: 'conflict-1',
    operationId: 'operation-1',
    taskId: 'task-1',
    kind: SyncConflictKind.createCollision,
    localTask: makeTask(id: 'task-1', title: 'Local copy'),
    remoteTask: remote,
    detectedAt: DateTime(2026, 3, 4, 10),
  );
}

void main() {
  testWidgets('shows a clean state with the last successful sync', (
    tester,
  ) async {
    final repository = _FakeSyncRepository(
      snapshot: SyncSnapshot(
        phase: SyncPhase.synced,
        lastSyncedAt: DateTime(2026, 3, 4, 15, 6),
      ),
    );

    await _open(tester, _store(repository));

    expect(find.text('Sync centre'), findsOneWidget);
    expect(find.text('All changes saved'), findsOneWidget);
    expect(find.text('Last successful sync: 04/03/2026 15:06'), findsOneWidget);
    expect(find.text('Every change has reached the server.'), findsOneWidget);
    expect(find.text('Retry now'), findsOneWidget);
  });

  testWidgets('lists pending operations with attempts and errors', (
    tester,
  ) async {
    final task = makeTask(id: 'task-1', title: 'Upload notes');
    final operation = SyncOperation(
      id: 'operation-1',
      taskId: task.id,
      type: SyncOperationType.create,
      payload: task.toJson(),
      queuedAt: DateTime(2026, 3, 4, 10),
      attempts: 2,
      lastError: 'Connection reset',
    );
    final repository = _FakeSyncRepository(
      snapshot: const SyncSnapshot(phase: SyncPhase.offline, pendingCount: 1),
      operations: <SyncOperation>[operation],
    );

    await _open(tester, _store(repository));

    expect(find.text('Offline — changes queued'), findsOneWidget);
    expect(find.text('WAITING TO SEND'), findsOneWidget);
    expect(find.text('Upload notes'), findsOneWidget);
    expect(
      find.textContaining('Create · 2 attempts · Connection reset'),
      findsOneWidget,
    );
  });

  testWidgets('explains a conflict and accepts the server copy', (
    tester,
  ) async {
    final conflict = _conflict(
      remote: makeTask(id: 'task-1', title: 'Server copy'),
    );
    final repository = _FakeSyncRepository(
      snapshot: const SyncSnapshot(phase: SyncPhase.conflict, conflictCount: 1),
      conflicts: <SyncConflict>[conflict],
    );
    final store = _store(repository);

    await _open(tester, store);

    expect(find.text('1 conflict to resolve'), findsOneWidget);
    expect(find.text('NEEDS A DECISION'), findsOneWidget);
    expect(
      find.text('Already exists. Your version differs from the server.'),
      findsOneWidget,
    );
    expect(find.text('Server: Server copy'), findsOneWidget);

    await tester.tap(find.text('Use server'));
    await tester.pumpAndSettle();

    expect(repository.lastResolution, ConflictResolution.keepRemote);
    expect(find.text('Every change has reached the server.'), findsOneWidget);
  });

  testWidgets('keeps the local copy and reports a failed resolution', (
    tester,
  ) async {
    final conflict = _conflict();
    final repository = _FakeSyncRepository(
      snapshot: const SyncSnapshot(phase: SyncPhase.conflict, conflictCount: 1),
      conflicts: <SyncConflict>[conflict],
    )..succeed = false;

    await _open(tester, _store(repository));

    expect(find.text('Use server (deleted)'), findsOneWidget);

    await tester.tap(find.text('Keep mine'));
    await tester.pumpAndSettle();

    expect(repository.lastResolution, ConflictResolution.keepLocal);
    expect(find.text('Could not reach the server.'), findsOneWidget);
    expect(find.text('Keep mine'), findsOneWidget);
  });

  testWidgets('retry is available unless a sync is already running', (
    tester,
  ) async {
    final repository = _FakeSyncRepository(
      snapshot: const SyncSnapshot(phase: SyncPhase.pending, pendingCount: 1),
      operations: <SyncOperation>[
        SyncOperation(
          id: 'operation-1',
          taskId: 'task-1',
          type: SyncOperationType.update,
          payload: makeTask(id: 'task-1').toJson(),
          queuedAt: DateTime(2026, 3, 4, 10),
        ),
      ],
    );

    await _open(tester, _store(repository));
    await tester.tap(find.text('Retry now'));
    await tester.pumpAndSettle();

    expect(repository.retryCount, 1);
  });

  testWidgets('retry is disabled while syncing', (tester) async {
    final repository = _FakeSyncRepository(
      snapshot: const SyncSnapshot(phase: SyncPhase.syncing, pendingCount: 1),
    );

    await _open(tester, _store(repository));

    final retry = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Retry now'),
    );
    expect(retry.onPressed, isNull);
  });

  testWidgets('closes back to the page', (tester) async {
    final repository = _FakeSyncRepository();

    await _open(tester, _store(repository));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Sync centre'), findsNothing);
    expect(find.text('Open sync'), findsOneWidget);
  });
}
