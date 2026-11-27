import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';
import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/projects/data/models/project.dart';
import 'package:frontend/features/projects/data/repositories/project_repository.dart';
import 'package:frontend/features/projects/presentation/controllers/project_controller.dart';
import 'package:frontend/features/projects/presentation/pages/project_detail_page.dart';

import '../../../../helpers.dart';

class _FakeProjectRepo extends ProjectRepository {
  _FakeProjectRepo(this._projects);
  final List<Project> _projects;
  @override
  Future<List<Project>> load({
    required String ownerId,
    required List<Task> tasks,
  }) async => _projects;
  @override
  Future<void> save({
    required String ownerId,
    required List<Project> projects,
  }) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders project detail with tasks', (tester) async {
    final task = makeTask(
      id: 't1',
      title: 'Do work',
      course: 'Capstone',
      status: TaskStatus.pending,
    );
    final store = TaskStore(
      repository: InMemoryTaskRepository(
        seed: {
          'u': [task],
        },
      ),
      ownerId: 'u',
    );
    await store.load();
    final project = Project(
      id: 'p1',
      name: 'Capstone',
      description: 'Desc',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      tasks: [task],
    );
    final controller = ProjectController(
      store: store,
      ownerId: 'u',
      repository: _FakeProjectRepo([project]),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectDetailPage(
          projectId: 'p1',
          ownerId: 'u',
          store: store,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Capstone'), findsWidgets);
    expect(find.text('Do work'), findsWidgets);
  });

  testWidgets('shows not found when project missing', (tester) async {
    final store = TaskStore(
      repository: InMemoryTaskRepository(seed: {'u': <Task>[]}),
      ownerId: 'u',
    );
    await store.load();
    final controller = ProjectController(
      store: store,
      ownerId: 'u',
      repository: _FakeProjectRepo([]),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectDetailPage(
          projectId: 'missing',
          ownerId: 'u',
          store: store,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('not found'), findsWidgets);
  });
}
