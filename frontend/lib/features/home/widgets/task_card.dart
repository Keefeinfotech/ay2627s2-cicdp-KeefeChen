import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../models/task.dart';

/// A weather-inspired task card with coloured priority accents and subtle
/// elevation. Each card lifts gently when it represents an overdue or high
/// priority task, drawing the eye to what needs attention first.
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
    TaskPriority.low => AppColors.pacific,
    TaskPriority.medium => AppColors.saffron,
    TaskPriority.high => AppColors.persimmon,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bool completed = task.isCompleted;
    final bool overdue = task.isOverdue;
    final Color muted = scheme.onSurfaceVariant;
    final Color accent = _priorityColor(scheme);

    return Semantics(
      container: true,
      label:
          'Task: ${task.title}. ${task.priority.label} priority. '
          '$_statusText. $_dueText.',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: completed
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.25)
              : scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: overdue
                ? AppColors.persimmon.withValues(alpha: 0.4)
                : completed
                ? scheme.outlineVariant.withValues(alpha: 0.4)
                : scheme.outlineVariant,
          ),
          boxShadow: [
            if (!completed)
              BoxShadow(
                color: accent.withValues(alpha: overdue ? 0.15 : 0.08),
                blurRadius: overdue ? 16 : 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
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
                        activeColor: accent,
                        checkColor: scheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        side: BorderSide(
                          color: completed ? accent : scheme.outlineVariant,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        AppSpacing.sm,
                        AppSpacing.sm,
                        AppSpacing.sm,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              decoration: completed
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: completed ? muted : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          if (onEdit != null || onDelete != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                if (onEdit != null)
                                  _actionButton(
                                    context,
                                    tooltip: 'Edit ${task.title}',
                                    onPressed: onEdit!,
                                    icon: Icons.edit_outlined,
                                    accent: accent,
                                  ),
                                if (onDelete != null)
                                  _actionButton(
                                    context,
                                    tooltip: 'Delete ${task.title}',
                                    onPressed: onDelete!,
                                    icon: Icons.delete_outline_rounded,
                                    accent: AppColors.persimmon,
                                  ),
                              ],
                            ),
                          if (task.notes.trim().isNotEmpty) ...[
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
                                dotColor: accent,
                                color: accent,
                              ),
                              if (task.course.isNotEmpty)
                                _MetaItem(
                                  label: task.course,
                                  icon: Icons.school_outlined,
                                  color: muted,
                                ),
                              if (task.assigneeName != null)
                                _MetaItem(
                                  label: task.assigneeName!,
                                  icon: Icons.person_outline_rounded,
                                  color: muted,
                                ),
                              if (task.reminderAt != null)
                                _MetaItem(
                                  label:
                                      'Reminder ${formatTaskDate(task.reminderAt!)}',
                                  icon: Icons.notifications_active_outlined,
                                  color: muted,
                                ),
                              _MetaItem(
                                label: _dueText,
                                icon: overdue
                                    ? Icons.warning_amber_rounded
                                    : Icons.schedule_rounded,
                                color: overdue ? AppColors.persimmon : muted,
                              ),
                              Text(
                                _statusText,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: task.isCompleted
                                      ? AppColors.malachite
                                      : overdue
                                      ? AppColors.persimmon
                                      : muted,
                                ),
                              ),
                            ],
                          ),
                          if (task.tags.isNotEmpty) ...<Widget>[
                            const SizedBox(height: AppSpacing.xs),
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: <Widget>[
                                for (final tag in task.tags)
                                  _TagPill(
                                    label: tag,
                                    accent: accent,
                                    muted: muted,
                                    scheme: scheme,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required String tooltip,
    required VoidCallback onPressed,
    required IconData icon,
    required Color accent,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: AppSizes.iconMd, color: accent),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        foregroundColor: accent,
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({
    required this.label,
    required this.accent,
    required this.muted,
    required this.scheme,
  });

  final String label;
  final Color accent;
  final Color muted;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Text(
        '#$label',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: accent, fontWeight: FontWeight.w600),
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
