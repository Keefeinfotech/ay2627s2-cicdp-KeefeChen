import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../authentication/data/session_store.dart';
import '../../sync/data/sync_queue_store.dart';
import '../../sync/data/sync_service.dart';
import '../../sync/models/sync_conflict.dart';
import '../../sync/models/sync_operation.dart';
import '../../sync/models/sync_snapshot.dart';
import '../models/task.dart';
import 'task_api_mapper.dart';
import 'task_repository.dart';

/// Offline-first task repository backed by the REST API.
///
/// Local writes are committed to [SharedPreferences] immediately and appended
/// to a durable [SyncService] queue. The queue is replayed in the background;
/// failures never roll back the user's edit. This replaces the previous
/// best-effort "save then hope" reconciliation with explicit retry, conflict
/// detection and user-controlled resolution.
class ApiTaskRepository implements SyncAwareTaskRepository {
  ApiTaskRepository({
    String? token,
    SessionStore? sessions,
    ApiClient? api,
    SharedPreferences? preferences,
    SyncQueueStore? queueStore,
  }) : _tokenValue = token,
       _sessions = token == null ? (sessions ?? SessionStore()) : null,
       _api = api ?? ApiClient(),
       _cache = SharedPreferencesTaskRepository(preferences: preferences),
       _queueStore = queueStore;

  final String? _tokenValue;
  final SessionStore? _sessions;
  final ApiClient _api;
  final SharedPreferencesTaskRepository _cache;
  final SyncQueueStore? _queueStore;

  final ValueNotifier<SyncSnapshot> _syncState = ValueNotifier<SyncSnapshot>(
    const SyncSnapshot(),
  );

  SyncService? _service;
  String? _serviceOwner;
  bool _disposed = false;

  @override
  ValueListenable<SyncSnapshot> get syncState => _syncState;

  @override
  List<SyncConflict> get conflicts =>
      _service?.conflicts ?? const <SyncConflict>[];

  @override
  List<SyncOperation> get operations =>
      _service?.operations ?? const <SyncOperation>[];

  Future<String?> _token() async {
    if (_tokenValue != null && _tokenValue.isNotEmpty) return _tokenValue;
    if (_sessions == null) return null;
    try {
      final session = await _sessions.read().timeout(
        const Duration(seconds: 3),
      );
      return session?.token;
    } catch (_) {
      // A locked or unavailable keychain must not block local-first use.
      return null;
    }
  }

  Future<SyncService> _serviceFor(String ownerId) async {
    final existing = _service;
    if (existing != null && _serviceOwner == ownerId) return existing;

    existing?.snapshot.removeListener(_mirrorSnapshot);
    existing?.dispose();

    final service = SyncService(
      api: _api,
      ownerId: ownerId,
      tokenProvider: _token,
      store: _queueStore,
    );
    _service = service;
    _serviceOwner = ownerId;
    service.snapshot.addListener(_mirrorSnapshot);
    await service.load();
    _mirrorSnapshot();
    return service;
  }

  void _mirrorSnapshot() {
    if (_disposed) return;
    final value = _service?.snapshot.value;
    if (value != null) _syncState.value = value;
  }

  @override
  Future<List<Task>> load(String ownerId) async {
    final service = await _serviceFor(ownerId);
    final token = await _token();
    final cached = await _cache.load(ownerId);

    if (token == null || token.isEmpty) {
      await service.flush();
      return cached;
    }

    // Push local edits first so the fetch below returns the reconciled view.
    await service.flush();

    try {
      final remote = await _fetchAll(token);
      final merged = await _merge(service, cached, remote);
      await _cache.save(ownerId, merged);
      unawaited(service.flush());
      return merged;
    } on ApiException {
      return _cache.load(ownerId);
    } catch (_) {
      return _cache.load(ownerId);
    }
  }

  /// Merges the remote list with local tasks that still have queued work.
  Future<List<Task>> _merge(
    SyncService service,
    List<Task> local,
    List<Task> remote,
  ) async {
    final localById = <String, Task>{for (final task in local) task.id: task};
    final remoteById = <String, Task>{for (final task in remote) task.id: task};
    final pendingIds = service.operations.map((op) => op.taskId).toSet();
    final conflictIds = service.conflicts.map((item) => item.taskId).toSet();
    final deleteIds = service.operations
        .where((op) => op.type == SyncOperationType.delete)
        .map((op) => op.taskId)
        .toSet();
    final keepLocalIds = <String>{...pendingIds, ...conflictIds};

    final merged = <Task>[];
    for (final remoteTask in remote) {
      if (deleteIds.contains(remoteTask.id)) continue;
      final localTask = localById[remoteTask.id];
      if (keepLocalIds.contains(remoteTask.id) && localTask != null) {
        merged.add(localTask);
      } else {
        merged.add(remoteTask);
      }
    }

    for (final localTask in local) {
      if (remoteById.containsKey(localTask.id)) continue;
      if (deleteIds.contains(localTask.id)) continue;
      merged.add(localTask);
      if (!keepLocalIds.contains(localTask.id)) {
        // A task that only exists on this device should be uploaded.
        await service.enqueue(
          type: SyncOperationType.create,
          task: localTask,
          baseUpdatedAt: localTask.updatedAt,
        );
      }
    }

    return merged;
  }

  @override
  Future<void> save(String ownerId, List<Task> tasks) async {
    final service = await _serviceFor(ownerId);
    final previous = await _cache.load(ownerId);
    final previousById = <String, Task>{
      for (final task in previous) task.id: task,
    };
    final nextIds = tasks.map((task) => task.id).toSet();

    for (final task in tasks) {
      final old = previousById[task.id];
      if (old == null) {
        await service.enqueue(
          type: SyncOperationType.create,
          task: task,
          baseUpdatedAt: task.updatedAt,
        );
      } else if (!_sameVersion(old, task)) {
        await service.enqueue(
          type: SyncOperationType.update,
          task: task,
          baseUpdatedAt: old.updatedAt,
        );
      }
    }

    for (final old in previous) {
      if (nextIds.contains(old.id)) continue;
      await service.enqueue(
        type: SyncOperationType.delete,
        task: old,
        baseUpdatedAt: old.updatedAt,
      );
    }

    // Commit locally before touching the network so the UI never waits on it.
    await _cache.save(ownerId, tasks);
    unawaited(service.flush());
  }

  @override
  Future<void> clear(String ownerId) async {
    final service = await _serviceFor(ownerId);
    final cached = await _cache.load(ownerId);
    for (final task in cached) {
      await service.enqueue(
        type: SyncOperationType.delete,
        task: task,
        baseUpdatedAt: task.updatedAt,
      );
    }
    await _cache.clear(ownerId);

    final token = await _token();
    if (token == null || token.isEmpty) {
      await service.clear();
      return;
    }
    await service.flush();
  }

  @override
  Future<void> retrySync() async {
    final service = _service;
    if (service == null) return;
    await service.flush();
  }

  @override
  Future<void> discardOperation(String operationId) async {
    final ownerId = _serviceOwner;
    if (ownerId == null) return;
    final service = await _serviceFor(ownerId);
    await service.discard(operationId);
  }

  @override
  Future<SyncResolutionResult> resolveConflict(
    SyncConflict conflict,
    ConflictResolution resolution,
  ) async {
    final ownerId = _serviceOwner;
    if (ownerId == null) {
      return const SyncResolutionResult(
        success: false,
        error: 'Load your tasks before resolving a conflict.',
      );
    }
    final service = await _serviceFor(ownerId);
    final result = await service.resolveConflict(conflict, resolution);
    if (!result.success) return result;

    final cached = await _cache.load(ownerId);
    final next = List<Task>.of(cached);
    next.removeWhere((task) => task.id == conflict.taskId);
    if (!result.deleteLocal && result.remoteTask != null) {
      next.add(result.remoteTask!);
    }
    await _cache.save(ownerId, next);
    unawaited(service.flush());
    return result;
  }

  Future<List<Task>> _fetchAll(String token) async {
    final data = await _api.getJson(
      ApiEndpoints.tasks,
      token: token,
      query: const <String, String>{'page': '1', 'limit': '100'},
    );
    return TaskApiMapper.listFromApi(data['data']);
  }

  bool _sameVersion(Task a, Task b) {
    if (!a.updatedAt.isAtSameMomentAs(b.updatedAt)) return false;
    return a.title == b.title &&
        a.notes == b.notes &&
        a.course == b.course &&
        a.priority == b.priority &&
        a.status == b.status &&
        a.groupId == b.groupId &&
        a.assigneeId == b.assigneeId &&
        a.assigneeName == b.assigneeName &&
        _sameTags(a.tags, b.tags) &&
        _sameDate(a.dueDate, b.dueDate) &&
        _sameDate(a.reminderAt, b.reminderAt) &&
        a.xpAwarded == b.xpAwarded;
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

  void dispose() {
    _disposed = true;
    _service?.snapshot.removeListener(_mirrorSnapshot);
    _service?.dispose();
    _syncState.dispose();
  }
}
