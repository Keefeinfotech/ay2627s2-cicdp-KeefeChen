/// One AI-suggested subtask in a breakdown plan.
class SubtaskSuggestion {
  const SubtaskSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.effortMinutes,
    required this.milestone,
    required this.order,
    this.dependsOn = const <String>[],
    this.selected = true,
  });

  final String id;
  final String title;
  final String description;
  final int effortMinutes;
  final String milestone;
  final int order;
  final List<String> dependsOn;
  final bool selected;

  String get effortLabel {
    if (effortMinutes < 60) return '$effortMinutes min';
    final hours = effortMinutes / 60;
    return hours == hours.roundToDouble()
        ? '${hours.round()} hr'
        : '${hours.toStringAsFixed(1)} hr';
  }

  SubtaskSuggestion copyWith({bool? selected}) {
    return SubtaskSuggestion(
      id: id,
      title: title,
      description: description,
      effortMinutes: effortMinutes,
      milestone: milestone,
      order: order,
      dependsOn: dependsOn,
      selected: selected ?? this.selected,
    );
  }
}

/// A complete plan produced for a task or project.
class TaskBreakdownPlan {
  const TaskBreakdownPlan({
    required this.sourceTitle,
    required this.summary,
    required this.milestones,
    required this.subtasks,
  });

  final String sourceTitle;
  final String summary;
  final List<String> milestones;
  final List<SubtaskSuggestion> subtasks;

  int get selectedCount => subtasks.where((task) => task.selected).length;

  int get selectedEffortMinutes => subtasks
      .where((task) => task.selected)
      .fold(0, (total, task) => total + task.effortMinutes);

  String get selectedEffortLabel {
    final minutes = selectedEffortMinutes;
    if (minutes < 60) return '$minutes min';
    final hours = minutes / 60;
    return hours == hours.roundToDouble()
        ? '${hours.round()} hr'
        : '${hours.toStringAsFixed(1)} hr';
  }

  TaskBreakdownPlan copyWith({List<SubtaskSuggestion>? subtasks}) {
    return TaskBreakdownPlan(
      sourceTitle: sourceTitle,
      summary: summary,
      milestones: milestones,
      subtasks: subtasks ?? this.subtasks,
    );
  }
}
