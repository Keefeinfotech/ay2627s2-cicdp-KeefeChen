import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
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
import 'package:frontend/features/home/widgets/task_card.dart';
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
            constraints: const BoxConstraints(maxWidth: 1200),
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
              : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : scheme.outlineVariant),
        ),
        labelStyle: TextStyle(
          fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
          color: sel ? scheme.primary : scheme.onSurfaceVariant,
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : scheme.surface,
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
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : scheme.outlineVariant;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: _quickAdd,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New Task'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        SizedBox(
          width: 220,
          height: 40,
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
              fillColor: isDark ? const Color(0xFF1E293B) : scheme.surface,
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
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : scheme.outlineVariant;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            message: 'Use New Task to capture something in plain language.',
            action: FilledButton.icon(
              onPressed: _quickAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New task'),
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
      'Today / Due Soon': const Color(0xFFF59E0B),
      'Upcoming': const Color(0xFF3B82F6),
      'Completed': const Color(0xFF10B981),
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : scheme.outlineVariant;
    final bg = isDark ? const Color(0xFF1E293B) : scheme.surface;
    final collapsed = _collapsed.contains(name);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(
              child: Column(
                children: [
                  InkWell(
                    onTap: () => setState(() {
                      collapsed
                          ? _collapsed.remove(name)
                          : _collapsed.add(name);
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
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
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${items.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!collapsed) ...[
                    Divider(height: 1, color: border),
                    _tableHeader(context),
                    Divider(height: 1, color: border),
                    for (var i = 0; i < items.length; i++) ...[
                      _taskRow(context, items[i]),
                      if (i < items.length - 1)
                        Divider(
                          height: 1,
                          indent: 14,
                          endIndent: 14,
                          color: border.withValues(alpha: 0.6),
                        ),
                    ],
                    Divider(height: 1, color: border),
                    InkWell(
                      onTap: _quickAdd,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Add task',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 28),
          const Expanded(
            flex: 4,
            child: Text(
              'Task Name',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'Project',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(
            width: 110,
            child: Text(
              'Status',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(
            width: 80,
            child: Text(
              'Priority',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(
            width: 92,
            child: Text(
              'Due Date',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _taskRow(BuildContext context, Task task) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final overdue =
        !task.isCompleted &&
        task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now());
    final statusLabel = task.isCompleted
        ? 'Done'
        : overdue
        ? 'Overdue'
        : 'Working on it';
    final statusColor = task.isCompleted
        ? const Color(0xFF10B981)
        : overdue
        ? const Color(0xFFEF4444)
        : const Color(0xFF3B82F6);

    return InkWell(
      onTap: () => _edit(task),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Checkbox(
                value: task.isCompleted,
                onChanged: (_) => _toggle(task),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
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
            Expanded(
              flex: 2,
              child: Text(
                task.course.isEmpty ? '—' : task.course,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
            SizedBox(
              width: 110,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 80,
              child: Text(
                task.priority.name[0].toUpperCase() +
                    task.priority.name.substring(1),
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(
              width: 92,
              child: Text(
                task.dueDate == null ? '—' : _fmtDate(task.dueDate!),
                style: TextStyle(
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: overdue
                      ? const Color(0xFFEF4444)
                      : scheme.onSurfaceVariant,
                  fontWeight: overdue ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            SizedBox(
              width: 32,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_horiz_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
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
              ),
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
