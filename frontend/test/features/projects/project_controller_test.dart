import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';
import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/projects/data/models/project.dart';
import 'package:frontend/features/projects/data/repositories/project_repository.dart';
import 'package:frontend/features/projects/presentation/controllers/project_controller.dart';

import '../../helpers.dart';

class _FailingProjectRepository extends ProjectRepository {
  const _FailingProjectRepository({this.loadError, this.saveError});

  final Object? loadError;
  final Object? saveError;

  @override
  Future<List<Project>> load({
    required String ownerId,
    required List<Task> tasks,
  }) {
    if (loadError != null) throw loadError!;
    return super.load(ownerId: ownerId, tasks: tasks);
  }

  @override
  Future<void> save({
    required String ownerId,
    required List<Project> projects,
  }) async {
    if (saveError != null) throw saveError!;
    return super.save(ownerId: ownerId, projects: projects);
  }
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loads, filters and searches projects', () async {
    final store = await _store(<Task>[
      makeTask(
        id: '1',
        course: 'COMP 2101',
        status: TaskStatus.completed,
        completedAt: DateTime(2026, 1, 1),
      ),
      makeTask(
        id: '2',
        course: 'COMP 2101',
        status: TaskStatus.completed,
        completedAt: DateTime(2026, 1, 2),
      ),
      makeTask(id: '3', course: 'Maths'),
    ]);
    final controller = ProjectController(store: store, ownerId: 'owner');

    await controller.load();

    expect(controller.hasLoaded, isTrue);
    expect(controller.projects, hasLength(2));
    expect(controller.activeCount, 1);
    expect(controller.completedCount, 1);
    expect(controller.archivedCount, 0);
    expect(controller.totalTasks, 3);
    expect(controller.completedTasks, 2);
    expect(controller.overallProgress, closeTo(2 / 3, 0.0001));
    expect(controller.byId('project-comp-2101')?.name, 'COMP 2101');
    expect(controller.byId('missing'), isNull);

    controller.setFilter(ProjectFilter.completed);
    expect(controller.filteredProjects.single.name, 'COMP 2101');

    controller.setFilter(ProjectFilter.active);
    expect(controller.filteredProjects.single.name, 'Maths');

    controller.setFilter(ProjectFilter.all);
    controller.setQuery('math');
    expect(controller.filteredProjects.single.name, 'Maths');

    controller.setQuery('algorithms');
    expect(controller.filteredProjects, isEmpty);

    controller.setFilter(ProjectFilter.archived);
    expect(controller.filteredProjects, isEmpty);
    expect(controller.activeProjects, hasLength(1));
  });

  test('creates a project and rejects empty or duplicate names', () async {
    final store = await _store(<Task>[makeTask(course: 'Maths')]);
    final controller = ProjectController(store: store, ownerId: 'owner');
    await controller.load();

    expect(
      await controller.createProject(const ProjectDraft(name: '   ')),
      isFalse,
    );
    expect(controller.error, 'Give the project a name.');

    expect(
      await controller.createProject(const ProjectDraft(name: 'Maths')),
      isFalse,
    );
    expect(controller.error, 'A project with that name already exists.');

    expect(
      await controller.createProject(
        const ProjectDraft(name: 'Algorithms', description: '  Graphs  '),
      ),
      isTrue,
    );
    expect(controller.error, isNull);
    expect(controller.byId('project-algorithms')?.description, 'Graphs');
  });

  test('renames a project and moves its tasks with it', () async {
    final store = await _store(<Task>[
      makeTask(id: '1', course: 'Old name', title: 'Task'),
    ]);
    final controller = ProjectController(store: store, ownerId: 'owner');
    await controller.load();

    expect(
      await controller.updateProject(
        'project-old-name',
        const ProjectDraft(name: 'New name'),
      ),
      isTrue,
    );
    expect(controller.byId('project-old-name')?.name, 'New name');
    expect(store.tasks.single.course, 'New name');
  });

  test('rejects invalid project updates', () async {
    final store = await _store(<Task>[makeTask(course: 'Maths')]);
    final controller = ProjectController(store: store, ownerId: 'owner');
    await controller.load();

    expect(
      await controller.updateProject(
        'missing',
        const ProjectDraft(name: 'Anything'),
      ),
      isFalse,
    );
    expect(controller.error, 'That project no longer exists.');

    expect(
      await controller.updateProject(
        'project-maths',
        const ProjectDraft(name: '  '),
      ),
      isFalse,
    );
    expect(controller.error, 'Give the project a name.');

    expect(
      await controller.updateProject(
        'project-maths',
        const ProjectDraft(name: 'Maths'),
      ),
      isTrue,
    );
  });

  test('archives, restores and deletes projects', () async {
    final store = await _store(<Task>[
      makeTask(id: '1', course: 'Maths', title: 'Task'),
    ]);
    final controller = ProjectController(store: store, ownerId: 'owner');
    await controller.load();

    expect(await controller.setArchived('project-maths', true), isTrue);
    expect(
      controller.byId('project-maths')?.effectiveStatus,
      ProjectStatus.archived,
    );
    expect(await controller.setArchived('project-maths', false), isTrue);
    expect(
      controller.byId('project-maths')?.effectiveStatus,
      ProjectStatus.active,
    );
    expect(await controller.setArchived('missing', true), isFalse);

    expect(await controller.deleteProject('project-maths'), isTrue);
    expect(controller.byId('project-maths'), isNull);
    expect(store.tasks.single.course, '');
    expect(await controller.deleteProject('missing'), isFalse);
  });

  test('surfaces storage read failures with a readable message', () async {
    final store = await _store(const <Task>[]);
    final controller = ProjectController(
      store: store,
      ownerId: 'owner',
      repository: _FailingProjectRepository(
        loadError: ProjectStorageException('Could not read projects.'),
      ),
    );

    await controller.load();

    expect(controller.hasLoaded, isTrue);
    expect(controller.error, 'Could not read projects.');
    controller.clearError();
    expect(controller.error, isNull);
  });

  test('surfaces unexpected read failures and save failures', () async {
    final store = await _store(const <Task>[]);
    final failingRead = ProjectController(
      store: store,
      ownerId: 'owner',
      repository: const _FailingProjectRepository(
        loadError: FormatException('boom'),
      ),
    );
    await failingRead.load();
    expect(failingRead.error, 'Projects could not be loaded from this device.');

    final failingSave = ProjectController(
      store: store,
      ownerId: 'owner',
      repository: _FailingProjectRepository(
        saveError: ProjectStorageException('Disk full'),
      ),
    );
    await failingSave.load();
    expect(
      await failingSave.createProject(const ProjectDraft(name: 'New')),
      isFalse,
    );
    expect(failingSave.error, 'Disk full');

    final unexpectedSave = ProjectController(
      store: store,
      ownerId: 'owner',
      repository: _FailingProjectRepository(saveError: StateError('x')),
    );
    expect(
      await unexpectedSave.createProject(const ProjectDraft(name: 'Other')),
      isFalse,
    );
    expect(unexpectedSave.error, 'Project changes could not be saved.');
  });

  test('reacts to task changes and stops after disposal', () async {
    final store = await _store(const <Task>[]);
    final controller = ProjectController(store: store, ownerId: 'owner');
    await controller.load();
    expect(controller.projects, isEmpty);

    await store.addTask(const TaskDraft(title: 'Read', course: 'Physics'));
    await Future<void>.delayed(Duration.zero);

    expect(controller.projects.single.name, 'Physics');

    controller.dispose();
    await store.addTask(const TaskDraft(title: 'Write', course: 'Chemistry'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.projects.single.name, 'Physics');
    store.dispose();
  });
}
