import 'package:flutter/foundation.dart';

import '../../../home/data/task_store.dart';
import '../../../home/models/task.dart';
import '../../data/models/project.dart';
import '../../data/repositories/project_repository.dart';

enum ProjectFilter { all, active, completed, archived }

/// Owns project metadata, filters and the derived task rollups.
class ProjectController extends ChangeNotifier {
  ProjectController({
    required this.store,
    required this.ownerId,
    ProjectRepository? repository,
  }) : repository = repository ?? const ProjectRepository() {
    store.addListener(_storeChanged);
  }

  final TaskStore store;
  final String ownerId;
  final ProjectRepository repository;

  List<Project> _projects = <Project>[];
  ProjectFilter _filter = ProjectFilter.all;
  String _query = '';
  bool _loading = false;
  bool _hasLoaded = false;
  bool _saving = false;
  String? _error;

  List<Project> get projects => List<Project>.unmodifiable(_projects);
  ProjectFilter get filter => _filter;
  String get query => _query;
  bool get isLoading => _loading;
  bool get isSaving => _saving;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;

  int get activeCount => _projects
      .where((project) => project.effectiveStatus == ProjectStatus.active)
      .length;
  int get completedCount => _projects
      .where((project) => project.effectiveStatus == ProjectStatus.completed)
      .length;
  int get archivedCount => _projects
      .where((project) => project.effectiveStatus == ProjectStatus.archived)
      .length;
  int get totalTasks =>
      _projects.fold(0, (total, project) => total + project.totalTasks);
  int get completedTasks =>
      _projects.fold(0, (total, project) => total + project.completedTasks);

  double get overallProgress =>
      totalTasks == 0 ? 0 : completedTasks / totalTasks;

  List<Project> get filteredProjects {
    final normalized = _query.trim().toLowerCase();
    return _projects
        .where((project) {
          switch (_filter) {
            case ProjectFilter.all:
              if (project.effectiveStatus == ProjectStatus.archived) {
                return false;
              }
            case ProjectFilter.active:
              if (project.effectiveStatus != ProjectStatus.active) return false;
            case ProjectFilter.completed:
              if (project.effectiveStatus != ProjectStatus.completed) {
                return false;
              }
            case ProjectFilter.archived:
              if (project.effectiveStatus != ProjectStatus.archived) {
                return false;
              }
          }
          if (normalized.isEmpty) return true;
          return project.name.toLowerCase().contains(normalized) ||
              project.description.toLowerCase().contains(normalized);
        })
        .toList(growable: false);
  }

  List<Project> get activeProjects => _projects
      .where((project) => project.effectiveStatus == ProjectStatus.active)
      .toList(growable: false);

  Project? byId(String id) {
    for (final project in _projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  void setFilter(ProjectFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    notifyListeners();
  }

  void setQuery(String query) {
    if (_query == query) return;
    _query = query;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<void> load({bool silent = false}) async {
    if (_loading) return;
    _loading = !silent;
    if (!silent) notifyListeners();

    try {
      final loaded = await repository.load(
        ownerId: ownerId,
        tasks: store.tasks,
      );
      _projects = loaded;
      _hasLoaded = true;
      _error = null;
    } on ProjectStorageException catch (err) {
      _error = err.message;
      _hasLoaded = true;
    } catch (_) {
      _error = 'Projects could not be loaded from this device.';
      _hasLoaded = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> retry() => load();

  Future<bool> createProject(ProjectDraft draft) async {
    final name = draft.name.trim();
    if (name.isEmpty) {
      _error = 'Give the project a name.';
      notifyListeners();
      return false;
    }
    if (_projects.any(
      (project) => project.name.toLowerCase() == name.toLowerCase(),
    )) {
      _error = 'A project with that name already exists.';
      notifyListeners();
      return false;
    }

    final now = DateTime.now();
    final project = Project(
      id: Project.idFor(name),
      name: name,
      description: draft.description.trim(),
      createdAt: now,
      updatedAt: now,
      deadline: draft.deadline,
    );

    return _save(<Project>[..._projects, project]);
  }

  Future<bool> updateProject(String id, ProjectDraft draft) async {
    final index = _projects.indexWhere((project) => project.id == id);
    if (index < 0) {
      _error = 'That project no longer exists.';
      notifyListeners();
      return false;
    }

    final current = _projects[index];
    final name = draft.name.trim();
    if (name.isEmpty) {
      _error = 'Give the project a name.';
      notifyListeners();
      return false;
    }
    if (_projects.any(
      (project) =>
          project.id != id && project.name.toLowerCase() == name.toLowerCase(),
    )) {
      _error = 'A project with that name already exists.';
      notifyListeners();
      return false;
    }

    final next = List<Project>.of(_projects);
    next[index] = current.copyWith(
      name: name,
      description: draft.description.trim(),
      deadline: draft.deadline,
      updatedAt: DateTime.now(),
    );

    _saving = true;
    try {
      if (current.name != name) {
        final tasks = store.tasks
            .where((task) => task.course.trim() == current.name)
            .toList(growable: false);
        for (final task in tasks) {
          await store.updateTask(
            task.id,
            TaskDraft(
              title: task.title,
              notes: task.notes,
              course: name,
              priority: task.priority,
              dueDate: task.dueDate,
              reminderAt: task.reminderAt,
            ),
          );
        }
      }
      return await _save(next);
    } finally {
      _saving = false;
    }
  }

  Future<bool> setArchived(String id, bool archived) async {
    final index = _projects.indexWhere((project) => project.id == id);
    if (index < 0) return false;

    final next = List<Project>.of(_projects);
    next[index] = next[index].copyWith(
      status: archived ? ProjectStatus.archived : ProjectStatus.active,
      updatedAt: DateTime.now(),
    );
    return _save(next);
  }

  Future<bool> deleteProject(String id) async {
    final project = byId(id);
    if (project == null) return false;

    _saving = true;
    try {
      for (final task in project.tasks) {
        await store.updateTask(
          task.id,
          TaskDraft(
            title: task.title,
            notes: task.notes,
            course: '',
            priority: task.priority,
            dueDate: task.dueDate,
            reminderAt: task.reminderAt,
          ),
        );
      }
      final next = _projects
          .where((candidate) => candidate.id != id)
          .toList(growable: false);
      return await _save(next);
    } finally {
      _saving = false;
    }
  }

  Future<bool> _save(List<Project> next) async {
    _saving = true;
    try {
      await repository.save(ownerId: ownerId, projects: next);
    } on ProjectStorageException catch (err) {
      _error = err.message;
      _saving = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Project changes could not be saved.';
      _saving = false;
      notifyListeners();
      return false;
    }

    _projects = next;
    _error = null;
    _saving = false;
    notifyListeners();
    await load(silent: true);
    return true;
  }

  void _storeChanged() {
    if (_saving) return;
    load(silent: true);
  }

  @override
  void dispose() {
    store.removeListener(_storeChanged);
    super.dispose();
  }
}
