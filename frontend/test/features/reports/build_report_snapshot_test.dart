import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/reports/data/models/report_snapshot.dart';
import 'package:frontend/features/reports/domain/usecases/build_report_snapshot.dart';

Task _task({
  required String id,
  required String title,
  required DateTime createdAt,
  TaskPriority priority = TaskPriority.medium,
  TaskStatus status = TaskStatus.pending,
  String course = '',
  DateTime? dueDate,
  DateTime? completedAt,
}) {
  return Task(
    id: id,
    title: title,
    notes: '',
    course: course,
    priority: priority,
    status: status,
    dueDate: dueDate,
    createdAt: createdAt,
    updatedAt: createdAt,
    completedAt: completedAt,
    xpAwarded: status == TaskStatus.completed,
  );
}

void main() {
  const builder = BuildReportSnapshot();
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);

  DateTime daysAgo(int days, {int hour = 9}) {
    return today.subtract(Duration(days: days)).add(Duration(hours: hour));
  }

  final tasks = <Task>[
    _task(
      id: 'completed-recently',
      title: 'Write essay',
      createdAt: daysAgo(2),
      priority: TaskPriority.high,
      status: TaskStatus.completed,
      course: 'COMP 2101',
      dueDate: daysAgo(1, hour: 17),
      completedAt: daysAgo(1, hour: 18),
    ),
    _task(
      id: 'overdue',
      title: 'Submit lab',
      createdAt: daysAgo(2),
      priority: TaskPriority.low,
      course: 'COMP 2101',
      dueDate: daysAgo(1, hour: 17),
    ),
    _task(
      id: 'due-today',
      title: 'Read chapter',
      createdAt: daysAgo(0),
      priority: TaskPriority.medium,
      dueDate: DateTime(today.year, today.month, today.day, 23, 59),
    ),
    _task(
      id: 'historic',
      title: 'Old revision',
      createdAt: daysAgo(400),
      status: TaskStatus.completed,
      course: 'MATH 1001',
      completedAt: daysAgo(399),
    ),
  ];

  test('scopes metrics to the selected week', () {
    final snapshot = builder(tasks: tasks, period: ReportPeriod.week, now: now);

    expect(snapshot.period, ReportPeriod.week);
    expect(snapshot.totalTasks, 3);
    expect(snapshot.completedTasks, 1);
    expect(snapshot.pendingTasks, 2);
    expect(snapshot.overdueTasks, 1);
    expect(snapshot.dueToday, 1);
    expect(snapshot.completedInPeriod, 1);
    expect(snapshot.createdInPeriod, 3);
    expect(snapshot.completionRate, closeTo(1 / 3, 0.0001));
    expect(snapshot.series, hasLength(7));
    expect(snapshot.focusDays, 1);
    expect(snapshot.currentStreak, 1);
    expect(snapshot.longestStreak, 1);
  });

  test('builds priority and project breakdowns ordered by volume', () {
    final snapshot = builder(tasks: tasks, period: ReportPeriod.week, now: now);

    expect(snapshot.priorities.map((slice) => slice.priority), <TaskPriority>[
      TaskPriority.high,
      TaskPriority.medium,
      TaskPriority.low,
    ]);
    expect(snapshot.priorities.first.total, 1);
    expect(snapshot.priorities.first.completed, 1);
    expect(snapshot.priorities.first.rate, 1);
    expect(snapshot.priorities.last.pending, 1);

    expect(snapshot.projects, hasLength(2));
    final comp = snapshot.projects.first;
    expect(comp.name, 'COMP 2101');
    expect(comp.total, 2);
    expect(comp.completed, 1);
    expect(comp.pending, 1);
    expect(comp.overdue, 1);
    expect(snapshot.projects.last.name, 'Unassigned');
  });

  test('all-time scope includes historic tasks and weekly bars', () {
    final snapshot = builder(tasks: tasks, period: ReportPeriod.all, now: now);

    expect(snapshot.totalTasks, 4);
    expect(snapshot.completedTasks, 2);
    expect(snapshot.pendingTasks, 2);
    expect(snapshot.completedInPeriod, 2);
    expect(snapshot.createdInPeriod, 4);
    expect(snapshot.series, hasLength(12));
    expect(snapshot.projects, hasLength(3));
    expect(snapshot.maxSeriesValue, greaterThanOrEqualTo(1));
  });

  test('insights prioritise overdue work', () {
    final snapshot = builder(tasks: tasks, period: ReportPeriod.week, now: now);

    expect(snapshot.insight, contains('1 overdue task'));
  });

  test('insights describe momentum, open work and empty states', () {
    final strong = builder(
      tasks: <Task>[
        _task(
          id: 'one',
          title: 'One',
          createdAt: daysAgo(1),
          status: TaskStatus.completed,
          completedAt: daysAgo(0),
        ),
        _task(
          id: 'two',
          title: 'Two',
          createdAt: daysAgo(1),
          status: TaskStatus.completed,
          completedAt: daysAgo(0),
        ),
      ],
      period: ReportPeriod.week,
      now: now,
    );
    expect(strong.insight, contains('Strong momentum'));

    final open = builder(
      tasks: <Task>[
        _task(id: 'one', title: 'One', createdAt: daysAgo(1)),
        _task(id: 'two', title: 'Two', createdAt: daysAgo(1)),
        _task(
          id: 'three',
          title: 'Three',
          createdAt: daysAgo(1),
          status: TaskStatus.completed,
          completedAt: daysAgo(0),
        ),
      ],
      period: ReportPeriod.week,
      now: now,
    );
    expect(open.insight, contains('more open work than finished work'));

    final empty = builder(
      tasks: const <Task>[],
      period: ReportPeriod.month,
      now: now,
    );
    expect(empty.isEmpty, isTrue);
    expect(empty.completionRate, 0);
    expect(empty.insight, contains('Complete a few tasks'));
    expect(empty.series, hasLength(30));
  });
}
