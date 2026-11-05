import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../home/models/task.dart';
import '../models/project.dart';

class ProjectStorageException implements Exception {
  ProjectStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Persists project metadata locally while deriving task progress from the
/// existing offline-first task store.
class ProjectRepository {
  const ProjectRepository();

  static const String storagePrefix = 'auxilia.projects.v1';

  String keyFor(String ownerId) => '$storagePrefix.$ownerId';

  Future<List<Project>> load({
    required String ownerId,
    required List<Task> tasks,
  }) async {
    final Map<String, Project> byName = <String, Project>{};

    for (final stored in await _read(ownerId)) {
      byName[stored.name.toLowerCase()] = stored;
    }

    for (final task in tasks) {
      final name = task.course.trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (byName.containsKey(key)) continue;

      final timestamp = task.createdAt;
      byName[key] = Project(
        id: Project.idFor(name),
        name: name,
        description: '',
        createdAt: timestamp,
        updatedAt: timestamp,
      );
    }

    final projects = byName.values.map((project) {
      final projectTasks =
          tasks
              .where(
                (task) =>
                    task.course.trim().toLowerCase() ==
                    project.name.trim().toLowerCase(),
              )
              .toList()
            ..sort(_compareTasks);
      return project.copyWith(tasks: projectTasks);
    }).toList();

    projects.sort(_compareProjects);
    return projects;
  }

  Future<void> save({
    required String ownerId,
    required List<Project> projects,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(
        projects.map((project) => project.toJson()).toList(growable: false),
      );
      await prefs.setString(keyFor(ownerId), payload);
    } catch (_) {
      throw ProjectStorageException(
        'Could not save project details on this device.',
      );
    }
  }

  Future<void> clear(String ownerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyFor(ownerId));
  }

  Future<List<Project>> _read(String ownerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyFor(ownerId));
      if (raw == null || raw.isEmpty) return const <Project>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <Project>[];
      return decoded
          .map(Project.tryFromJson)
          .whereType<Project>()
          .toList(growable: false);
    } catch (_) {
      throw ProjectStorageException(
        'Could not read project details from this device.',
      );
    }
  }

  int _compareProjects(Project a, Project b) {
    final aArchived = a.effectiveStatus == ProjectStatus.archived;
    final bArchived = b.effectiveStatus == ProjectStatus.archived;
    if (aArchived != bArchived) return aArchived ? 1 : -1;

    final aComplete = a.effectiveStatus == ProjectStatus.completed;
    final bComplete = b.effectiveStatus == ProjectStatus.completed;
    if (aComplete != bComplete) return aComplete ? 1 : -1;

    final aDeadline = a.nextDeadline;
    final bDeadline = b.nextDeadline;
    if (aDeadline != null && bDeadline != null) {
      return aDeadline.compareTo(bDeadline);
    }
    if (aDeadline != null) return -1;
    if (bDeadline != null) return 1;

    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  int _compareTasks(Task a, Task b) {
    if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
    final aDue = a.dueDate;
    final bDue = b.dueDate;
    if (aDue != null && bDue != null) return aDue.compareTo(bDue);
    if (aDue != null) return -1;
    if (bDue != null) return 1;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }
}
