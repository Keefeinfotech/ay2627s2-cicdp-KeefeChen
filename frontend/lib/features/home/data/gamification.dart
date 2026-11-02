import '../models/task.dart';

class LevelProgress {
  const LevelProgress({
    required this.level,
    required this.totalXp,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
  });

  final int level;
  final int totalXp;
  final int xpIntoLevel;
  final int xpForNextLevel;

  double get fraction {
    if (xpForNextLevel <= 0) return 1;
    return (xpIntoLevel / xpForNextLevel).clamp(0.0, 1.0);
  }
}

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.unlocked,
  });

  final String id;
  final String title;
  final String description;
  final bool unlocked;
}

class Gamification {
  const Gamification._();

  static const Map<TaskPriority, int> xpByPriority = {
    TaskPriority.low: 10,
    TaskPriority.medium: 20,
    TaskPriority.high: 30,
  };

  /// XP is derived from persisted task state, never from a separate counter, so
  /// repeated completion events cannot award it twice.
  static int xpForTask(Task task) {
    if (!task.xpAwarded) return 0;
    return xpByPriority[task.priority] ?? 0;
  }

  static int totalXp(Iterable<Task> tasks) =>
      tasks.fold(0, (total, task) => total + xpForTask(task));

  /// Level 1 starts at 0 XP; each level n requires 50 * (n - 1) * n XP.
  static int xpRequiredForLevel(int level) {
    if (level <= 1) return 0;
    return 50 * (level - 1) * level;
  }

  static int levelForXp(int xp) {
    if (xp < 0) return 1;
    var level = 1;
    while (xp >= xpRequiredForLevel(level + 1)) {
      level += 1;
    }
    return level;
  }

  static LevelProgress progressFor(Iterable<Task> tasks) {
    final xp = totalXp(tasks);
    final level = levelForXp(xp);
    final currentThreshold = xpRequiredForLevel(level);
    final nextThreshold = xpRequiredForLevel(level + 1);
    return LevelProgress(
      level: level,
      totalXp: xp,
      xpIntoLevel: xp - currentThreshold,
      xpForNextLevel: nextThreshold - currentThreshold,
    );
  }

  static List<Achievement> achievementsFor(Iterable<Task> tasks) {
    final all = tasks.toList(growable: false);
    final completed = all
        .where((task) => task.status == TaskStatus.completed)
        .toList();
    final completedHigh = completed
        .where((task) => task.priority == TaskPriority.high)
        .length;
    final level = levelForXp(totalXp(all));

    return [
      Achievement(
        id: 'first_step',
        title: 'First step',
        description: 'Complete your first task',
        unlocked: completed.isNotEmpty,
      ),
      Achievement(
        id: 'five_done',
        title: 'Getting things done',
        description: 'Complete five tasks',
        unlocked: completed.length >= 5,
      ),
      Achievement(
        id: 'twenty_five',
        title: 'Task master',
        description: 'Complete twenty-five tasks',
        unlocked: completed.length >= 25,
      ),
      Achievement(
        id: 'planner',
        title: 'Planner',
        description: 'Give a task a due date',
        unlocked: all.any((task) => task.dueDate != null),
      ),
      Achievement(
        id: 'high_five',
        title: 'Priority pro',
        description: 'Complete five high-priority tasks',
        unlocked: completedHigh >= 5,
      ),
      Achievement(
        id: 'level_three',
        title: 'Momentum',
        description: 'Reach level 3',
        unlocked: level >= 3,
      ),
    ];
  }
}
