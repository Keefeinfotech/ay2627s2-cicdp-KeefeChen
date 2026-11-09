import 'package:flutter/foundation.dart';

import '../../sync/models/sync_conflict.dart';
import '../../sync/models/sync_operation.dart';
import '../../sync/models/sync_snapshot.dart';
import '../models/task.dart';
import 'gamification.dart';
import 'task_repository.dart';
import 'task_validation.dart';

enum TaskFilter { all, pending, overdue, completed }

enum SyncStatus {
  localOnly,
  synced,
  pendingSync,
  syncing,
  offline,
  syncFailed,
  conflict,
}

class TaskStore extends ChangeNotifier {
  TaskStore({
    required this.repository,
    required this.ownerId,
    this.pageSize = 20,
  }) : assert(pageSize > 0) {
    final candidate = repository;
    if (candidate is SyncAwareTaskRepository) {
      _syncAware = candidate;
      _syncAware!.syncState.addListener(_onSyncChanged);
      _applySnapshot(_syncAware!.syncState.value);
    }
  }

  final TaskRepository repository;
  final String ownerId;
  final int pageSize;

  SyncAwareTaskRepository? _syncAware;

  List<Task> _tasks = <Task>[];
  List<Task>? _filteredTasksCache;

  bool _loading = false;
  bool _hasLoaded = false;

  SyncStatus _syncStatus = SyncStatus.synced;
  String? _error;

  TaskFilter _filter = TaskFilter.all;
  String? _tagFilter;
  String _query = '';
  int _page = 0;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  SyncStatus get syncStatus => _syncStatus;

  SyncSnapshot? get syncSnapshot => _syncAware?.syncState.value;

  List<SyncConflict> get syncConflicts =>
      _syncAware?.conflicts ?? const <SyncConflict>[];

  List<SyncOperation> get pendingOperations =>
      _syncAware?.operations ?? const <SyncOperation>[];

  bool get isSyncAware => _syncAware != null;

  bool get isLoading => _loading;

  bool get hasLoaded => _hasLoaded;

  SyncStatus? get syncStatusOpt =>
      _syncStatus == SyncStatus.synced || _syncStatus == SyncStatus.localOnly
      ? null
      : _syncStatus;

  /// Replays the offline queue. A no-op for local-only repositories.
  Future<void> retrySync() async {
    await _syncAware?.retrySync();
  }

  /// Resolves a queued conflict and refreshes the local list afterwards.
  Future<bool> resolveSyncConflict(
    SyncConflict conflict,
    ConflictResolution resolution,
  ) async {
    final syncAware = _syncAware;
    if (syncAware == null) return false;

    final result = await syncAware.resolveConflict(conflict, resolution);
    if (!result.success) {
      _error = result.error;
      notifyListeners();
      return false;
    }

    await load();
    return true;
  }

  /// Discards a queued change after the user reviews its failure.
  Future<void> discardPendingOperation(String operationId) async {
    await _syncAware?.discardOperation(operationId);
    await load();
  }

  String? get error => _error;

  TaskFilter get filter => _filter;

  String? get tagFilter => _tagFilter;

  String get query => _query;

  int get page => _page;

  List<Task> get tasks => List<Task>.unmodifiable(_tasks);

  int get pendingCount =>
      _tasks.where((task) => task.status == TaskStatus.pending).length;

  int get completedCount => _tasks.length - pendingCount;

  int get overdueCount => _tasks.where((task) => task.isOverdue).length;

  /// Every tag in use, ordered by frequency and then alphabetically. The
  /// result is stable so filter chips do not jump between rebuilds.
  List<String> get allTags {
    final counts = <String, int>{};
    final labels = <String, String>{};
    for (final task in _tasks) {
      for (final tag in task.tags) {
        final key = tag.toLowerCase();
        counts[key] = (counts[key] ?? 0) + 1;
        labels.putIfAbsent(key, () => tag);
      }
    }
    final keys = counts.keys.toList(growable: false)
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    return keys.map((key) => labels[key]!).toList(growable: false);
  }

  /// Open tasks with a reminder, earliest first.
  List<Task> get upcomingReminders {
    final reminders = _tasks
        .where((task) => !task.isCompleted && task.reminderAt != null)
        .toList(growable: false);
    reminders.sort((a, b) => a.reminderAt!.compareTo(b.reminderAt!));
    return reminders;
  }

  /// Reminders that are due at [now] and have not been completed.
  List<Task> dueReminders({DateTime? now}) {
    final reference = now ?? DateTime.now();
    return _tasks
        .where((task) => task.isReminderDue(reference))
        .toList(growable: false);
  }

  int get dueTodayCount => _tasks.where(_isDueToday).length;

  int get completedThisWeek => _tasks.where((task) {
    final completedAt = task.completedAt;

    if (!task.isCompleted || completedAt == null) {
      return false;
    }

    final now = DateTime.now();

    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    return !completedAt.isBefore(startOfWeek);
  }).length;

  int get totalXp => Gamification.totalXp(_tasks);

  LevelProgress get levelProgress => Gamification.progressFor(_tasks);

  List<Achievement> get achievements => Gamification.achievementsFor(_tasks);

  // ---------------------------------------------------------------------------
  // Filtering and Pagination
  // ---------------------------------------------------------------------------

  List<Task> get filteredTasks {
    if (_filteredTasksCache != null) {
      return _filteredTasksCache!;
    }

    final normalizedQuery = _query.trim().toLowerCase();

    final filtered = _tasks
        .where((task) {
          switch (_filter) {
            case TaskFilter.pending:
              if (task.isCompleted) return false;

            case TaskFilter.overdue:
              if (task.isCompleted || !task.isOverdue) {
                return false;
              }

            case TaskFilter.completed:
              if (!task.isCompleted) return false;

            case TaskFilter.all:
              break;
          }

          final tagFilter = _tagFilter;
          if (tagFilter != null &&
              !task.tags.any(
                (tag) => tag.toLowerCase() == tagFilter.toLowerCase(),
              )) {
            return false;
          }

          if (normalizedQuery.isEmpty) return true;

          return task.title.toLowerCase().contains(normalizedQuery) ||
              task.notes.toLowerCase().contains(normalizedQuery) ||
              task.course.toLowerCase().contains(normalizedQuery) ||
              task.tags.any(
                (tag) => tag.toLowerCase().contains(normalizedQuery),
              ) ||
              (task.assigneeName?.toLowerCase().contains(normalizedQuery) ??
                  false);
        })
        .toList(growable: false);

    filtered.sort(_compare);

    _filteredTasksCache = filtered;
    return filtered;
  }

  List<Task> get visibleTasks {
    final filtered = filteredTasks;

    final start = (_page * pageSize).clamp(0, filtered.length);
    final end = (start + pageSize).clamp(0, filtered.length);

    return filtered.sublist(start, end);
  }

  int get filteredCount => filteredTasks.length;

  int get pageCount {
    final count = filteredTasks.length;

    if (count == 0) return 1;

    return ((count - 1) ~/ pageSize) + 1;
  }

  bool get canGoToPreviousPage => _page > 0;

  bool get canGoToNextPage => _page + 1 < pageCount;

  void setFilter(TaskFilter filter) {
    if (_filter == filter) return;

    _filter = filter;
    _invalidateCache();
    _page = 0;

    notifyListeners();
  }

  void setQuery(String query) {
    if (_query == query) return;

    _query = query;
    _invalidateCache();
    _page = 0;

    notifyListeners();
  }

  /// Applies a tag filter. Passing null clears it.
  void setTagFilter(String? tag) {
    final normalized = tag?.trim();
    if (_tagFilter == normalized) return;

    _tagFilter = normalized == null || normalized.isEmpty ? null : normalized;
    _invalidateCache();
    _page = 0;

    notifyListeners();
  }

  /// Clears every list filter and the search query in one step.
  void clearFilters() {
    if (_filter == TaskFilter.all && _tagFilter == null && _query.isEmpty) {
      return;
    }
    _filter = TaskFilter.all;
    _tagFilter = null;
    _query = '';
    _invalidateCache();
    _page = 0;
    notifyListeners();
  }

  void nextPage() {
    if (!canGoToNextPage) return;

    _page++;

    notifyListeners();
  }

  void previousPage() {
    if (!canGoToPreviousPage) return;

    _page--;

    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;

    _error = null;

    notifyListeners();
  }

  void setSyncStatus(SyncStatus status) {
    if (_syncStatus == status) return;

    _syncStatus = status;

    notifyListeners();
  }

  void _onSyncChanged() {
    final snapshot = _syncAware?.syncState.value;
    if (snapshot == null) return;
    _applySnapshot(snapshot);
    notifyListeners();
  }

  void _applySnapshot(SyncSnapshot snapshot) {
    _syncStatus = switch (snapshot.phase) {
      SyncPhase.localOnly => SyncStatus.localOnly,
      SyncPhase.synced => SyncStatus.synced,
      SyncPhase.pending => SyncStatus.pendingSync,
      SyncPhase.syncing => SyncStatus.syncing,
      SyncPhase.offline => SyncStatus.offline,
      SyncPhase.failed => SyncStatus.syncFailed,
      SyncPhase.conflict => SyncStatus.conflict,
    };
  }

  @override
  void dispose() {
    _syncAware?.syncState.removeListener(_onSyncChanged);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Load Tasks
  // ---------------------------------------------------------------------------

  Future<void> load() async {
    if (_loading) return;

    _loading = true;
    _error = null;

    Future<void>.microtask(notifyListeners);

    try {
      final loaded = await repository.load(ownerId);

      _tasks = loaded;
      _hasLoaded = true;
      _invalidateCache();
      _clampPage();
    } on TaskStorageException catch (err) {
      _error =
          '${err.message}. Existing tasks may not be available until storage is readable.';
    } catch (_) {
      _error = 'Could not load your tasks from this device.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> retry() async {
    await load();

    return _error == null;
  }

  // ---------------------------------------------------------------------------
  // Add Task
  // ---------------------------------------------------------------------------

  Future<bool> addTask(TaskDraft draft) async {
    final String? validationError = validateDraft(draft);

    if (validationError != null) {
      _error = validationError;
      notifyListeners();

      return false;
    }

    final task = Task.create(
      title: draft.title,
      notes: draft.notes,
      course: draft.course,
      tags: draft.tags,
      groupId: draft.groupId,
      assigneeId: draft.assigneeId,
      assigneeName: draft.assigneeName,
      priority: draft.priority,
      dueDate: draft.dueDate,
      reminderAt: draft.reminderAt,
    );

    return _commit(<Task>[..._tasks, task]);
  }

  // ---------------------------------------------------------------------------
  // Update Task
  // ---------------------------------------------------------------------------

  Future<bool> updateTask(String id, TaskDraft draft) async {
    final String? validationError = validateDraft(draft);

    if (validationError != null) {
      _error = validationError;
      notifyListeners();

      return false;
    }

    final index = _tasks.indexWhere((task) => task.id == id);

    if (index < 0) {
      _error = 'That task no longer exists.';
      notifyListeners();

      return false;
    }

    final updated = _tasks[index].copyWith(
      title: draft.title.trim(),
      notes: draft.notes.trim(),
      course: draft.course.trim(),
      tags: draft.tags,
      groupId: draft.groupId,
      assigneeId: draft.assigneeId,
      assigneeName: draft.assigneeName,
      priority: draft.priority,
      dueDate: draft.dueDate,
      reminderAt: draft.reminderAt,
      updatedAt: DateTime.now(),
    );

    final next = List<Task>.of(_tasks);

    next[index] = updated;

    return _commit(next);
  }

  // ---------------------------------------------------------------------------
  // Toggle Task Completion
  // ---------------------------------------------------------------------------

  Future<bool> toggleCompletion(String id) async {
    final index = _tasks.indexWhere((task) => task.id == id);

    if (index < 0) return false;

    final task = _tasks[index];
    final now = DateTime.now();

    final updated = task.isCompleted
        ? task.copyWith(
            status: TaskStatus.pending,
            completedAt: null,
            updatedAt: now,
          )
        : task.copyWith(
            status: TaskStatus.completed,
            completedAt: now,
            xpAwarded: true,
            updatedAt: now,
          );

    final next = List<Task>.of(_tasks);

    next[index] = updated;

    return _commit(next);
  }

  // ---------------------------------------------------------------------------
  // Reminders
  // ---------------------------------------------------------------------------

  /// Moves a reminder forward so it appears again later without changing the
  /// due date.
  Future<bool> snoozeReminder(
    String id, {
    Duration delay = const Duration(minutes: 10),
  }) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index < 0) return false;

    final next = List<Task>.of(_tasks);
    next[index] = _tasks[index].copyWith(
      reminderAt: DateTime.now().add(delay),
      updatedAt: DateTime.now(),
    );
    return _commit(next);
  }

  /// Removes a reminder while keeping the task itself intact.
  Future<bool> clearReminder(String id) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index < 0) return false;

    final next = List<Task>.of(_tasks);
    next[index] = _tasks[index].copyWith(
      reminderAt: null,
      updatedAt: DateTime.now(),
    );
    return _commit(next);
  }

  // ---------------------------------------------------------------------------
  // Assignment
  // ---------------------------------------------------------------------------

  /// Assigns or unassigns a task. Passing null for [assigneeId] clears the
  /// assignment; [groupId] identifies the workspace the assignee belongs to.
  Future<bool> assignTask(
    String id, {
    required String? groupId,
    required String? assigneeId,
    String? assigneeName,
  }) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index < 0) return false;

    final next = List<Task>.of(_tasks);
    next[index] = _tasks[index].copyWith(
      groupId: groupId,
      assigneeId: assigneeId,
      assigneeName: assigneeId == null ? null : assigneeName,
      updatedAt: DateTime.now(),
    );
    return _commit(next);
  }

  // ---------------------------------------------------------------------------
  // Delete Task
  // ---------------------------------------------------------------------------

  Future<bool> deleteTask(String id) async {
    final next = _tasks.where((task) => task.id != id).toList(growable: false);

    if (next.length == _tasks.length) return false;

    return _commit(next);
  }

  // ---------------------------------------------------------------------------
  // Restore Task
  // ---------------------------------------------------------------------------

  Future<bool> restoreTask(Task task) async {
    if (_tasks.any((existing) => existing.id == task.id)) {
      return false;
    }

    return _commit(<Task>[..._tasks, task]);
  }

  // ---------------------------------------------------------------------------
  // Clear Tasks
  // ---------------------------------------------------------------------------

  Future<bool> clearAll() async {
    try {
      await repository.clear(ownerId);
    } catch (_) {
      _error = 'Could not remove local task data. Please try again.';
      _syncStatus = SyncStatus.syncFailed;

      notifyListeners();

      return false;
    }

    _tasks = <Task>[];
    _invalidateCache();

    _error = null;
    _page = 0;

    _syncStatus = SyncStatus.pendingSync;

    notifyListeners();

    return true;
  }

  // ---------------------------------------------------------------------------
  // Commit Local Changes
  // ---------------------------------------------------------------------------

  Future<bool> _commit(List<Task> next) async {
    try {
      await repository.save(ownerId, next);
    } on TaskStorageException catch (err) {
      _error = '${err.message}. Your previous task state was kept.';

      _syncStatus = SyncStatus.syncFailed;

      notifyListeners();

      return false;
    } catch (_) {
      _error =
          'Could not save your changes. Your previous task state was kept.';

      _syncStatus = SyncStatus.syncFailed;

      notifyListeners();

      return false;
    }

    _tasks = next;
    _invalidateCache();

    _error = null;

    _clampPage();

    _syncStatus = SyncStatus.pendingSync;

    notifyListeners();

    return true;
  }

  // ---------------------------------------------------------------------------
  // Helper Methods
  // ---------------------------------------------------------------------------

  void _invalidateCache() {
    _filteredTasksCache = null;
  }

  void _clampPage() {
    final lastPage = pageCount - 1;

    if (_page > lastPage) {
      _page = lastPage;
    }

    if (_page < 0) {
      _page = 0;
    }
  }

  bool _isDueToday(Task task) {
    final dueDate = task.dueDate;

    if (task.isCompleted || dueDate == null) {
      return false;
    }

    final now = DateTime.now();

    return dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }

  int _compare(Task a, Task b) {
    if (a.isCompleted != b.isCompleted) {
      return a.isCompleted ? 1 : -1;
    }

    final aDue = a.dueDate;
    final bDue = b.dueDate;

    if (aDue != null && bDue != null && !aDue.isAtSameMomentAs(bDue)) {
      return aDue.compareTo(bDue);
    }

    if (aDue != null && bDue == null) return -1;

    if (aDue == null && bDue != null) return 1;

    final priority = b.priority.index.compareTo(a.priority.index);

    if (priority != 0) return priority;

    return b.createdAt.compareTo(a.createdAt);
  }
}
