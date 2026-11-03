import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../data/models/task_breakdown.dart';
import '../../domain/usecases/build_task_breakdown.dart';

/// Review-and-approve view for an AI-suggested task breakdown.
class TaskBreakdownSheet extends StatefulWidget {
  const TaskBreakdownSheet({
    super.key,
    required this.taskTitle,
    required this.onApprove,
    this.project,
    this.planner = const BuildTaskBreakdown(),
  });

  final String taskTitle;
  final String? project;
  final Future<int> Function(List<SubtaskSuggestion> selected) onApprove;
  final BuildTaskBreakdown planner;

  @override
  State<TaskBreakdownSheet> createState() => _TaskBreakdownSheetState();
}

class _TaskBreakdownSheetState extends State<TaskBreakdownSheet> {
  late TaskBreakdownPlan _plan = widget.planner(
    widget.taskTitle,
    project: widget.project,
  );
  bool _saving = false;
  bool _approved = false;
  String? _error;

  void _toggle(String id, bool selected) {
    setState(() {
      _plan = _plan.copyWith(
        subtasks: _plan.subtasks
            .map(
              (task) =>
                  task.id == id ? task.copyWith(selected: selected) : task,
            )
            .toList(growable: false),
      );
    });
  }

  void _toggleAll(bool selected) {
    setState(() {
      _plan = _plan.copyWith(
        subtasks: _plan.subtasks
            .map((task) => task.copyWith(selected: selected))
            .toList(growable: false),
      );
    });
  }

  Future<void> _approve() async {
    if (_plan.selectedCount == 0) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final created = await widget.onApprove(
        _plan.subtasks.where((task) => task.selected).toList(growable: false),
      );
      if (!mounted) return;
      if (created > 0) {
        setState(() {
          _saving = false;
          _approved = true;
        });
      } else {
        setState(() {
          _saving = false;
          _error = 'No steps could be added. Please try again.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'The steps could not be added. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.94;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 760, maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: scheme.outlineVariant,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Icon(
                                      Icons.account_tree_outlined,
                                      size: AppSizes.iconMd,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      'Task breakdown',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Approve the steps you want Auxilia to add.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close breakdown',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      0,
                      AppSpacing.xl,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(
                              alpha: 0.45,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: scheme.primary.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _plan.sourceTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _plan.summary,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                children: <Widget>[
                                  StatusBadge(
                                    label: '${_plan.selectedCount} selected',
                                    color: scheme.primary,
                                    icon: Icons.checklist_rounded,
                                  ),
                                  StatusBadge(
                                    label: _plan.selectedEffortLabel,
                                    color: AppColors.warningAmber,
                                    icon: Icons.schedule_outlined,
                                  ),
                                  if (widget.project != null)
                                    StatusBadge(
                                      label: widget.project!,
                                      color: scheme.tertiary,
                                      icon: Icons.workspaces_outline,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Wrap(
                              spacing: AppSpacing.md,
                              runSpacing: AppSpacing.sm,
                              children: _plan.milestones
                                  .map(
                                    (milestone) => _MilestoneChip(
                                      label: milestone,
                                      index: _plan.milestones.indexOf(
                                        milestone,
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: <Widget>[
                            Text(
                              'Execution order',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _saving
                                  ? null
                                  : () => _toggleAll(
                                      _plan.selectedCount !=
                                          _plan.subtasks.length,
                                    ),
                              child: Text(
                                _plan.selectedCount == _plan.subtasks.length
                                    ? 'Clear all'
                                    : 'Select all',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        for (
                          var index = 0;
                          index < _plan.subtasks.length;
                          index++
                        )
                          _SubtaskRow(
                            subtask: _plan.subtasks[index],
                            isLast: index == _plan.subtasks.length - 1,
                            onChanged: (selected) =>
                                _toggle(_plan.subtasks[index].id, selected),
                            dependencyTitles: _plan.subtasks
                                .where(
                                  (task) => _plan.subtasks[index].dependsOn
                                      .contains(task.id),
                                )
                                .map((task) => task.title)
                                .toList(growable: false),
                          ),
                        if (_error != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Text(
                              _error!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border(
                      top: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      AppButton(
                        label: _approved
                            ? 'Added to tasks'
                            : 'Add ${_plan.selectedCount} approved steps',
                        icon: _approved
                            ? Icons.check_circle_outline_rounded
                            : Icons.playlist_add_check_rounded,
                        onPressed: _saving || _plan.selectedCount == 0
                            ? null
                            : _approve,
                        isLoading: _saving,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MilestoneChip extends StatelessWidget {
  const _MilestoneChip({required this.label, required this.index});

  final String label;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtaskRow extends StatelessWidget {
  const _SubtaskRow({
    required this.subtask,
    required this.isLast,
    required this.onChanged,
    required this.dependencyTitles,
  });

  final SubtaskSuggestion subtask;
  final bool isLast;
  final ValueChanged<bool> onChanged;
  final List<String> dependencyTitles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 32,
            child: Column(
              children: <Widget>[
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: subtask.selected
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: subtask.selected ? scheme.primary : scheme.outline,
                    ),
                  ),
                  child: Text(
                    '${subtask.order}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: subtask.selected
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: subtask.selected
                    ? scheme.surface
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: subtask.selected
                      ? scheme.outlineVariant
                      : scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Checkbox(
                    value: subtask.selected,
                    onChanged: (value) => onChanged(value ?? false),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          subtask.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: subtask.selected
                                ? null
                                : TextDecoration.lineThrough,
                            color: subtask.selected
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          subtask.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: <Widget>[
                            StatusBadge(
                              label: subtask.effortLabel,
                              color: AppColors.warningAmber,
                              icon: Icons.schedule_outlined,
                            ),
                            StatusBadge(
                              label: subtask.milestone,
                              color: scheme.tertiary,
                              icon: Icons.flag_outlined,
                            ),
                            if (dependencyTitles.isNotEmpty)
                              StatusBadge(
                                label:
                                    'After step '
                                    '${subtask.dependsOn.length}',
                                color: scheme.primary,
                                icon: Icons.link_rounded,
                              ),
                          ],
                        ),
                        if (dependencyTitles.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Depends on: ${dependencyTitles.join(', ')}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
