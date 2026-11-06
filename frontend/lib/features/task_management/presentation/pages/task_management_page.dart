import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_app_bar.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/app_text_field.dart';
import 'package:frontend/features/home/data/api_task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';
import 'package:frontend/features/home/data/task_validation.dart';
import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/home/widgets/task_editor.dart';
import 'package:frontend/features/task_management/data/models/task_breakdown.dart';
import 'package:frontend/features/task_management/data/repositories/task_management_repository.dart';
import 'package:frontend/features/task_management/presentation/widgets/quick_add_task_sheet.dart';
import 'package:frontend/features/task_management/presentation/widgets/task_breakdown_sheet.dart';

/// Full task-management surface with natural-language quick add, filtering,
/// swipe actions and AI-assisted breakdowns.
class TaskManagementPage extends StatefulWidget {
  const TaskManagementPage({super.key, required this.ownerId, this.store});

  final String ownerId;
  final TaskStore? store;

  @override
  State<TaskManagementPage> createState() => _TaskManagementPageState();
}

class _TaskManagementPageState extends State<TaskManagementPage> {
  final TextEditingController _search = TextEditingController();
  late final TaskStore _store;
  late final bool _ownsStore;
  late final TaskManagementRepository _repository;

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.store == null;
    _store =
        widget.store ??
        TaskStore(repository: ApiTaskRepository(), ownerId: widget.ownerId);
    _repository = TaskManagementRepository(_store);
    _store.addListener(_changed);
    if (!_store.hasLoaded && !_store.isLoading) _store.load();
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    if (_ownsStore) _store.dispose();
    _search.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _showSnack(
    String message, {
    AppSnackType type = AppSnackType.info,
    SnackBarAction? action,
  }) {
    AppSnackBar.show(context, message, type: type, action: action);
  }

  Future<void> _quickAdd() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => QuickAddTaskSheet(
        projects: _repository.projects,
        onSubmit: _store.addTask,
      ),
    );
    if (!mounted || created != true) return;
    _showSnack('Task created from quick add.', type: AppSnackType.success);
  }

  Future<void> _edit(Task task) async {
    final draft = await showModalBottomSheet<TaskDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaskEditor(initial: task, existingTags: _store.allTags),
    );
    if (draft == null || !mounted) return;
    try {
      final saved = await _store.updateTask(task.id, draft);
      if (!mounted) return;
      _showSnack(
        saved ? 'Task updated.' : _store.error ?? 'Could not update the task.',
        type: saved ? AppSnackType.success : AppSnackType.error,
      );
    } on TaskValidationException catch (err) {
      if (mounted) _showSnack(err.message, type: AppSnackType.error);
    }
  }

  Future<void> _toggle(Task task) async {
    final wasCompleted = task.isCompleted;
    final saved = await _store.toggleCompletion(task.id);
    if (!mounted) return;
    _showSnack(
      saved
          ? wasCompleted
                ? 'Task reopened.'
                : 'Task completed.'
          : _store.error ?? 'Could not update the task.',
      type: saved ? AppSnackType.success : AppSnackType.error,
    );
  }

  Future<bool> _confirmDelete(Task task) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete task?',
      message: '"${task.title}" will be removed from this device.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return false;

    final saved = await _store.deleteTask(task.id);
    if (!mounted) return false;
    if (!saved) {
      _showSnack(
        _store.error ?? 'Could not delete the task.',
        type: AppSnackType.error,
      );
      return false;
    }
    _showSnack(
      'Task deleted.',
      type: AppSnackType.success,
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          final restored = await _store.restoreTask(task);
          if (!mounted) return;
          _showSnack(
            restored
                ? 'Task restored.'
                : _store.error ?? 'Could not restore the task.',
            type: restored ? AppSnackType.success : AppSnackType.error,
          );
        },
      ),
    );
    return false;
  }

  Future<void> _breakDown(Task task) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaskBreakdownSheet(
        taskTitle: task.title,
        project: task.course.isEmpty ? null : task.course,
        onApprove: (subtasks) => _addBreakdown(task, subtasks),
      ),
    );
  }

  Future<int> _addBreakdown(
    Task parent,
    List<SubtaskSuggestion> subtasks,
  ) async {
    var created = 0;
    for (final subtask in subtasks) {
      final due = DateTime.now().add(Duration(days: subtask.order));
      final saved = await _store.addTask(
        TaskDraft(
          title: subtask.title,
          notes: '${subtask.description}\n\nPart of: ${parent.title}',
          course: parent.course,
          priority: parent.priority,
          dueDate: due,
        ),
      );
      if (saved) created += 1;
    }
    if (mounted && created > 0) {
      _showSnack(
        '$created breakdown ${created == 1 ? 'step' : 'steps'} added.',
        type: AppSnackType.success,
      );
    }
    return created;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AuxiliaAppBar(
        title: 'Tasks',
        subtitle: 'Search, plan and complete your work',
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh tasks',
            onPressed: _store.isLoading ? null : _store.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _quickAdd,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Quick add'),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: RefreshIndicator(
              onRefresh: _store.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: <Widget>[
                  _buildSummary(context),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _search,
                    useFormField: false,
                    hintText: 'Search tasks by title, notes, tags or project',
                    prefixIcon: Icons.search_rounded,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) {
                      _store.setQuery(value);
                      setState(() {});
                    },
                    suffixIcon: _store.query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _search.clear();
                              _store.setQuery('');
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear_rounded),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildFilters(context),
                  const SizedBox(height: AppSpacing.xl),
                  if (_store.isLoading && !_store.hasLoaded)
                    const TaskListSkeleton(itemCount: 5)
                  else if (_store.error != null && _store.tasks.isEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: AppErrorState(
                        title: 'Tasks could not be loaded',
                        message: _store.error!,
                        onRetry: _store.retry,
                      ),
                    )
                  else
                    ..._buildTaskSection(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final int total = _store.tasks.length;
    final int done = _store.completedCount;
    final double ratio = total == 0 ? 0 : done / total;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Widget progress = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${(ratio * 100).round()}% complete',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      '$done of $total tasks',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              CompletionBar(
                value: ratio,
                color: AppColors.successGreen,
                label: '${(ratio * 100).round()} percent of tasks complete',
              ),
            ],
          );

          final Widget stats = Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _Stat(label: 'To do', value: '${_store.pendingCount}'),
              _Stat(label: 'Due today', value: '${_store.dueTodayCount}'),
              _Stat(
                label: 'Overdue',
                value: '${_store.overdueCount}',
                color: _store.overdueCount > 0 ? AppColors.errorRed : null,
              ),
            ],
          );

          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                progress,
                const SizedBox(height: AppSpacing.lg),
                stats,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(flex: 5, child: progress),
              const SizedBox(width: AppSpacing.xl),
              Expanded(flex: 4, child: stats),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final tags = _store.allTags;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _FilterChip(
              label: 'All (${_store.tasks.length})',
              selected: _store.filter == TaskFilter.all,
              onTap: () => _store.setFilter(TaskFilter.all),
            ),
            _FilterChip(
              label: 'To do (${_store.pendingCount})',
              selected: _store.filter == TaskFilter.pending,
              onTap: () => _store.setFilter(TaskFilter.pending),
            ),
            if (_store.overdueCount > 0)
              _FilterChip(
                label: 'Overdue (${_store.overdueCount})',
                selected: _store.filter == TaskFilter.overdue,
                onTap: () => _store.setFilter(TaskFilter.overdue),
                warning: true,
              ),
            _FilterChip(
              label: 'Done (${_store.completedCount})',
              selected: _store.filter == TaskFilter.completed,
              onTap: () => _store.setFilter(TaskFilter.completed),
            ),
          ],
        ),
        if (tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Filter by tag',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final tag in tags)
                FilterChip(
                  label: Text('#$tag'),
                  selected:
                      _store.tagFilter?.toLowerCase() == tag.toLowerCase(),
                  showCheckmark: false,
                  onSelected: (selected) =>
                      _store.setTagFilter(selected ? tag : null),
                ),
            ],
          ),
        ],
      ],
    );
  }

  List<Widget> _buildTaskSection(BuildContext context) {
    if (_store.tasks.isEmpty) {
      return <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppEmptyState(
            icon: Icons.task_alt_rounded,
            title: 'A clear task list',
            message:
                'Use quick add to capture something in plain language, or '
                'break a bigger deliverable into smaller steps.',
            action: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: FilledButton.icon(
                    onPressed: _quickAdd,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Quick add a task'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (_store.filteredCount == 0) {
      return <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppEmptyState(
            compact: true,
            icon: Icons.filter_alt_off_outlined,
            title: 'No matching tasks',
            message: 'Try a different search or clear the active filter.',
            action: OutlinedButton.icon(
              onPressed: () {
                _search.clear();
                _store.clearFilters();
                setState(() {});
              },
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: const Text('Clear filters'),
            ),
          ),
        ),
      ];
    }

    return <Widget>[
      if (_store.error != null) ...[
        AppErrorBanner(
          message: _store.error!,
          onRetry: _store.retry,
          onDismiss: _store.clearError,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: <Widget>[
            for (
              var index = 0;
              index < _store.visibleTasks.length;
              index++
            ) ...[
              if (index > 0) const Divider(height: 1),
              _SwipeTaskRow(
                key: ValueKey<String>(_store.visibleTasks[index].id),
                task: _store.visibleTasks[index],
                onToggle: () => _toggle(_store.visibleTasks[index]),
                onEdit: () => _edit(_store.visibleTasks[index]),
                onDelete: () => _confirmDelete(_store.visibleTasks[index]),
                onBreakdown: () => _breakDown(_store.visibleTasks[index]),
              ),
            ],
          ],
        ),
      ),
      if (_store.pageCount > 1) ...[
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton(
              tooltip: 'Previous page',
              onPressed: _store.canGoToPreviousPage
                  ? _store.previousPage
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text(
              'Page ${_store.page + 1} of ${_store.pageCount}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            IconButton(
              tooltip: 'Next page',
              onPressed: _store.canGoToNextPage ? _store.nextPage : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    ];
  }
}

class _SwipeTaskRow extends StatelessWidget {
  const _SwipeTaskRow({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onBreakdown,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final Future<bool> Function() onDelete;
  final VoidCallback onBreakdown;

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

    return Dismissible(
      key: ValueKey<String>('swipe-${task.id}'),
      background: _SwipeBackground(
        color: completed ? AppColors.warningAmber : AppColors.successGreen,
        icon: completed ? Icons.undo_rounded : Icons.check_rounded,
        label: completed ? 'Reopen' : 'Complete',
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
          onToggle();
        } else {
          await onDelete();
        }
        return false;
      },
      child: InkWell(
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
                child: Checkbox(value: completed, onChanged: (_) => onToggle()),
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
                        decoration: completed
                            ? TextDecoration.lineThrough
                            : null,
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
                        if (task.course.isNotEmpty)
                          StatusBadge(
                            label: task.course,
                            color: scheme.primary,
                            icon: Icons.workspaces_outline,
                          ),
                        if (task.assigneeName != null)
                          StatusBadge(
                            label: task.assigneeName!,
                            color: scheme.tertiary,
                            icon: Icons.person_outline_rounded,
                          ),
                        for (final tag in task.tags.take(3))
                          StatusBadge(
                            label: '#$tag',
                            color: scheme.onSurfaceVariant,
                            icon: Icons.sell_outlined,
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
                    case 'breakdown':
                      onBreakdown();
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
                  PopupMenuItem<String>(
                    value: 'breakdown',
                    child: ListTile(
                      leading: Icon(Icons.account_tree_outlined),
                      title: Text('Break into steps'),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.warning = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final Color accent = warning ? AppColors.warningAmber : scheme.primary;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: accent,
      backgroundColor: scheme.surface,
      side: BorderSide(color: selected ? accent : scheme.outline),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: selected ? Colors.white : scheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
