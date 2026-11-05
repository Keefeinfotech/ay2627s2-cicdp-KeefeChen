import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';

import '../helpers.dart';

TaskStore buildStore(InMemoryTaskRepository repository, {int pageSize = 20}) {
  return TaskStore(
    repository: repository,
    ownerId: 'owner',
    pageSize: pageSize,
  );
}

void main() {
  group('loading', () {
    test('loads persisted tasks', () async {
      final repository = InMemoryTaskRepository(
        seed: <String, List<Task>>{
          'owner': <Task>[makeTask(title: 'Existing')],
        },
      );
      final store = buildStore(repository);

      await store.load();

      expect(store.hasLoaded, isTrue);
      expect(store.isLoading, isFalse);
      expect(store.tasks.single.title, 'Existing');
    });

    test('reports a readable error when storage cannot be read', () async {
      final repository = InMemoryTaskRepository()..failOnLoad = true;
      final store = buildStore(repository);

      await store.load();

      expect(store.error, contains('Simulated read failure'));
      expect(store.tasks, isEmpty);
    });
  });

  group('writes', () {
    test('adds and persists a task', () async {
      final repository = InMemoryTaskRepository();
      final store = buildStore(repository);
      await store.load();

      final saved = await store.addTask(const TaskDraft(title: '  New task  '));

      expect(saved, isTrue);
      expect(store.tasks.single.title, 'New task');
      expect(repository.saveCount, 1);
    });

    test('rejects a blank title without writing', () async {
      final repository = InMemoryTaskRepository();
      final store = buildStore(repository);
      await store.load();

      final saved = await store.addTask(const TaskDraft(title: '   '));

      expect(saved, isFalse);
      expect(store.error, 'Enter a task title');
      expect(repository.saveCount, 0);
      expect(store.tasks, isEmpty);
    });

    test('updates a task and preserves earned XP', () async {
      final repository = InMemoryTaskRepository();
      final store = buildStore(repository);
      await store.load();

      await store.addTask(
        const TaskDraft(title: 'Original', priority: TaskPriority.high),
      );
      final original = store.tasks.single;
      await store.toggleCompletion(original.id);

      final saved = await store.updateTask(
        original.id,
        const TaskDraft(title: 'Renamed', priority: TaskPriority.high),
      );

      expect(saved, isTrue);
      expect(store.tasks.single.title, 'Renamed');
      expect(store.tasks.single.isCompleted, isTrue);
      expect(store.totalXp, 30);
    });

    test('keeps the previous state when a write fails', () async {
      final repository = InMemoryTaskRepository();
      final store = buildStore(repository);
      await store.load();
      await store.addTask(const TaskDraft(title: 'Kept'));

      repository.failOnSave = true;
      final saved = await store.addTask(const TaskDraft(title: 'Lost'));

      expect(saved, isFalse);
      expect(store.tasks, hasLength(1));
      expect(store.tasks.single.title, 'Kept');
      expect(store.error, contains('previous task state was kept'));
    });
  });

  group('completion and XP', () {
    test('does not award XP twice for repeated completion', () async {
      final repository = InMemoryTaskRepository();
      final store = buildStore(repository);
      await store.load();
      await store.addTask(
        const TaskDraft(title: 'High', priority: TaskPriority.high),
      );
      final id = store.tasks.single.id;

      await store.toggleCompletion(id);
      expect(store.tasks.single.isCompleted, isTrue);
      expect(store.totalXp, 30);

      await store.toggleCompletion(id);
      expect(store.tasks.single.isCompleted, isFalse);
      expect(store.totalXp, 30);

      await store.toggleCompletion(id);
      expect(store.tasks.single.isCompleted, isTrue);
      expect(store.totalXp, 30);
    });

    test('derives level and achievements from persisted state', () async {
      final repository = InMemoryTaskRepository();
      final store = buildStore(repository);
      await store.load();

      for (var i = 0; i < 5; i++) {
        await store.addTask(
          const TaskDraft(title: 'Task', priority: TaskPriority.high),
        );
        await store.toggleCompletion(store.tasks.last.id);
      }

      expect(store.totalXp, 150);
      expect(store.levelProgress.level, 2);
      expect(
        store.achievements
            .firstWhere((achievement) => achievement.id == 'five_done')
            .unlocked,
        isTrue,
      );
    });
  });

  group('filtering and pagination', () {
    test('paginates large lists instead of exposing everything', () async {
      final repository = InMemoryTaskRepository(
        seed: <String, List<Task>>{
          'owner': <Task>[
            for (var i = 0; i < 25; i++)
              makeTask(id: 'task-$i', title: 'Task $i'),
          ],
        },
      );
      final store = buildStore(repository, pageSize: 10);
      await store.load();

      expect(store.pageCount, 3);
      expect(store.visibleTasks, hasLength(10));
      expect(store.canGoToNextPage, isTrue);

      store.nextPage();
      expect(store.page, 1);
      expect(store.visibleTasks, hasLength(10));

      store.nextPage();
      expect(store.page, 2);
      expect(store.visibleTasks, hasLength(5));
      expect(store.canGoToNextPage, isFalse);
    });

    test('filters by status', () async {
      final repository = InMemoryTaskRepository(
        seed: <String, List<Task>>{
          'owner': <Task>[
            makeTask(id: '1'),
            makeTask(id: '2'),
            makeTask(id: '3', status: TaskStatus.completed),
          ],
        },
      );
      final store = buildStore(repository);
      await store.load();

      store.setFilter(TaskFilter.pending);
      expect(store.filteredCount, 2);

      store.setFilter(TaskFilter.completed);
      expect(store.filteredCount, 1);
    });

    test('searches titles, notes and courses', () async {
      final repository = InMemoryTaskRepository(
        seed: <String, List<Task>>{
          'owner': <Task>[
            makeTask(id: '1', title: 'Buy milk'),
            makeTask(id: '2', title: 'Write report', notes: 'milk budget'),
            makeTask(id: '3', title: 'Call mum', course: 'COMP 2101'),
          ],
        },
      );
      final store = buildStore(repository);
      await store.load();

      store.setQuery('MILK');
      expect(store.filteredCount, 2);

      store.setQuery('comp 2101');
      expect(store.filteredCount, 1);
    });
  });

  group('deadline awareness', () {
    test('counts due today and overdue tasks separately', () async {
      final now = DateTime.now();
      final repository = InMemoryTaskRepository(
        seed: <String, List<Task>>{
          'owner': <Task>[
            makeTask(
              id: 'today',
              dueDate: DateTime(now.year, now.month, now.day, 23, 59),
            ),
            makeTask(
              id: 'overdue',
              dueDate: now.subtract(const Duration(days: 2)),
            ),
            makeTask(
              id: 'done',
              status: TaskStatus.completed,
              dueDate: now.subtract(const Duration(days: 1)),
            ),
            makeTask(id: 'later', dueDate: now.add(const Duration(days: 2))),
          ],
        },
      );
      final store = buildStore(repository);
      await store.load();

      expect(store.dueTodayCount, 1);
      expect(store.overdueCount, 1);
    });

    test('filters overdue tasks only', () async {
      final now = DateTime.now();
      final repository = InMemoryTaskRepository(
        seed: <String, List<Task>>{
          'owner': <Task>[
            makeTask(
              id: 'overdue',
              dueDate: now.subtract(const Duration(days: 1)),
            ),
            makeTask(id: 'later', dueDate: now.add(const Duration(days: 3))),
          ],
        },
      );
      final store = buildStore(repository);
      await store.load();

      store.setFilter(TaskFilter.overdue);
      expect(store.filteredCount, 1);
      expect(store.visibleTasks.single.id, 'overdue');
    });

    test('counts tasks completed this calendar week', () async {
      final now = DateTime.now();
      final repository = InMemoryTaskRepository(
        seed: <String, List<Task>>{
          'owner': <Task>[
            makeTask(
              id: 'recent',
              status: TaskStatus.completed,
              completedAt: now,
              xpAwarded: true,
            ),
            makeTask(
              id: 'old',
              status: TaskStatus.completed,
              completedAt: now.subtract(const Duration(days: 14)),
              xpAwarded: true,
            ),
          ],
        },
      );
      final store = buildStore(repository);
      await store.load();

      expect(store.completedThisWeek, 1);
    });
  });

  group('deletion', () {
    test('deletes a single task', () async {
      final repository = InMemoryTaskRepository(
        seed: <String, List<Task>>{
          'owner': <Task>[makeTask(id: '1')],
        },
      );
      final store = buildStore(repository);
      await store.load();

      expect(await store.deleteTask('1'), isTrue);
      expect(store.tasks, isEmpty);
      expect(await repository.load('owner'), isEmpty);
    });

    test('restores a deleted task without losing XP', () async {
      final repository = InMemoryTaskRepository(
        seed: <String, List<Task>>{
          'owner': <Task>[
            makeTask(
              id: '1',
              status: TaskStatus.completed,
              completedAt: DateTime(2026, 1, 2),
              xpAwarded: true,
            ),
          ],
        },
      );
      final store = buildStore(repository);
      await store.load();
      final task = store.tasks.single;
      expect(store.totalXp, 20);

      await store.deleteTask(task.id);
      expect(store.tasks, isEmpty);
      expect(store.totalXp, 0);

      expect(await store.restoreTask(task), isTrue);
      expect(store.tasks.single.id, task.id);
      expect(store.tasks.single.isCompleted, isTrue);
      expect(store.totalXp, 20);
    });

    test('does not duplicate a task on repeated restore', () async {
      final repository = InMemoryTaskRepository(
        seed: <String, List<Task>>{
          'owner': <Task>[makeTask(id: '1')],
        },
      );
      final store = buildStore(repository);
      await store.load();

      expect(await store.restoreTask(store.tasks.single), isFalse);
      expect(store.tasks, hasLength(1));
    });

    test('clears all local data for the owner', () async {
      final repository = InMemoryTaskRepository(
        seed: <String, List<Task>>{
          'owner': <Task>[makeTask(id: '1'), makeTask(id: '2')],
        },
      );
      final store = buildStore(repository);
      await store.load();

      expect(await store.clearAll(), isTrue);
      expect(store.tasks, isEmpty);
      expect(await repository.load('owner'), isEmpty);
    });

    test('reports a failed clear without pretending success', () async {
      final repository = InMemoryTaskRepository(
        seed: <String, List<Task>>{
          'owner': <Task>[makeTask(id: '1')],
        },
      )..failOnClear = true;
      final store = buildStore(repository);
      await store.load();

      expect(await store.clearAll(), isFalse);
      expect(store.tasks, hasLength(1));
      expect(store.error, isNotNull);
    });
  });

  group('tags and assignment', () {
    test('normalises and filters by tags', () async {
      final repository = InMemoryTaskRepository(
        seed: <String, List<Task>>{
          'owner': <Task>[
            makeTask(id: '1', tags: <String>['Maths', 'Urgent']),
            makeTask(id: '2', tags: <String>['maths']),
            makeTask(id: '3'),
          ],
        },
      );
      final store = buildStore(repository);
      await store.load();

      expect(store.allTags, <String>['Maths', 'Urgent']);
      expect(store.allTags.first, 'Maths');

      store.setTagFilter('MATHS');
      expect(store.filteredTasks.map((task) => task.id), <String>['1', '2']);

      store.clearFilters();
      expect(store.tagFilter, isNull);
      expect(store.filteredCount, 3);
    });

    test('searches tags and assignee names', () async {
      final repository = InMemoryTaskRepository(
        seed: <String, List<Task>>{
          'owner': <Task>[
            makeTask(
              id: '1',
              title: 'Slides',
              tags: <String>['Presentation'],
              assigneeName: 'Alex Chen',
            ),
            makeTask(id: '2', title: 'Notes'),
          ],
        },
      );
      final store = buildStore(repository);
      await store.load();

      store.setQuery('presentation');
      expect(store.filteredTasks.single.id, '1');

      store.setQuery('alex');
      expect(store.filteredTasks.single.id, '1');
    });

    test('assigns a task and clears the assignment', () async {
      final repository = InMemoryTaskRepository(
        seed: <String, List<Task>>{
          'owner': <Task>[makeTask(id: '1')],
        },
      );
      final store = buildStore(repository);
      await store.load();

      expect(
        await store.assignTask(
          '1',
          groupId: 'group-1',
          assigneeId: 'user-2',
          assigneeName: 'Alex Chen',
        ),
        isTrue,
      );
      expect(store.tasks.single.groupId, 'group-1');
      expect(store.tasks.single.assigneeId, 'user-2');
      expect(store.tasks.single.assigneeName, 'Alex Chen');

      expect(
        await store.assignTask('1', groupId: null, assigneeId: null),
        isTrue,
      );
      expect(store.tasks.single.isAssigned, isFalse);
      expect(store.tasks.single.assigneeName, isNull);
    });
  });

  group('reminders', () {
    test('lists open reminders in chronological order', () async {
      final repository = InMemoryTaskRepository(
        seed: <String, List<Task>>{
          'owner': <Task>[
            makeTask(id: 'late', reminderAt: DateTime(2026, 3, 1, 12)),
            makeTask(id: 'early', reminderAt: DateTime(2026, 2, 1, 12)),
            makeTask(
              id: 'done',
              status: TaskStatus.completed,
              reminderAt: DateTime(2026, 1, 1, 12),
            ),
            makeTask(id: 'none'),
          ],
        },
      );
      final store = buildStore(repository);
      await store.load();

      expect(store.upcomingReminders.map((task) => task.id), <String>[
        'early',
        'late',
      ]);
    });

    test('finds due reminders and snoozes them', () async {
      final repository = InMemoryTaskRepository(
        seed: <String, List<Task>>{
          'owner': <Task>[
            makeTask(id: '1', reminderAt: DateTime(2026, 1, 1, 9)),
          ],
        },
      );
      final store = buildStore(repository);
      await store.load();

      expect(store.dueReminders(now: DateTime(2026, 1, 1, 10)), hasLength(1));
      expect(store.dueReminders(now: DateTime(2026, 1, 1, 8)), isEmpty);

      expect(await store.snoozeReminder('1'), isTrue);
      expect(store.tasks.single.reminderAt!.isAfter(DateTime.now()), isTrue);

      expect(await store.clearReminder('1'), isTrue);
      expect(store.tasks.single.hasReminder, isFalse);
    });

    test('completed tasks never raise reminders', () {
      final task = makeTask(
        status: TaskStatus.completed,
        reminderAt: DateTime(2026, 1, 1),
      );

      expect(task.isReminderDue(DateTime(2026, 2, 1)), isFalse);
      expect(task.hasReminder, isTrue);
    });
  });
}
