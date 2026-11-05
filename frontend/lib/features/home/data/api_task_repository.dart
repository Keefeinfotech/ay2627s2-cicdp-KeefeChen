
import 'package:shared_preferences/shared_preferences.dart';


import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../authentication/data/session_store.dart';
import '../models/task.dart';
import 'task_repository.dart';

/// Remote-first task repository that keeps a SharedPreferences cache for
/// offline use.
///
/// Behaviour:
///   * [load] always tries the backend first and refreshes the cache.
///   * When the network is unavailable, [load] returns the cached tasks.
///   * [save] reconciles the new task list against the last known remote
///     snapshot: creates, updates and deletes tasks as needed.
///   * When the network is unavailable, [save] writes only to the cache so
///     the UI can keep working; the next successful [load] reconciles.
class ApiTaskRepository implements TaskRepository {
  ApiTaskRepository({
    String? token,
    SessionStore? sessions,
    ApiClient? api,
    SharedPreferences? preferences,
  })  : _tokenValue = token,
        _sessions = token == null ? (sessions ?? SessionStore()) : null,
        _api = api ?? ApiClient(),
        _cache = SharedPreferencesTaskRepository(preferences: preferences);

  final String? _tokenValue;
  final SessionStore? _sessions;
  final ApiClient _api;
  final SharedPreferencesTaskRepository _cache;

  Future<String?> _token() async {
    if (_tokenValue != null && _tokenValue.isNotEmpty) return _tokenValue;
    if (_sessions == null) return null;
    final session = await _sessions.read();
    return session?.token;
  }

  @override
  Future<List<Task>> load(String ownerId) async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      return _cache.load(ownerId);
    }

    try {
      final remote = await _fetchAll(token);
      // Reconcile offline edits: tasks that exist only in the cache are
      // re-created on the server (updatedAt-wins for shared tasks).
      final cached = await _cache.load(ownerId);
      final remoteById = <String, Task>{for (final t in remote) t.id: t};
      final toCreate = <Task>[];
      final toUpdate = <Task>[];
      for (final task in cached) {
        final remoteTask = remoteById[task.id];
        if (remoteTask == null) {
          toCreate.add(task);
        } else if (task.updatedAt.isAfter(remoteTask.updatedAt)) {
          toUpdate.add(task);
        }
      }
      for (final created in toCreate) {
        try {
          await _api.postJson(
            ApiEndpoints.tasks,
            _toCreateJson(created),
            token: token,
          );
        } catch (_) {
          // Keep going; the task remains in the cache for the next attempt.
        }
      }
      for (final updated in toUpdate) {
        try {
          await _api.patchJson(
            ApiEndpoints.task(updated.id),
            _toUpdateJson(updated),
            token: token,
          );
        } catch (_) {
          // Keep going.
        }
      }
      final refreshed = await _fetchAll(token);
      await _cache.save(ownerId, refreshed);
      return refreshed;
    } on ApiException {
      return _cache.load(ownerId);
    } catch (_) {
      return _cache.load(ownerId);
    }
  }

  @override
  Future<void> save(String ownerId, List<Task> tasks) async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      await _cache.save(ownerId, tasks);
      return;
    }

    try {
      final remote = await _fetchAll(token);
      final remoteById = <String, Task>{for (final t in remote) t.id: t};
      final desiredIds = tasks.map((t) => t.id).toSet();

      // Deletes
      for (final remoteTask in remote) {
        if (!desiredIds.contains(remoteTask.id)) {
          try {
            await _api.deleteJson(
              ApiEndpoints.task(remoteTask.id),
              token: token,
            );
          } catch (_) {
            // Ignore; the task will be re-synced on the next load.
          }
        }
      }

      // Creates / updates
      for (final task in tasks) {
        final remoteTask = remoteById[task.id];
        if (remoteTask == null) {
          try {
            await _api.postJson(
              ApiEndpoints.tasks,
              _toCreateJson(task),
              token: token,
            );
          } catch (_) {
            // Ignore; cached below.
          }
        } else if (task.updatedAt.isAfter(remoteTask.updatedAt) ||
            task.title != remoteTask.title ||
            task.notes != remoteTask.notes ||
            task.course != remoteTask.course ||
            task.priority != remoteTask.priority ||
            task.status != remoteTask.status ||
            task.dueDate != remoteTask.dueDate ||
            task.reminderAt != remoteTask.reminderAt) {
          try {
            await _api.patchJson(
              ApiEndpoints.task(task.id),
              _toUpdateJson(task),
              token: token,
            );
          } catch (_) {
            // Ignore; cached below.
          }
        }
      }

      await _cache.save(ownerId, tasks);
    } on ApiException {
      await _cache.save(ownerId, tasks);
    } catch (_) {
      await _cache.save(ownerId, tasks);
    }
  }

  @override
  Future<void> clear(String ownerId) async {
    final token = await _token();
    if (token != null && token.isNotEmpty) {
      try {
        final remote = await _fetchAll(token);
        for (final task in remote) {
          try {
            await _api.deleteJson(
              ApiEndpoints.task(task.id),
              token: token,
            );
          } catch (_) {
            // Ignore.
          }
        }
      } catch (_) {
        // Fall through to cache clear.
      }
    }
    await _cache.clear(ownerId);
  }

  Future<List<Task>> _fetchAll(String token) async {
    final data = await _api.getJson(
      ApiEndpoints.tasks,
      token: token,
      query: const <String, String>{'page': '1', 'limit': '100'},
    );
    final raw = data['data'];
    if (raw is! List) return const <Task>[];
    return raw
        .map((item) => Task.tryFromBackend(item as Map<String, dynamic>))
        .whereType<Task>()
        .toList(growable: false);
  }

  Map<String, dynamic> _toCreateJson(Task task) => <String, dynamic>{
        'id': task.id,
        'title': task.title,
        'description': task.notes.isEmpty ? null : task.notes,
        'course': task.course,
        'reminderAt': task.reminderAt?.toUtc().toIso8601String(),
        'priority': _priorityName(task.priority),
        'dueDate': task.dueDate?.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _toUpdateJson(Task task) => <String, dynamic>{
        'title': task.title,
        'description': task.notes.isEmpty ? null : task.notes,
        'course': task.course,
        'reminderAt': task.reminderAt?.toUtc().toIso8601String(),
        'priority': _priorityName(task.priority),
        'status': task.isCompleted ? 'completed' : 'todo',
        'dueDate': task.dueDate?.toUtc().toIso8601String(),
      };

  String _priorityName(TaskPriority priority) => switch (priority) {
        TaskPriority.low => 'low',
        TaskPriority.medium => 'medium',
        TaskPriority.high => 'high',
      };
}
