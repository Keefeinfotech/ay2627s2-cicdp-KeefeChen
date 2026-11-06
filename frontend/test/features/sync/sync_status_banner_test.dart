import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';
import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/sync/models/sync_conflict.dart';
import 'package:frontend/features/sync/models/sync_operation.dart';
import 'package:frontend/features/sync/models/sync_snapshot.dart';
import 'package:frontend/features/sync/widgets/sync_status_banner.dart';

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
    conflicts.remove(conflict);
    return SyncResolutionResult(
      success: true,
      remoteTask: conflict.remoteTask,
      deleteLocal: conflict.remoteTask == null,
    );
  }
}

Widget _host(TaskStore store) {
  return MaterialApp(
    theme: AuxiliaTheme.light(),
    home: Scaffold(body: SyncStatusBanner(store: store)),
  );
}

void main() {
  testWidgets('renders nothing when everything is saved', (tester) async {
    final repository = _FakeSyncRepository(
      snapshot: const SyncSnapshot(phase: SyncPhase.synced),
    );
    final store = TaskStore(repository: repository, ownerId: 'owner');

    await tester.pumpWidget(_host(store));

    expect(find.byType(SyncStatusBanner), findsOneWidget);
    expect(find.text('All changes saved'), findsNothing);
  });

  testWidgets('shows the offline state and retries on demand', (tester) async {
    final repository = _FakeSyncRepository(
      snapshot: const SyncSnapshot(phase: SyncPhase.offline, pendingCount: 2),
    );
    final store = TaskStore(repository: repository, ownerId: 'owner');

    await tester.pumpWidget(_host(store));

    expect(find.text('Offline — changes queued'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.retryCount, 1);
  });

  testWidgets('shows the conflict state with a review action', (tester) async {
    final repository = _FakeSyncRepository(
      snapshot: const SyncSnapshot(phase: SyncPhase.conflict, conflictCount: 1),
    );
    final store = TaskStore(repository: repository, ownerId: 'owner');

    await tester.pumpWidget(_host(store));

    expect(find.text('1 conflict to resolve'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('disables retry while a sync is running', (tester) async {
    final repository = _FakeSyncRepository(
      snapshot: const SyncSnapshot(phase: SyncPhase.syncing),
    );
    final store = TaskStore(repository: repository, ownerId: 'owner');

    await tester.pumpWidget(_host(store));

    expect(find.text('Saving changes…'), findsOneWidget);
    final retry = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Retry'),
    );
    expect(retry.onPressed, isNull);
  });
}
