import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/projects/data/models/project.dart';
import 'package:frontend/features/projects/data/repositories/project_repository.dart';

import '../../helpers.dart';

void main() {
  const repository = ProjectRepository();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('derives projects from task courses and rolls up progress', () async {
    final projects = await repository.load(
      ownerId: 'owner',
      tasks: <Task>[
        makeTask(id: '1', course: 'COMP 2101', title: 'Lab 1'),
        makeTask(
          id: '2',
          course: 'COMP 2101',
          title: 'Lab 2',
          status: TaskStatus.completed,
          completedAt: DateTime(2026, 1, 2),
        ),
        makeTask(id: '3', course: 'Maths', title: 'Problem set'),
        makeTask(id: '4'),
      ],
    );

    expect(projects.map((project) => project.name), <String>[
      'COMP 2101',
      'Maths',
    ]);

    final comp = projects.first;
    expect(comp.totalTasks, 2);
    expect(comp.completedTasks, 1);
    expect(comp.remainingTasks, 1);
    expect(comp.progress, 0.5);
    expect(comp.effectiveStatus, ProjectStatus.active);
  });

  test('persists metadata and merges it with task-derived projects', () async {
    await repository.save(
      ownerId: 'owner',
      projects: <Project>[
        Project(
          id: 'project-comp-2101',
          name: 'COMP 2101',
          description: 'Algorithms coursework',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 2),
          deadline: DateTime(2026, 5, 1),
        ),
      ],
    );

    final loaded = await repository.load(
      ownerId: 'owner',
      tasks: <Task>[makeTask(id: '1', course: 'COMP 2101')],
    );

    expect(loaded, hasLength(1));
    expect(loaded.single.description, 'Algorithms coursework');
    expect(loaded.single.deadline, DateTime(2026, 5, 1));
    expect(loaded.single.totalTasks, 1);
  });

  test('orders active projects before completed and archived ones', () async {
    final now = DateTime(2026, 1, 1);
    await repository.save(
      ownerId: 'owner',
      projects: <Project>[
        Project(
          id: 'archived',
          name: 'Archived',
          description: '',
          createdAt: now,
          updatedAt: now,
          status: ProjectStatus.archived,
        ),
        Project(
          id: 'completed',
          name: 'Completed',
          description: '',
          createdAt: now,
          updatedAt: now,
          status: ProjectStatus.completed,
        ),
        Project(
          id: 'active',
          name: 'Active',
          description: '',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    final loaded = await repository.load(
      ownerId: 'owner',
      tasks: const <Task>[],
    );

    expect(loaded.map((project) => project.name), <String>[
      'Active',
      'Completed',
      'Archived',
    ]);
  });

  test('tasks are sorted open first, then by due date and title', () async {
    final projects = await repository.load(
      ownerId: 'owner',
      tasks: <Task>[
        makeTask(
          id: 'done',
          course: 'COMP 2101',
          title: 'Done',
          status: TaskStatus.completed,
          dueDate: DateTime(2026, 1, 1),
        ),
        makeTask(
          id: 'later',
          course: 'COMP 2101',
          title: 'Later',
          dueDate: DateTime(2026, 3, 1),
        ),
        makeTask(
          id: 'sooner',
          course: 'COMP 2101',
          title: 'Sooner',
          dueDate: DateTime(2026, 2, 1),
        ),
      ],
    );

    expect(projects.single.tasks.map((task) => task.id), <String>[
      'sooner',
      'later',
      'done',
    ]);
  });

  test('ignores stored data with an unexpected shape', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auxilia.projects.v1.owner': '{"not":"a list"}',
    });

    final loaded = await repository.load(
      ownerId: 'owner',
      tasks: const <Task>[],
    );

    expect(loaded, isEmpty);
  });

  test('reports corrupt stored JSON as a storage failure', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auxilia.projects.v1.owner': 'not-json',
    });

    await expectLater(
      repository.load(ownerId: 'owner', tasks: const <Task>[]),
      throwsA(isA<ProjectStorageException>()),
    );
  });

  test('clear removes stored metadata', () async {
    await repository.save(
      ownerId: 'owner',
      projects: <Project>[
        Project(
          id: 'p',
          name: 'P',
          description: '',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    await repository.clear('owner');

    final loaded = await repository.load(
      ownerId: 'owner',
      tasks: const <Task>[],
    );
    expect(loaded, isEmpty);
  });

  test('project model exposes risk, deadlines and slug identifiers', () {
    final overdue = Project(
      id: Project.idFor('  COMP 2101! '),
      name: 'COMP 2101',
      description: '',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      tasks: <Task>[
        makeTask(id: '1', course: 'COMP 2101', dueDate: DateTime(2020, 1, 1)),
      ],
    );

    expect(overdue.id, 'project-comp-2101');
    expect(overdue.nextDeadline, DateTime(2020, 1, 1));
    expect(overdue.isAtRisk, isTrue);
    expect(overdue.overdueTasks, 1);
    expect(Project.idFor('!!!').endsWith('untitled'), isTrue);

    final complete = overdue.copyWith(
      tasks: <Task>[
        makeTask(id: '1', course: 'COMP 2101', status: TaskStatus.completed),
      ],
    );
    expect(complete.isComplete, isTrue);
    expect(complete.effectiveStatus, ProjectStatus.completed);
    expect(complete.progress, 1);
  });
}
