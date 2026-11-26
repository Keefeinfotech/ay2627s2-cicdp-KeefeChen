import 'package:flutter/material.dart';

import '../../../../core/design_system/ds_tokens.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_status_badge.dart';

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
  String _view = 'table';
  final Set<String> _collapsed = <String>{};

  // Shared column widths keep the header and rows on the same grid. The gaps
  // give the status, priority and metadata groups consistent breathing room.
  static const double _statusColumnWidth = 136;
  static const double _priorityColumnWidth = 84;
  static const double _dueColumnWidth = 88;

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
      builder: (_) => TaskEditor(
        initial: task,
        existingTags: _store.allTags,
        existingCourses: _store.allCourses,
      ),
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
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.maxContentWidth,
            ),
            child: RefreshIndicator(
              onRefresh: _store.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: <Widget>[
                  _buildViewSwitcher(context),
                  const SizedBox(height: 12),
                  _buildActionToolbar(context),
                  const SizedBox(height: 16),
                  if (_store.isLoading && !_store.hasLoaded)
                    const TaskListSkeleton(itemCount: 5)
                  else if (_store.error != null && _store.tasks.isEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: AppErrorState(
                        title: 'Tasks could not be loaded',
                        message: _store.error!,
                        onRetry: _store.retry,
                      ),
                    )
                  else if (_view != 'table')
                    _buildAltViewPlaceholder(context)
                  else
                    ..._buildGroupedTasks(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewSwitcher(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    Widget chip(String id, String label, IconData icon) {
      final sel = _view == id;
      return ChoiceChip(
        showCheckmark: false,
        avatar: Icon(
          icon,
          size: 16,
          color: sel ? scheme.primary : scheme.onSurfaceVariant,
        ),
        label: Text(label),
        selected: sel,
        onSelected: (_) => setState(() => _view = id),
        selectedColor: scheme.primary.withValues(alpha: 0.12),
        side: BorderSide(
          color: sel
              ? scheme.primary.withValues(alpha: 0.4)
              : (isDark ? Ds.borderDark : scheme.outlineVariant),
        ),
        labelStyle: TextStyle(
          fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
          color: sel ? scheme.primary : scheme.onSurfaceVariant,
        ),
        backgroundColor: isDark ? Ds.surfaceDark : scheme.surface,
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('table', 'Main Table', Icons.table_rows_rounded),
        chip('board', 'Board', Icons.view_kanban_outlined),
        chip('calendar', 'Calendar', Icons.calendar_month_outlined),
      ],
    );
  }

  Widget _buildActionToolbar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final border = isDark ? Ds.borderDark : scheme.outlineVariant;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppButton(
          label: 'New task',
          icon: Icons.add_rounded,
          onPressed: _quickAdd,
        ),
        SizedBox(
          width: 220,
          height: AppSizes.buttonHeight,
          child: TextField(
            controller: _search,
            onChanged: (v) {
              _store.setQuery(v);
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              isDense: true,
              filled: true,
              fillColor: isDark ? Ds.surfaceDark : scheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border),
              ),
            ),
          ),
        ),
        _ghostBtn(
          context,
          Icons.filter_list_rounded,
          'Filter',
          () => _showFilterSheet(context),
        ),
        _ghostBtn(context, Icons.swap_vert_rounded, 'Sort', () {}),
        _ghostBtn(context, Icons.layers_outlined, 'Group by', () {}),
        if (_store.query.isNotEmpty ||
            _store.filter != TaskFilter.all ||
            _store.tagFilter != null)
          TextButton(
            onPressed: () {
              _search.clear();
              _store.clearFilters();
              setState(() {});
            },
            child: const Text('Clear'),
          ),
      ],
    );
  }

  Widget _ghostBtn(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final border = isDark ? Ds.borderDark : scheme.outlineVariant;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: AppSizes.iconMd),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        side: BorderSide(color: border),
        minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Ds.rMd),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('All (${_store.tasks.length})'),
                selected: _store.filter == TaskFilter.all,
                onSelected: (_) {
                  _store.setFilter(TaskFilter.all);
                  Navigator.pop(ctx);
                  setState(() {});
                },
              ),
              ChoiceChip(
                label: Text('To do (${_store.pendingCount})'),
                selected: _store.filter == TaskFilter.pending,
                onSelected: (_) {
                  _store.setFilter(TaskFilter.pending);
                  Navigator.pop(ctx);
                  setState(() {});
                },
              ),
              ChoiceChip(
                label: Text('Overdue (${_store.overdueCount})'),
                selected: _store.filter == TaskFilter.overdue,
                onSelected: (_) {
                  _store.setFilter(TaskFilter.overdue);
                  Navigator.pop(ctx);
                  setState(() {});
                },
              ),
              ChoiceChip(
                label: Text('Done (${_store.completedCount})'),
                selected: _store.filter == TaskFilter.completed,
                onSelected: (_) {
                  _store.setFilter(TaskFilter.completed);
                  Navigator.pop(ctx);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAltViewPlaceholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Center(
        child: Text(
          _view == 'board'
              ? 'Board view coming soon'
              : 'Calendar view coming soon',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedTasks(BuildContext context) {
    final tasks = _store.visibleTasks.toList();
    if (_store.tasks.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: AppEmptyState(
            icon: Icons.task_alt_rounded,
            title: 'A clear task list',
            message: 'Use the New task button to capture something in plain language.',
            action: FilledButton.icon(
              onPressed: _quickAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add your first task'),
            ),
          ),
        ),
      ];
    }
    if (tasks.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: AppEmptyState(
            compact: true,
            icon: Icons.filter_alt_off_outlined,
            title: 'No matching tasks',
            message: 'Try a different search or clear the active filter.',
            action: OutlinedButton(
              onPressed: () {
                _search.clear();
                _store.clearFilters();
                setState(() {});
              },
              child: const Text('Clear filters'),
            ),
          ),
        ),
      ];
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final soon = today.add(const Duration(days: 2));
    final groups = <String, List<Task>>{
      'Today / Due Soon': [],
      'Upcoming': [],
      'Completed': [],
    };
    for (final t in tasks) {
      if (t.isCompleted) {
        groups['Completed']!.add(t);
        continue;
      }
      final d = t.dueDate;
      if (d != null) {
        final dd = DateTime(d.year, d.month, d.day);
        if (!dd.isAfter(soon)) {
          groups['Today / Due Soon']!.add(t);
          continue;
        }
      }
      groups['Upcoming']!.add(t);
    }
    final colors = <String, Color>{
      'Today / Due Soon': Ds.warningAmber,
      'Upcoming': Ds.trustBlue,
      'Completed': Ds.accentGreen,
    };

    final out = <Widget>[];
    groups.forEach((name, items) {
      if (items.isEmpty) return;
      out.add(_buildTaskGroup(context, name, colors[name]!, items));
      out.add(const SizedBox(height: 16));
    });
    return out;
  }

  Widget _buildTaskGroup(
    BuildContext context,
    String name,
    Color accent,
    List<Task> items,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final border = isDark ? Ds.borderDark : scheme.outlineVariant;
    final bg = isDark ? Ds.surfaceDark : scheme.surface;
    final collapsed = _collapsed.contains(name);

    final header = InkWell(
      onTap: () => setState(() {
        collapsed ? _collapsed.remove(name) : _collapsed.add(name);
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              collapsed
                  ? Icons.chevron_right_rounded
                  : Icons.expand_more_rounded,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Ds.rLg),
              ),
              child: Text(
                '${items.length}',
                style: Ds.captionStrong.copyWith(color: accent),
              ),
            ),
          ],
        ),
      ),
    );

    final addTask = InkWell(
      onTap: _quickAdd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.add_rounded, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'Add task',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Ds.rXl),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The fixed-column table cannot fit a phone. Switch to stacked task
          // cards before the columns crowd or clip.
          final compact = constraints.maxWidth < 760;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accent),
                Expanded(
                  child: Column(
                    children: [
                      header,
                      if (!collapsed) ...[
                        Divider(height: 1, color: border),
                        if (!compact) _tableHeader(),
                        if (!compact) Divider(height: 1, color: border),
                        for (var i = 0; i < items.length; i++) ...[
                          compact
                              ? _compactTaskTile(context, items[i])
                              : _taskRow(context, items[i]),
                          if (i < items.length - 1)
                            Divider(
                              height: 1,
                              indent: 14,
                              endIndent: 14,
                              color: border.withValues(alpha: 0.6),
                            ),
                        ],
                        Divider(height: 1, color: border),
                        addTask,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tableHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: AppSizes.touchTarget),
          SizedBox(width: AppSpacing.sm),
          Expanded(flex: 4, child: Text('Task Name', style: Ds.labelStrong)),
          SizedBox(width: AppSpacing.md),
          Expanded(flex: 2, child: Text('Project', style: Ds.labelStrong)),
          SizedBox(width: AppSpacing.md),
          SizedBox(
            width: _statusColumnWidth,
            child: Text('Status', style: Ds.labelStrong),
          ),
          SizedBox(width: AppSpacing.md),
          SizedBox(
            width: _priorityColumnWidth,
            child: Text('Priority', style: Ds.labelStrong),
          ),
          SizedBox(width: AppSpacing.md),
          SizedBox(
            width: _dueColumnWidth,
            child: Text('Due Date', style: Ds.labelStrong),
          ),
          SizedBox(width: AppSpacing.sm),
          SizedBox(width: AppSizes.touchTarget),
        ],
      ),
    );
  }

  String _taskStatusLabel(Task task) {
    if (task.isCompleted) return 'Done';
    if (task.isOverdue) return 'Overdue';
    return 'Working on it';
  }

  IconData _taskStatusIcon(Task task) {
    if (task.isCompleted) return Icons.check_circle_outline_rounded;
    if (task.isOverdue) return Icons.warning_amber_rounded;
    return Icons.schedule_rounded;
  }

  Color _taskStatusColor(Task task, bool isDark) {
    if (task.isCompleted) {
      return isDark ? Ds.successOnDark : Ds.accentGreen;
    }
    if (task.isOverdue) {
      return isDark ? Ds.dangerOnDark : Ds.dangerRed;
    }
    return isDark ? Ds.primaryOnDark : Ds.trustBlue;
  }

  /// Solid, high-contrast fill for status pills. On-dark accents are reserved
  /// for text on dark surfaces; a filled pill always carries crisp white text.
  Color _taskStatusFillColor(Task task) {
    if (task.isCompleted) return Ds.accentGreen;
    if (task.isOverdue) return Ds.dangerRed;
    return Ds.trustBlue;
  }

  Color _taskPriorityColor(TaskPriority priority, bool isDark) {
    return switch (priority) {
      TaskPriority.low => isDark ? Ds.primaryOnDark : Ds.trustBlue,
      TaskPriority.medium => isDark ? Ds.warningOnDark : Ds.warningAmber,
      TaskPriority.high => isDark ? Ds.dangerOnDark : Ds.dangerRed,
    };
  }

  /// Compact metadata cell with a leading icon so values read as structured
  /// data rather than unstyled text floating beside the badges.
  Widget _metaText(
    BuildContext context, {
    required IconData icon,
    required String text,
    required Color color,
    bool emphasize = false,
  }) {
    return Row(
      children: <Widget>[
        Icon(icon, size: AppSizes.iconSm, color: color),
        const SizedBox(width: AppSpacing.xxs),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Ds.small.copyWith(
              color: color,
              fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _taskMenu(BuildContext context, Task task) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      iconSize: AppSizes.iconMd,
      padding: const EdgeInsets.all(AppSpacing.md),
      icon: Icon(Icons.more_horiz_rounded, color: scheme.onSurfaceVariant),
      onSelected: (v) {
        if (v == 'edit') _edit(task);
        if (v == 'delete') _confirmDelete(task);
        if (v == 'breakdown') _breakDown(task);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'breakdown', child: Text('Break down')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }

  Widget _compactTaskTile(BuildContext context, Task task) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final overdue = task.isOverdue;
    final statusColor = _taskStatusColor(task, isDark);

    return InkWell(
      onTap: () => _edit(task),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: AppSizes.touchTarget,
              height: AppSizes.touchTarget,
              child: Checkbox(
                value: task.isCompleted,
                onChanged: (_) => _toggle(task),
                side: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: task.isCompleted
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (task.course.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    _metaText(
                      context,
                      icon: Icons.school_outlined,
                      text: task.course,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusBadge(
                        label: _taskStatusLabel(task),
                        color: _taskStatusFillColor(task),
                        icon: _taskStatusIcon(task),
                        filled: true,
                      ),
                      PriorityBadge.task(
                        label: task.priority.label,
                        color: _taskPriorityColor(task.priority, isDark),
                      ),
                      if (task.dueDate != null)
                        _metaText(
                          context,
                          icon: Icons.event_outlined,
                          text: _fmtDate(task.dueDate!),
                          color: overdue
                              ? statusColor
                              : scheme.onSurfaceVariant,
                          emphasize: overdue,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            _taskMenu(context, task),
          ],
        ),
      ),
    );
  }

  Widget _taskRow(BuildContext context, Task task) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final overdue = task.isOverdue;
    final statusColor = _taskStatusColor(task, isDark);

    return InkWell(
      onTap: () => _edit(task),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: AppSizes.touchTarget,
              height: AppSizes.touchTarget,
              child: Checkbox(
                value: task.isCompleted,
                onChanged: (_) => _toggle(task),
                side: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 4,
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  decoration: task.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                  color: task.isCompleted
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: _metaText(
                context,
                icon: Icons.school_outlined,
                text: task.course.isEmpty ? 'No course' : task.course,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: _statusColumnWidth,
              child: StatusBadge(
                label: _taskStatusLabel(task),
                color: _taskStatusFillColor(task),
                icon: _taskStatusIcon(task),
                filled: true,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: _priorityColumnWidth,
              child: PriorityBadge.task(
                label: task.priority.label,
                color: _taskPriorityColor(task.priority, isDark),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: _dueColumnWidth,
              child: _metaText(
                context,
                icon: Icons.event_outlined,
                text: task.dueDate == null
                    ? 'No date'
                    : _fmtDate(task.dueDate!),
                color: overdue ? statusColor : scheme.onSurfaceVariant,
                emphasize: overdue,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: AppSizes.touchTarget,
              child: _taskMenu(context, task),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${m[d.month - 1]} ${d.day}';
  }
}
