import 'package:flutter/material.dart';

import '../../../core/design_system/ds_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../models/task.dart';

/// A weather-inspired task card with coloured priority accents and subtle
/// elevation. Each card lifts gently when it represents an overdue or high
/// priority task, drawing the eye to what needs attention first.
///
/// Cards are swipeable: swiping left/right toggles completion and the right
/// swipe target doubles as the delete affordance — the "marking and deleting"
/// flow popularised by Mobbin's productivity screen library.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
    this.onBreakdown,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onBreakdown;

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
    TaskPriority.low => Ds.trustBlue,
    TaskPriority.medium => Ds.warningAmber,
    TaskPriority.high => Ds.dangerRed,
  };

  static bool _isDueToday(DateTime? dueDate) {
    if (dueDate == null) return false;
    final now = DateTime.now();
    return dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bool completed = task.isCompleted;
    final bool overdue = task.isOverdue;
    final Color muted = scheme.onSurfaceVariant;
    final Color accent = _priorityColor(scheme);
    final bool dueToday = !completed && _isDueToday(task.dueDate);

    return Semantics(
      container: true,
      label:
          'Task: ${task.title}. ${task.priority.label} priority. '
          '$_statusText. $_dueText.',
      child: Dismissible(
        key: ValueKey<String>('task-swipe-${task.id}'),
        direction: DismissDirection.horizontal,
        background: _SwipeBackground(
          color: completed ? Ds.warningAmber : Ds.accentGreen,
          icon: completed ? Icons.undo_rounded : Icons.check_rounded,
          label: completed ? 'Reopen' : 'Complete',
          alignment: Alignment.centerLeft,
        ),
        secondaryBackground: onDelete == null
            ? null
            : const _SwipeBackground(
                color: Ds.dangerRed,
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                alignment: Alignment.centerRight,
              ),
        confirmDismiss: (direction) {
          if (direction == DismissDirection.startToEnd) {
            onToggle();
          } else if (onDelete != null) {
            onDelete!();
          }
          return Future<bool>.value(false);
        },
        child: _CardBody(
          task: task,
          accent: accent,
          muted: muted,
          completed: completed,
          overdue: overdue,
          dueToday: dueToday,
          onToggle: onToggle,
          onEdit: onEdit,
          onDelete: onDelete,
          onBreakdown: onBreakdown,
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.task,
    required this.accent,
    required this.muted,
    required this.completed,
    required this.overdue,
    required this.dueToday,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
    this.onBreakdown,
  });

  final Task task;
  final Color accent;
  final Color muted;
  final bool completed;
  final bool overdue;
  final bool dueToday;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onBreakdown;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedContainer(
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
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
                const SizedBox(width: AppSpacing.sm),
                Expanded(
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
                          if (dueToday)
                            StatusBadge(
                              label: 'Due today',
                              color: accent,
                              icon: Icons.today_rounded,
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
                PopupMenuButton<String>(
                  tooltip: 'Task actions for ${task.title}',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit?.call();
                      case 'breakdown':
                        onBreakdown?.call();
                      case 'delete':
                        onDelete?.call();
                    }
                  },
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    if (onEdit != null)
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit task'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (onBreakdown != null)
                      const PopupMenuItem<String>(
                        value: 'breakdown',
                        child: ListTile(
                          leading: Icon(Icons.account_tree_outlined),
                          title: Text('Break into steps'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem<String>(
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
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
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
