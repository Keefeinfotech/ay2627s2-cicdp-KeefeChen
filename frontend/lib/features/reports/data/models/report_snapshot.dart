import '../../../home/models/task.dart';

/// Selectable reporting window.
enum ReportPeriod { week, month, all }

extension ReportPeriodLabel on ReportPeriod {
  String get label => switch (this) {
    ReportPeriod.week => 'Last 7 days',
    ReportPeriod.month => 'Last 30 days',
    ReportPeriod.all => 'All time',
  };

  String get shortLabel => switch (this) {
    ReportPeriod.week => 'Week',
    ReportPeriod.month => 'Month',
    ReportPeriod.all => 'All time',
  };

  int? get days => switch (this) {
    ReportPeriod.week => 7,
    ReportPeriod.month => 30,
    ReportPeriod.all => null,
  };
}

/// One bar in the activity chart.
class ReportSeriesPoint {
  const ReportSeriesPoint({
    required this.start,
    required this.label,
    required this.completed,
    required this.created,
  });

  final DateTime start;
  final String label;
  final int completed;
  final int created;

  int get total => completed + created;
}

/// Completion split for one priority.
class ReportPrioritySlice {
  const ReportPrioritySlice({
    required this.priority,
    required this.total,
    required this.completed,
  });

  final TaskPriority priority;
  final int total;
  final int completed;

  int get pending => total - completed;

  double get rate => total == 0 ? 0 : completed / total;
}

/// Task rollup for one course or project.
class ReportProjectSlice {
  const ReportProjectSlice({
    required this.name,
    required this.total,
    required this.completed,
    required this.overdue,
  });

  final String name;
  final int total;
  final int completed;
  final int overdue;

  int get pending => total - completed;

  double get rate => total == 0 ? 0 : completed / total;
}

/// Immutable report payload rendered by [ReportsPage].
class ReportSnapshot {
  const ReportSnapshot({
    required this.period,
    required this.generatedAt,
    required this.totalTasks,
    required this.completedTasks,
    required this.pendingTasks,
    required this.overdueTasks,
    required this.dueToday,
    required this.completedInPeriod,
    required this.createdInPeriod,
    required this.currentStreak,
    required this.longestStreak,
    required this.focusDays,
    required this.series,
    required this.priorities,
    required this.projects,
  });

  final ReportPeriod period;
  final DateTime generatedAt;
  final int totalTasks;
  final int completedTasks;
  final int pendingTasks;
  final int overdueTasks;
  final int dueToday;
  final int completedInPeriod;
  final int createdInPeriod;
  final int currentStreak;
  final int longestStreak;
  final int focusDays;
  final List<ReportSeriesPoint> series;
  final List<ReportPrioritySlice> priorities;
  final List<ReportProjectSlice> projects;

  bool get isEmpty => totalTasks == 0;

  double get completionRate =>
      totalTasks == 0 ? 0 : completedTasks / totalTasks;

  int get maxSeriesValue {
    var maximum = 0;
    for (final point in series) {
      if (point.completed > maximum) maximum = point.completed;
      if (point.created > maximum) maximum = point.created;
    }
    return maximum;
  }

  /// A short, deterministic observation for the insight panel.
  String get insight {
    if (totalTasks == 0) {
      return 'Complete a few tasks and your progress trends will appear here.';
    }
    if (overdueTasks > 0) {
      return 'You have $overdueTasks overdue '
          '${overdueTasks == 1 ? 'task' : 'tasks'}. Clear those first to '
          'protect your completion rate.';
    }
    if (completionRate >= 0.8) {
      return 'Strong momentum: ${(completionRate * 100).round()}% of the '
          'tasks in this view are complete.';
    }
    if (pendingTasks > completedTasks) {
      return 'There is more open work than finished work. Break the largest '
          'remaining task into smaller steps to keep moving.';
    }
    return 'Progress is steady. Keep completing one task at a time to '
        'maintain your current streak.';
  }
}
