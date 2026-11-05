import '../../../home/models/task.dart';

enum ProjectStatus { active, completed, archived }

extension ProjectStatusLabel on ProjectStatus {
  String get label => switch (this) {
    ProjectStatus.active => 'Active',
    ProjectStatus.completed => 'Completed',
    ProjectStatus.archived => 'Archived',
  };

  static ProjectStatus fromName(Object? value) {
    return ProjectStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ProjectStatus.active,
    );
  }
}

/// A course or personal project derived from task organisation.
///
/// Tasks remain the source of truth. A project stores only the lightweight
/// metadata that cannot be inferred from a task, such as a description or an
/// explicit deadline.
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    this.deadline,
    this.status = ProjectStatus.active,
    this.tasks = const <Task>[],
  });

  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deadline;
  final ProjectStatus status;
  final List<Task> tasks;

  int get totalTasks => tasks.length;

  int get completedTasks => tasks.where((task) => task.isCompleted).length;

  int get remainingTasks => totalTasks - completedTasks;

  int get overdueTasks => tasks.where((task) => task.isOverdue).length;

  double get progress {
    if (totalTasks == 0) {
      return status == ProjectStatus.completed ? 1 : 0;
    }
    return completedTasks / totalTasks;
  }

  bool get isComplete =>
      status == ProjectStatus.completed ||
      (totalTasks > 0 && completedTasks == totalTasks);

  ProjectStatus get effectiveStatus {
    if (status == ProjectStatus.archived) return ProjectStatus.archived;
    if (isComplete) return ProjectStatus.completed;
    return ProjectStatus.active;
  }

  DateTime? get nextDeadline {
    final pending =
        tasks
            .where((task) => !task.isCompleted && task.dueDate != null)
            .map((task) => task.dueDate!)
            .toList(growable: false)
          ..sort();
    if (pending.isNotEmpty) return pending.first;
    return deadline;
  }

  bool get isAtRisk {
    final next = nextDeadline;
    return next != null &&
        !isComplete &&
        effectiveStatus != ProjectStatus.archived &&
        next.isBefore(DateTime.now());
  }

  Project copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deadline = _unset,
    ProjectStatus? status,
    List<Task>? tasks,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deadline: identical(deadline, _unset)
          ? this.deadline
          : deadline as DateTime?,
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'deadline': deadline?.toUtc().toIso8601String(),
      'status': status.name,
    };
  }

  static Project? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.map<String, dynamic>(
      (key, value) => MapEntry('$key', value),
    );
    final id = map['id'];
    final name = map['name'];
    final createdAt = DateTime.tryParse('${map['createdAt'] ?? ''}');
    final updatedAt = DateTime.tryParse('${map['updatedAt'] ?? ''}');
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;
    if (createdAt == null || updatedAt == null) return null;

    return Project(
      id: id,
      name: name.trim(),
      description: map['description'] is String
          ? map['description'] as String
          : '',
      createdAt: createdAt.toLocal(),
      updatedAt: updatedAt.toLocal(),
      deadline: DateTime.tryParse('${map['deadline'] ?? ''}')?.toLocal(),
      status: ProjectStatusLabel.fromName(map['status']),
    );
  }

  static String idFor(String name) {
    final slug = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return 'project-${slug.isEmpty ? 'untitled' : slug}';
  }

  static const Object _unset = Object();
}

/// Fields edited by the project dialog.
class ProjectDraft {
  const ProjectDraft({
    required this.name,
    this.description = '',
    this.deadline,
  });

  final String name;
  final String description;
  final DateTime? deadline;

  ProjectDraft copyWith({
    String? name,
    String? description,
    Object? deadline = Project._unset,
  }) {
    return ProjectDraft(
      name: name ?? this.name,
      description: description ?? this.description,
      deadline: identical(deadline, Project._unset)
          ? this.deadline
          : deadline as DateTime?,
    );
  }
}
