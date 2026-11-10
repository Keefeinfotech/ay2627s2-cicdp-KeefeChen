import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_app_bar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_status_badge.dart';
import 'package:frontend/features/home/data/api_task_repository.dart';
import '../../../home/data/task_store.dart';
import '../../../home/models/task.dart';
import '../../../home/widgets/task_editor.dart';
import '../../data/models/project.dart';
import '../controllers/project_controller.dart';
import '../widgets/project_editor_dialog.dart';

enum _TaskView { all, open, done }

/// Workspace for a single project: progress, task rollup and project actions.
class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({
    super.key,
    required this.projectId,
    required this.ownerId,
    this.store,
    this.controller,
  });

  final String projectId;
  final String ownerId;
  final TaskStore? store;
  final ProjectController? controller;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  late final TaskStore _store;
  late final ProjectController _controller;
  late final bool _ownsStore;
  late final bool _ownsController;
  _TaskView _view = _TaskView.all;

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.store == null;
    _store =
        widget.store ??
        TaskStore(repository: ApiTaskRepository(), ownerId: widget.ownerId);
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        ProjectController(store: _store, ownerId: widget.ownerId);
    if (_ownsStore) _store.load();
    if (_ownsController) _controller.load();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    if (_ownsStore) _store.dispose();
    super.dispose();
  }

  Project? get _project => _controller.byId(widget.projectId);

  void _snack(
    String message, {
    AppSnackType type = AppSnackType.info,
    SnackBarAction? action,
  }) {
    AppSnackBar.show(context, message, type: type, action: action);
  }

  List<Task> _visibleTasks(Project project) {
    final tasks = project.tasks
        .where((task) {
          return switch (_view) {
            _TaskView.all => true,
            _TaskView.open => !task.isCompleted,
            _TaskView.done => task.isCompleted,
          };
        })
        .toList(growable: false);

    final sorted = List<Task>.of(tasks);
    sorted.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      final aDue = a.dueDate;
      final bDue = b.dueDate;
      if (aDue != null && bDue != null && !aDue.isAtSameMomentAs(bDue)) {
        return aDue.compareTo(bDue);
      }
      if (aDue != null && bDue == null) return -1;
      if (aDue == null && bDue != null) return 1;
      return b.priority.index.compareTo(a.priority.index);
    });
    return sorted;
  }

  Future<void> _createTask() async {
    final project = _project;
    if (project == null) return;
    final draft = await showModalBottomSheet<TaskDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          TaskEditor(initialCourse: project.name, existingTags: _store.allTags),
    );
    if (draft == null || !mounted) return;
    final saved = await _store.addTask(
      TaskDraft(
        title: draft.title,
        notes: draft.notes,
        course: project.name,
        tags: draft.tags,
        groupId: draft.groupId,
        assigneeId: draft.assigneeId,
        assigneeName: draft.assigneeName,
        priority: draft.priority,
        dueDate: draft.dueDate,
        reminderAt: draft.reminderAt,
      ),
    );
    if (!mounted) return;
    _snack(
      saved ? 'Task added to ${project.name}.' : _store.error ?? 'Add failed.',
      type: saved ? AppSnackType.success : AppSnackType.error,
    );
  }

  Future<void> _editTask(Task task) async {
    final draft = await showModalBottomSheet<TaskDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaskEditor(initial: task, existingTags: _store.allTags),
    );
    if (draft == null || !mounted) return;
    final saved = await _store.updateTask(task.id, draft);
    if (!mounted) return;
    _snack(
      saved ? 'Task updated.' : _store.error ?? 'Update failed.',
      type: saved ? AppSnackType.success : AppSnackType.error,
    );
  }

  Future<void> _toggleTask(Task task) async {
    final wasCompleted = task.isCompleted;
    final saved = await _store.toggleCompletion(task.id);
    if (!mounted) return;
    _snack(
      saved
          ? wasCompleted
                ? 'Task reopened.'
                : 'Task completed.'
          : _store.error ?? 'Could not update the task.',
      type: saved ? AppSnackType.success : AppSnackType.error,
    );
  }

  Future<bool> _deleteTask(Task task) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete task?',
      message: '“${task.title}” will be removed from this project.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return false;

    final saved = await _store.deleteTask(task.id);
    if (!mounted) return false;
    if (!saved) {
      _snack(
        _store.error ?? 'Could not delete the task.',
        type: AppSnackType.error,
      );
      return false;
    }
    _snack(
      'Task deleted.',
      type: AppSnackType.success,
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          final restored = await _store.restoreTask(task);
          if (!mounted) return;
          _snack(
            restored ? 'Task restored.' : 'Could not restore the task.',
            type: restored ? AppSnackType.success : AppSnackType.error,
          );
        },
      ),
    );
    return true;
  }

  Future<void> _editProject(Project project) async {
    final draft = await showProjectEditorDialog(context, initial: project);
    if (draft == null || !mounted) return;
    final saved = await _controller.updateProject(project.id, draft);
    if (!mounted) return;
    _snack(
      saved ? 'Project updated.' : _controller.error ?? 'Update failed.',
      type: saved ? AppSnackType.success : AppSnackType.error,
    );
  }

  Future<void> _toggleArchive(Project project) async {
    final archived = project.effectiveStatus == ProjectStatus.archived;
    final saved = await _controller.setArchived(project.id, !archived);
    if (!mounted) return;
    _snack(
      saved
          ? archived
                ? 'Project restored.'
                : 'Project archived.'
          : _controller.error ?? 'Could not update the project.',
      type: saved ? AppSnackType.success : AppSnackType.error,
    );
  }

  Future<void> _deleteProject(Project project) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete project?',
      message:
          '“${project.name}” will be removed. Its tasks stay in Tasks but are '
          'no longer grouped under this project.',
      confirmLabel: 'Delete project',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;
    final saved = await _controller.deleteProject(project.id);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
      return;
    }
    _snack(_controller.error ?? 'Delete failed.', type: AppSnackType.error);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final project = _project;
        if (project == null) {
          return _missingProject(context);
        }
        return Scaffold(
          appBar: AuxiliaAppBar(
            title: project.name,
            subtitle: 'Project workspace',
            actions: <Widget>[
              IconButton(
                tooltip: 'Edit project',
                onPressed: () => _editProject(project),
                icon: const Icon(Icons.edit_outlined),
              ),
              PopupMenuButton<String>(
                tooltip: 'Project actions for ${project.name}',
                onSelected: (value) {
                  switch (value) {
                    case 'archive':
                      _toggleArchive(project);
                    case 'delete':
                      _deleteProject(project);
                  }
                },
                itemBuilder: (context) {
                  final archived =
                      project.effectiveStatus == ProjectStatus.archived;
                  return <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'archive',
                      child: ListTile(
                        leading: Icon(
                          archived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                        ),
                        title: Text(
                          archived ? 'Restore project' : 'Archive project',
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('Delete project'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSizes.maxContentWidth,
                ),
                child: RefreshIndicator(
                  onRefresh: _controller.retry,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    children: <Widget>[
                      if (project.effectiveStatus == ProjectStatus.archived)
                        _archivedBanner(context, project),
                      if (_controller.error != null) ...[
                        AppErrorBanner(
                          message: _controller.error!,
                          onRetry: _controller.retry,
                          onDismiss: _controller.clearError,
                        ),
                      ],
                      _summaryCard(context, project),
                      const SizedBox(height: AppSpacing.xl),
                      _taskHeader(context, project),
                      const SizedBox(height: AppSpacing.md),
                      if (_controller.isLoading && project.totalTasks == 0)
                        const TaskListSkeleton(itemCount: 4)
                      else
                        _taskSection(context, project),
                    ],
                  ),
                ),
              ),
            ),
          ),
          floatingActionButton:
              project.effectiveStatus == ProjectStatus.archived
              ? null
              : FloatingActionButton.extended(
                  heroTag: 'project-detail-add-task-fab',
                  onPressed: _createTask,
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('Add task'),
                ),
        );
      },
    );
  }

  Widget _missingProject(BuildContext context) {
    return Scaffold(
      appBar: AuxiliaAppBar(
        title: 'Project',
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: AppErrorState(
            title: 'Project not found',
            message:
                'This project may have been deleted. Return to Projects to '
                'see what is still available.',
            onRetry: _controller.retry,
            retryLabel: 'Reload projects',
          ),
        ),
      ),
    );
  }

  Widget _archivedBanner(BuildContext context, Project project) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.archive_outlined, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'This project is archived. Restore it to keep tracking progress.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _toggleArchive(project),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context, Project project) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusColor = switch (project.effectiveStatus) {
      ProjectStatus.active => AppColors.trustBlue,
      ProjectStatus.completed => AppColors.successGreen,
      ProjectStatus.archived => scheme.onSurfaceVariant,
    };
    final deadline = project.deadline ?? project.nextDeadline;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  project.effectiveStatus == ProjectStatus.completed
                      ? Icons.check_circle_outline_rounded
                      : project.effectiveStatus == ProjectStatus.archived
                      ? Icons.archive_outlined
                      : Icons.workspaces_outline,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${(project.progress * 100).round()}% complete',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${project.completedTasks} of ${project.totalTasks} '
                      '${project.totalTasks == 1 ? 'task' : 'tasks'} done',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: project.effectiveStatus.label,
                color: statusColor,
                icon: project.effectiveStatus == ProjectStatus.completed
                    ? Icons.check_circle_outline_rounded
                    : project.effectiveStatus == ProjectStatus.archived
                    ? Icons.archive_outlined
                    : Icons.bolt_outlined,
              ),
            ],
          ),
          if (project.description.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              project.description.trim(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          CompletionBar(
            value: project.progress,
            color: statusColor,
            height: 8,
            label:
                '${(project.progress * 100).round()} percent of '
                '${project.name} complete',
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              _ProjectDetailStat(
                icon: Icons.task_alt_rounded,
                label: 'Done',
                value: '${project.completedTasks}',
              ),
              _ProjectDetailStat(
                icon: Icons.pending_actions_outlined,
                label: 'Remaining',
                value: '${project.remainingTasks}',
              ),
              _ProjectDetailStat(
                icon: Icons.warning_amber_rounded,
                label: 'Overdue',
                value: '${project.overdueTasks}',
                color: project.overdueTasks > 0 ? scheme.error : null,
              ),
              _ProjectDetailStat(
                icon: Icons.event_outlined,
                label: deadline == null ? 'Deadline' : 'Next deadline',
                value: deadline == null ? 'None' : formatDateOnly(deadline),
                color: project.isAtRisk ? scheme.error : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _taskHeader(BuildContext context, Project project) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Tasks',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Work is linked by the project name “${project.name}”.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (project.effectiveStatus != ProjectStatus.archived)
              AppButton(
                label: 'Add task',
                icon: Icons.add_rounded,
                size: AppButtonSize.medium,
                onPressed: _createTask,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _TaskViewChip(
              label: 'All (${project.totalTasks})',
              selected: _view == _TaskView.all,
              onTap: () => setState(() => _view = _TaskView.all),
            ),
            _TaskViewChip(
              label: 'To do (${project.remainingTasks})',
              selected: _view == _TaskView.open,
              onTap: () => setState(() => _view = _TaskView.open),
            ),
            _TaskViewChip(
              label: 'Done (${project.completedTasks})',
              selected: _view == _TaskView.done,
              onTap: () => setState(() => _view = _TaskView.done),
            ),
          ],
        ),
      ],
    );
  }

  Widget _taskSection(BuildContext context, Project project) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tasks = _visibleTasks(project);

    if (project.tasks.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: AppEmptyState(
          icon: Icons.task_alt_rounded,
          title: 'No tasks in this project',
          message:
              'Add the first task to start tracking this project’s progress.',
          action: project.effectiveStatus == ProjectStatus.archived
              ? null
              : AppButton(
                  label: 'Add the first task',
                  icon: Icons.add_rounded,
                  onPressed: _createTask,
                ),
        ),
      );
    }

    if (tasks.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: AppEmptyState(
          compact: true,
          icon: Icons.filter_alt_off_outlined,
          title: 'Nothing in this view',
          message: _view == _TaskView.open
              ? 'Everything in this project is complete.'
              : 'No tasks have been completed yet.',
          action: AppButton(
            label: 'Show all tasks',
            icon: Icons.filter_alt_off_rounded,
            variant: AppButtonVariant.outline,
            onPressed: () => setState(() => _view = _TaskView.all),
          ),
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          for (var index = 0; index < tasks.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            Dismissible(
              key: ValueKey<String>('project-task-${tasks[index].id}'),
              background: _SwipeBackground(
                color: tasks[index].isCompleted
                    ? AppColors.warningAmber
                    : AppColors.successGreen,
                icon: tasks[index].isCompleted
                    ? Icons.undo_rounded
                    : Icons.check_rounded,
                label: tasks[index].isCompleted ? 'Reopen' : 'Complete',
                alignment: Alignment.centerLeft,
              ),
              secondaryBackground: _SwipeBackground(
                color: scheme.error,
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                alignment: Alignment.centerRight,
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  await _toggleTask(tasks[index]);
                } else {
                  await _deleteTask(tasks[index]);
                }
                return false;
              },
              child: _ProjectTaskRow(
                task: tasks[index],
                onToggle: () => _toggleTask(tasks[index]),
                onEdit: () => _editTask(tasks[index]),
                onDelete: () => _deleteTask(tasks[index]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectTaskRow extends StatelessWidget {
  const _ProjectTaskRow({
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bool completed = task.isCompleted;
    final Color priorityColor = switch (task.priority) {
      TaskPriority.low => AppColors.trustBlue,
      TaskPriority.medium => AppColors.warningAmber,
      TaskPriority.high => AppColors.errorRed,
    };

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Semantics(
                label: completed
                    ? 'Mark ${task.title} as pending'
                    : 'Mark ${task.title} as complete',
                toggled: completed,
                child: Checkbox(value: completed, onChanged: (_) => onToggle()),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: completed ? TextDecoration.lineThrough : null,
                      color: completed ? scheme.onSurfaceVariant : null,
                    ),
                  ),
                  if (task.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      task.notes.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      PriorityBadge(
                        label: '${task.priority.label} priority',
                        color: priorityColor,
                      ),
                      StatusBadge(
                        label: task.isCompleted
                            ? 'Completed'
                            : task.isOverdue
                            ? 'Overdue'
                            : task.dueDate == null
                            ? 'No due date'
                            : 'Due ${formatTaskDate(task.dueDate!)}',
                        color: task.isCompleted
                            ? AppColors.successGreen
                            : task.isOverdue
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                        icon: task.isCompleted
                            ? Icons.check_circle_outline_rounded
                            : Icons.schedule_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Task actions for ${task.title}',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (context) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit task'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded),
                    title: Text('Delete task'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectDetailStat extends StatelessWidget {
  const _ProjectDetailStat({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: AppSizes.iconSm,
              color: color ?? scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TaskViewChip extends StatelessWidget {
  const _TaskViewChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: scheme.primary,
      backgroundColor: scheme.surface,
      side: BorderSide(color: selected ? scheme.primary : scheme.outline),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white, size: AppSizes.iconMd),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
