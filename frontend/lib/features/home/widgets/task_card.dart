import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../models/task.dart';

/// A flat, single-line-oriented task row.
///
/// Metadata stays as inline text instead of a row of pills, which keeps long
/// lists calm and lets the title remain the strongest element.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  String get _statusText {
    if (task.isCompleted) return 'Completed';
    if (task.isOverdue) return 'Overdue';
    return 'Pending';
  }

  String get _dueText {
    final dueDate = task.dueDate;
    if (dueDate == null) return 'No due date';
    return 'Due ${formatTaskDate(dueDate)}';
  }

  Color _priorityColor(ColorScheme scheme) => switch (task.priority) {
    TaskPriority.low => scheme.primary,
    TaskPriority.medium => AppColors.warningAmber,
    TaskPriority.high => scheme.error,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bool completed = task.isCompleted;
    final Color muted = scheme.onSurfaceVariant;

    return Semantics(
      container: true,
      label:
          'Task: ${task.title}. ${task.priority.label} priority. '
          '$_statusText. $_dueText.',
      child: Container(
        color: completed
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Semantics(
                container: true,
                label: completed
                    ? 'Mark ${task.title} as pending'
                    : 'Mark ${task.title} as complete',
                toggled: completed,
                child: Checkbox(
                  value: completed,
                  onChanged: (_) => onToggle(),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.xs,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      task.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        decoration: completed
                            ? TextDecoration.lineThrough
                            : null,
                        color: completed ? muted : null,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (task.notes.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        task.notes.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        _MetaItem(
                          label: '${task.priority.label} priority',
                          dotColor: _priorityColor(scheme),
                          color: _priorityColor(scheme),
                        ),
                        if (task.course.isNotEmpty)
                          _MetaItem(
                            label: task.course,
                            icon: Icons.school_outlined,
                            color: muted,
                          ),
                        _MetaItem(
                          label: _dueText,
                          icon: task.isOverdue
                              ? Icons.warning_amber_rounded
                              : Icons.schedule_rounded,
                          color: task.isOverdue ? scheme.error : muted,
                        ),
                        Text(
                          _statusText,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: task.isCompleted
                                ? scheme.tertiary
                                : task.isOverdue
                                ? scheme.error
                                : muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (onEdit != null)
              _actionButton(
                context,
                tooltip: 'Edit ${task.title}',
                onPressed: onEdit!,
                icon: Icons.edit_outlined,
              ),
            if (onDelete != null)
              _actionButton(
                context,
                tooltip: 'Delete ${task.title}',
                onPressed: onDelete!,
                icon: Icons.delete_outline_rounded,
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required String tooltip,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: AppSizes.iconMd),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.label,
    required this.color,
    this.icon,
    this.dotColor,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (dotColor != null)
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          )
        else if (icon != null)
          Icon(icon, size: 14, color: color),
        if (dotColor != null || icon != null)
          const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
