import '../../../home/models/task.dart';
import '../../data/models/report_snapshot.dart';

/// Derives the reporting snapshot from the existing task store.
///
/// Reports intentionally own no persisted state: tasks remain the single source
/// of truth and every metric is recalculated when the user changes period or
/// completes a task.
class BuildReportSnapshot {
  const BuildReportSnapshot();

  ReportSnapshot call({
    required List<Task> tasks,
    required ReportPeriod period,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final today = _dateOnly(reference);
    final endExclusive = today.add(const Duration(days: 1));
    final windowDays = period.days;
    final start = windowDays == null
        ? null
        : _dateOnly(reference).subtract(Duration(days: windowDays - 1));

    bool inWindow(DateTime? date) {
      if (date == null) return false;
      if (start == null) return true;
      return !date.isBefore(start) && date.isBefore(endExclusive);
    }

    final scoped = tasks
        .where((task) {
          if (start == null) return true;
          return inWindow(task.createdAt) ||
              inWindow(task.completedAt) ||
              inWindow(task.dueDate);
        })
        .toList(growable: false);

    final completed = scoped.where((task) => task.isCompleted).length;
    final pendingTasks = scoped.where((task) => !task.isCompleted);
    final overdue = pendingTasks.where((task) {
      final due = task.dueDate;
      return due != null && due.isBefore(reference);
    }).length;
    final dueToday = pendingTasks.where((task) {
      final due = task.dueDate;
      return due != null && _isSameDay(due, reference);
    }).length;

    final completedInPeriod = tasks.where((task) {
      if (start == null) return task.isCompleted;
      return task.completedAt != null && inWindow(task.completedAt);
    }).length;
    final createdInPeriod = tasks.where((task) {
      if (start == null) return true;
      return inWindow(task.createdAt);
    }).length;

    final series = _buildSeries(tasks, period: period, now: reference);
    final priorities = _buildPriorities(scoped);
    final projects = _buildProjects(scoped);
    final streaks = _buildStreaks(tasks, now: reference);

    return ReportSnapshot(
      period: period,
      generatedAt: reference,
      totalTasks: scoped.length,
      completedTasks: completed,
      pendingTasks: pendingTasks.length,
      overdueTasks: overdue,
      dueToday: dueToday,
      completedInPeriod: completedInPeriod,
      createdInPeriod: createdInPeriod,
      currentStreak: streaks.current,
      longestStreak: streaks.longest,
      focusDays: series.fold<int>(
        0,
        (total, point) => total + (point.completed > 0 ? 1 : 0),
      ),
      series: series,
      priorities: priorities,
      projects: projects,
    );
  }

  List<ReportSeriesPoint> _buildSeries(
    List<Task> tasks, {
    required ReportPeriod period,
    required DateTime now,
  }) {
    final today = _dateOnly(now);
    final List<ReportSeriesPoint> points = <ReportSeriesPoint>[];

    if (period == ReportPeriod.all) {
      final currentWeek = today.subtract(Duration(days: today.weekday - 1));
      final firstWeek = currentWeek.subtract(const Duration(days: 77));
      for (var week = 0; week < 12; week++) {
        final start = firstWeek.add(Duration(days: week * 7));
        final end = start.add(const Duration(days: 7));
        points.add(
          ReportSeriesPoint(
            start: start,
            label: '${start.day}/${start.month}',
            completed: tasks.where((task) {
              final at = task.completedAt;
              return at != null && !at.isBefore(start) && at.isBefore(end);
            }).length,
            created: tasks.where((task) {
              final at = task.createdAt;
              return !at.isBefore(start) && at.isBefore(end);
            }).length,
          ),
        );
      }
      return points;
    }

    final days = period.days!;
    final first = today.subtract(Duration(days: days - 1));
    for (var index = 0; index < days; index++) {
      final start = first.add(Duration(days: index));
      final end = start.add(const Duration(days: 1));
      final label = period == ReportPeriod.week
          ? _weekdayLabel(start)
          : '${start.day}/${start.month}';
      points.add(
        ReportSeriesPoint(
          start: start,
          label: label,
          completed: tasks.where((task) {
            final at = task.completedAt;
            return at != null && !at.isBefore(start) && at.isBefore(end);
          }).length,
          created: tasks.where((task) {
            final at = task.createdAt;
            return !at.isBefore(start) && at.isBefore(end);
          }).length,
        ),
      );
    }
    return points;
  }

  List<ReportPrioritySlice> _buildPriorities(List<Task> tasks) {
    return TaskPriority.values.reversed
        .map((priority) {
          final scoped = tasks.where((task) => task.priority == priority);
          return ReportPrioritySlice(
            priority: priority,
            total: scoped.length,
            completed: scoped.where((task) => task.isCompleted).length,
          );
        })
        .where((slice) => slice.total > 0)
        .toList(growable: false);
  }

  List<ReportProjectSlice> _buildProjects(List<Task> tasks) {
    final Map<String, List<Task>> grouped = <String, List<Task>>{};
    for (final task in tasks) {
      final name = task.course.trim().isEmpty
          ? 'Unassigned'
          : task.course.trim();
      grouped.putIfAbsent(name, () => <Task>[]).add(task);
    }

    final slices = grouped.entries
        .map((entry) {
          final scoped = entry.value;
          return ReportProjectSlice(
            name: entry.key,
            total: scoped.length,
            completed: scoped.where((task) => task.isCompleted).length,
            overdue: scoped.where((task) => task.isOverdue).length,
          );
        })
        .toList(growable: false);

    slices.sort((a, b) {
      final byTotal = b.total.compareTo(a.total);
      if (byTotal != 0) return byTotal;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return slices;
  }

  _Streaks _buildStreaks(List<Task> tasks, {required DateTime now}) {
    final completedDays = tasks
        .where((task) => task.completedAt != null)
        .map((task) => _dateOnly(task.completedAt!))
        .toSet();
    if (completedDays.isEmpty) return const _Streaks(current: 0, longest: 0);

    final sorted = completedDays.toList()..sort();
    var longest = 1;
    var run = 1;
    for (var index = 1; index < sorted.length; index++) {
      final previous = sorted[index - 1];
      if (sorted[index].difference(previous).inDays == 1) {
        run += 1;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
    }

    var cursor = _dateOnly(now);
    if (!completedDays.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var current = 0;
    while (completedDays.contains(cursor)) {
      current += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return _Streaks(current: current, longest: longest);
  }

  DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final left = a.toLocal();
    final right = b.toLocal();
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _weekdayLabel(DateTime date) {
    const labels = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[date.weekday - 1];
  }
}

class _Streaks {
  const _Streaks({required this.current, required this.longest});

  final int current;
  final int longest;
}
