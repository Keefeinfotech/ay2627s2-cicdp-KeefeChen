import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';
import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/sync/data/background_sync_handler.dart';
import 'package:frontend/features/sync/models/sync_conflict.dart';
import 'package:frontend/features/sync/models/sync_operation.dart';
import 'package:frontend/features/sync/models/sync_snapshot.dart';

class _FakeConnectivity extends ConnectivityAdapter {
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  void emit(List<ConnectivityResult> results) => _controller.add(results);

  Future<void> close() => _controller.close();
}

class _FakeSyncRepository implements SyncAwareTaskRepository {
  @override
  final ValueNotifier<SyncSnapshot> syncState = ValueNotifier<SyncSnapshot>(
    const SyncSnapshot(phase: SyncPhase.pending, pendingCount: 1),
  );

  @override
  final List<SyncConflict> conflicts = <SyncConflict>[];

  @override
  final List<SyncOperation> operations = <SyncOperation>[];

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
  ) async => const SyncResolutionResult(success: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('flushes when connectivity becomes available', () async {
    final repository = _FakeSyncRepository();
    final store = TaskStore(repository: repository, ownerId: 'owner');
    final connectivity = _FakeConnectivity();
    final handler = BackgroundSyncHandler(
      store: store,
      connectivity: connectivity,
      interval: const Duration(hours: 1),
    )..start();

    await Future<void>.delayed(Duration.zero);
    final callsAfterStart = repository.retryCount;

    connectivity.emit(const <ConnectivityResult>[ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);

    expect(repository.retryCount, callsAfterStart + 1);

    handler.dispose();
    await connectivity.close();
  });

  test('ignores connectivity loss', () async {
    final repository = _FakeSyncRepository();
    final store = TaskStore(repository: repository, ownerId: 'owner');
    final connectivity = _FakeConnectivity();
    final handler = BackgroundSyncHandler(
      store: store,
      connectivity: connectivity,
      interval: const Duration(hours: 1),
    )..start();

    await Future<void>.delayed(Duration.zero);
    final callsAfterStart = repository.retryCount;

    connectivity.emit(const <ConnectivityResult>[ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);

    expect(repository.retryCount, callsAfterStart);

    handler.dispose();
    await connectivity.close();
  });

  test('stop cancels the connectivity subscription', () async {
    final repository = _FakeSyncRepository();
    final store = TaskStore(repository: repository, ownerId: 'owner');
    final connectivity = _FakeConnectivity();
    final handler = BackgroundSyncHandler(
      store: store,
      connectivity: connectivity,
      interval: const Duration(hours: 1),
    )..start();

    await Future<void>.delayed(Duration.zero);
    handler.stop();
    final callsAfterStop = repository.retryCount;

    connectivity.emit(const <ConnectivityResult>[ConnectivityResult.mobile]);
    await Future<void>.delayed(Duration.zero);

    expect(repository.retryCount, callsAfterStop);

    await connectivity.close();
  });
}
