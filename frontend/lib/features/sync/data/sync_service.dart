import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../home/data/task_api_mapper.dart';
import '../../home/models/task.dart';
import '../models/sync_conflict.dart';
import '../models/sync_operation.dart';
import '../models/sync_snapshot.dart';
import 'sync_queue_store.dart';

typedef SyncTokenProvider = Future<String?> Function();

enum _ApplyOutcome { applied, conflict, offline, failed }

/// Replays the durable offline queue against the task API.
///
/// The service owns no UI state and no task cache. It exposes a
/// [ValueNotifier] snapshot plus the queue/conflict lists; the repository is
/// responsible for merging remote results back into the local cache.
class SyncService {
  SyncService({
    required ApiClient api,
    required this.ownerId,
    required SyncTokenProvider tokenProvider,
    SyncQueueStore? store,
  }) : _api = api,
       _tokenProvider = tokenProvider,
       _store = store ?? SyncQueueStore();

  final ApiClient _api;
  final String ownerId;
  final SyncTokenProvider _tokenProvider;
  final SyncQueueStore _store;

  final ValueNotifier<SyncSnapshot> snapshot = ValueNotifier<SyncSnapshot>(
    const SyncSnapshot(),
  );

  static const int _deadLetterAfterFailures = 3;

  List<SyncOperation> _operations = <SyncOperation>[];
  List<SyncConflict> _conflicts = <SyncConflict>[];
  DateTime? _lastSyncedAt;
  bool _loaded = false;
  bool _flushing = false;

  List<SyncOperation> get operations =>
      List<SyncOperation>.unmodifiable(_operations);
  List<SyncConflict> get conflicts =>
      List<SyncConflict>.unmodifiable(_conflicts);
  bool get isFlushing => _flushing;

  Future<void> load() async {
    if (_loaded) return;
    final data = await _store.load(ownerId);
    _operations = List<SyncOperation>.of(data.operations);
    _conflicts = List<SyncConflict>.of(data.conflicts);
    _lastSyncedAt = data.lastSyncedAt;
    _loaded = true;
    await _publish();
  }

  /// Adds a change to the queue, coalescing repeated edits of the same task.
  Future<void> enqueue({
    required SyncOperationType type,
    required Task task,
    DateTime? baseUpdatedAt,
  }) async {
    await load();

    final existing = _operations.where((op) => op.taskId == task.id).toList();
    _operations.removeWhere((op) => op.taskId == task.id);

    if (type == SyncOperationType.delete) {
      _operations.add(
        SyncOperation(
          id: _newId(),
          taskId: task.id,
          type: SyncOperationType.delete,
          payload: task.toJson(),
          queuedAt: DateTime.now(),
          baseUpdatedAt: baseUpdatedAt ?? task.updatedAt,
        ),
      );
    } else if (type == SyncOperationType.create) {
      final hadUpdate = existing.any(
        (op) => op.type == SyncOperationType.update,
      );
      _operations.add(
        SyncOperation(
          id: _newId(),
          taskId: task.id,
          type: hadUpdate ? SyncOperationType.update : SyncOperationType.create,
          payload: task.toJson(),
          queuedAt: DateTime.now(),
          baseUpdatedAt: baseUpdatedAt ?? task.updatedAt,
        ),
      );
    } else {
      SyncOperation? existingCreate;
      for (final op in existing) {
        if (op.type == SyncOperationType.create) {
          existingCreate = op;
          break;
        }
      }
      _operations.add(
        SyncOperation(
          id: existingCreate?.id ?? _newId(),
          taskId: task.id,
          type: existingCreate == null
              ? SyncOperationType.update
              : SyncOperationType.create,
          payload: task.toJson(),
          queuedAt: existingCreate?.queuedAt ?? DateTime.now(),
          baseUpdatedAt:
              existingCreate?.baseUpdatedAt ?? baseUpdatedAt ?? task.updatedAt,
        ),
      );
    }

    await _persist();
    await _publish();
  }

  /// Attempts to apply every queued change. Safe to call repeatedly.
  Future<void> flush() async {
    await load();
    if (_flushing) return;

    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      await _publish(phase: SyncPhase.localOnly);
      return;
    }
    if (_operations.isEmpty && _conflicts.isEmpty) {
      await _publish(phase: SyncPhase.synced);
      return;
    }
    if (_operations.isEmpty && _conflicts.isNotEmpty) {
      await _publish(phase: SyncPhase.conflict);
      return;
    }

    _flushing = true;
    await _publish(phase: SyncPhase.syncing);

    var offline = false;
    String? failure;
    final remaining = <SyncOperation>[];

    for (var index = 0; index < _operations.length; index++) {
      final operation = _operations[index];

      if (operation.isDeadLetter || !operation.isDue) {
        remaining.add(operation);
        continue;
      }

      final outcome = await _apply(operation, token);

      switch (outcome) {
        case _ApplyOutcome.applied:
          continue;
        case _ApplyOutcome.conflict:
          // The operation has been converted into a user-facing conflict.
          continue;
        case _ApplyOutcome.offline:
          offline = true;
          remaining.addAll(_operations.sublist(index));
          index = _operations.length;
        case _ApplyOutcome.failed:
          // A permanent failure is retained for inspection and later manual
          // retry or discard, but it must not block unrelated queued work.
          final failedOperation = _operations[index];
          failure = failedOperation.lastError ?? operation.lastError;
          remaining.add(failedOperation);
      }
    }

    _operations = remaining;
    _flushing = false;

    if (!offline && failure == null && _conflicts.isEmpty) {
      _lastSyncedAt = DateTime.now();
    }

    await _persist();
    final deadLetterCount = _operations
        .where((operation) => operation.isDeadLetter)
        .length;
    final failureMessage =
        failure ??
        (deadLetterCount > 0
            ? '$deadLetterCount ${deadLetterCount == 1 ? 'change' : 'changes'} need attention.'
            : null);
    await _publish(
      phase: _conflicts.isNotEmpty
          ? SyncPhase.conflict
          : offline
          ? SyncPhase.offline
          : failureMessage != null
          ? SyncPhase.failed
          : _operations.isNotEmpty
          ? SyncPhase.pending
          : SyncPhase.synced,
      message: failureMessage,
    );
  }

  /// Manual retry. Clears automatic backoff and dead-letter state so the
  /// user can rescue an operation after fixing the underlying problem.
  Future<void> retry() async {
    await load();
    _operations = _operations
        .map(
          (operation) =>
              operation.copyWith(clearNextAttempt: true, clearDeadLetter: true),
        )
        .toList(growable: false);
    await _persist();
    return flush();
  }

  /// Removes an operation from the durable queue. Used for dead-lettered
  /// changes the user chooses to discard after reviewing the error.
  Future<void> discard(String operationId) async {
    await load();
    _operations = _operations
        .where((operation) => operation.id != operationId)
        .toList(growable: false);
    await _persist();
    await _publish();
  }

  Future<SyncResolutionResult> resolveConflict(
    SyncConflict conflict,
    ConflictResolution resolution,
  ) async {
    await load();
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      return const SyncResolutionResult(
        success: false,
        error: 'Sign in before resolving sync conflicts.',
      );
    }

    try {
      if (resolution == ConflictResolution.keepRemote) {
        _removeConflict(conflict);
        await _persist();
        await _publish();
        return SyncResolutionResult(
          success: true,
          remoteTask: conflict.remoteTask,
          deleteLocal: conflict.remoteTask == null,
        );
      }

      // Keep the local version. The user has explicitly chosen it, so the
      // base-version check is intentionally bypassed.
      final remote = conflict.remoteTask;
      if (remote == null) {
        await _api.postJson(
          ApiEndpoints.tasks,
          TaskApiMapper.toCreateJson(conflict.localTask),
          token: token,
        );
      } else {
        await _api.patchJson(
          ApiEndpoints.task(conflict.taskId),
          TaskApiMapper.toUpdateJson(conflict.localTask),
          token: token,
        );
      }
      _removeConflict(conflict);
      _lastSyncedAt = DateTime.now();
      await _persist();
      await _publish();
      return const SyncResolutionResult(success: true);
    } on ApiException catch (error) {
      await _publish(phase: SyncPhase.failed, message: error.message);
      return SyncResolutionResult(success: false, error: error.message);
    } catch (_) {
      await _publish(
        phase: SyncPhase.failed,
        message: 'The conflict could not be resolved.',
      );
      return const SyncResolutionResult(
        success: false,
        error: 'The conflict could not be resolved.',
      );
    }
  }

  Future<void> clear() async {
    _operations = <SyncOperation>[];
    _conflicts = <SyncConflict>[];
    _lastSyncedAt = null;
    await _store.clear(ownerId);
    await _publish(phase: SyncPhase.localOnly);
  }

  // ---------------------------------------------------------------------------
  // Replay
  // ---------------------------------------------------------------------------

  Future<_ApplyOutcome> _apply(SyncOperation operation, String token) async {
    final task = operation.task;
    if (task == null) {
      // The payload is unreadable; drop the operation rather than retrying
      // forever.
      return _ApplyOutcome.applied;
    }

    try {
      switch (operation.type) {
        case SyncOperationType.create:
          return await _applyCreate(operation, task, token);
        case SyncOperationType.update:
          return await _applyUpdate(operation, task, token);
        case SyncOperationType.delete:
          await _api.deleteJson(
            ApiEndpoints.task(operation.taskId),
            token: token,
          );
          return _ApplyOutcome.applied;
      }
    } on ApiException catch (error) {
      if (error.statusCode == 404 &&
          operation.type == SyncOperationType.delete) {
        return _ApplyOutcome.applied;
      }
      if (error.statusCode == 409 ||
          error.code == 'TASK_ALREADY_EXISTS' ||
          error.code == 'TASK_CONFLICT') {
        final remote = await _fetchTask(operation.taskId, token);
        _addConflict(operation, task, remote, SyncConflictKind.createCollision);
        return _ApplyOutcome.conflict;
      }
      if (error.isUnauthorized) {
        // Authentication can be restored; keep the operation available for
        // manual retry once the user signs in again.
        _markFailed(
          operation,
          'Your session expired. Sign in to sync.',
          permanent: false,
        );
        return _ApplyOutcome.failed;
      }
      if (error.statusCode == null || error.statusCode! >= 500) {
        _markFailed(operation, error.message, permanent: false);
        return _ApplyOutcome.offline;
      }
      _markFailed(operation, error.message, permanent: true);
      return _ApplyOutcome.failed;
    } catch (_) {
      _markFailed(operation, 'Could not reach the server.', permanent: false);
      return _ApplyOutcome.offline;
    }
  }

  Future<_ApplyOutcome> _applyCreate(
    SyncOperation operation,
    Task task,
    String token,
  ) async {
    await _api.postJson(
      ApiEndpoints.tasks,
      TaskApiMapper.toCreateJson(task),
      token: token,
    );
    return _ApplyOutcome.applied;
  }

  Future<_ApplyOutcome> _applyUpdate(
    SyncOperation operation,
    Task task,
    String token,
  ) async {
    Task? remote;
    try {
      remote = await _fetchTask(operation.taskId, token);
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
    }

    if (remote == null) {
      // The task was removed elsewhere. The local edit cannot be applied
      // idempotently without resurrecting a deleted task, and it must not be
      // dropped either, so the user decides.
      _addConflict(operation, task, null, SyncConflictKind.deleteCollision);
      return _ApplyOutcome.conflict;
    }

    final base = operation.baseUpdatedAt ?? operation.queuedAt;
    final remoteChangedAfterBase = remote.updatedAt.isAfter(base);
    if (remoteChangedAfterBase && !_sameContent(remote, task)) {
      _addConflict(operation, task, remote, SyncConflictKind.updateCollision);
      return _ApplyOutcome.conflict;
    }

    // Compare-and-swap against the server row we just fetched: if it changed
    // between the fetch and this write, the server rejects with
    // TASK_CONFLICT instead of overwriting the concurrent edit.
    await _api.patchJson(
      ApiEndpoints.task(operation.taskId),
      TaskApiMapper.toUpdateJson(task, expectedUpdatedAt: remote.updatedAt),
      token: token,
    );
    return _ApplyOutcome.applied;
  }

  Future<Task?> _fetchTask(String taskId, String token) async {
    final data = await _api.getJson(ApiEndpoints.task(taskId), token: token);
    return TaskApiMapper.fromApi(data['data'] ?? data);
  }

  bool _sameContent(Task a, Task b) {
    return a.title == b.title &&
        a.notes == b.notes &&
        a.course == b.course &&
        a.priority == b.priority &&
        a.status == b.status &&
        a.groupId == b.groupId &&
        a.assigneeId == b.assigneeId &&
        _sameTags(a.tags, b.tags) &&
        _sameDate(a.dueDate, b.dueDate) &&
        _sameDate(a.reminderAt, b.reminderAt);
  }

  bool _sameTags(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index].toLowerCase() != b[index].toLowerCase()) return false;
    }
    return true;
  }

  bool _sameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.isAtSameMomentAs(b);
  }

  void _addConflict(
    SyncOperation operation,
    Task local,
    Task? remote,
    SyncConflictKind kind,
  ) {
    _conflicts.removeWhere((conflict) => conflict.taskId == operation.taskId);
    _conflicts.add(
      SyncConflict(
        id: _newId(),
        operationId: operation.id,
        taskId: operation.taskId,
        kind: kind,
        localTask: local,
        remoteTask: remote,
        detectedAt: DateTime.now(),
      ),
    );
  }

  void _removeConflict(SyncConflict conflict) {
    _conflicts.removeWhere((item) => item.id == conflict.id);
  }

  void _markFailed(
    SyncOperation operation,
    String message, {
    required bool permanent,
  }) {
    final index = _operations.indexWhere((item) => item.id == operation.id);
    if (index < 0) return;
    final attempts = operation.attempts + 1;
    final nextAttemptAt = DateTime.now().add(_backoffFor(attempts));
    _operations[index] = operation.copyWith(
      attempts: attempts,
      lastError: message,
      nextAttemptAt: nextAttemptAt,
      deadLetteredAt: permanent && attempts >= _deadLetterAfterFailures
          ? DateTime.now()
          : null,
    );
  }

  Duration _backoffFor(int attempts) {
    final exponent = attempts < 1 ? 0 : attempts - 1;
    final minutes = pow(2, exponent).toInt().clamp(1, 60).toInt();
    // A small deterministic jitter avoids every client retrying in lockstep.
    return Duration(minutes: minutes + (attempts % 3));
  }

  // ---------------------------------------------------------------------------
  // Persistence and status
  // ---------------------------------------------------------------------------

  Future<void> _persist() async {
    await _store.save(
      ownerId,
      SyncQueueData(
        operations: _operations,
        conflicts: _conflicts,
        lastSyncedAt: _lastSyncedAt,
      ),
    );
  }

  Future<void> _publish({SyncPhase? phase, String? message}) async {
    final token = await _tokenProvider();
    final resolvedPhase =
        phase ??
        (token == null || token.isEmpty
            ? SyncPhase.localOnly
            : _conflicts.isNotEmpty
            ? SyncPhase.conflict
            : _operations.isNotEmpty
            ? SyncPhase.pending
            : SyncPhase.synced);
    snapshot.value = SyncSnapshot(
      phase: resolvedPhase,
      pendingCount: _operations.length,
      conflictCount: _conflicts.length,
      lastSyncedAt: _lastSyncedAt,
      message: message,
    );
  }

  String _newId() {
    final random = Random.secure();
    final bytes = List<int>.generate(12, (_) => random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  void dispose() {
    snapshot.dispose();
  }
}
