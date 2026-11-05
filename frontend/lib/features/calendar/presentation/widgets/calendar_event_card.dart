import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../data/models/calendar_event.dart';

/// Shared event surface used by daily, weekly and monthly calendar views.
class CalendarEventCard extends StatelessWidget {
  const CalendarEventCard({
    super.key,
    required this.event,
    this.onTap,
    this.compact = false,
    this.hasConflict = false,
  });

  final CalendarEvent event;
  final VoidCallback? onTap;
  final bool compact;
  final bool hasConflict;

  Color _accent(ColorScheme scheme) {
    if (event.isCompleted) return AppColors.successGreen;
    if (event.isCancelled) return scheme.onSurfaceVariant;
    return switch (event.priority) {
      CalendarEventPriority.low => AppColors.trustBlue,
      CalendarEventPriority.medium => AppColors.primaryDark,
      CalendarEventPriority.high => AppColors.warningAmber,
      CalendarEventPriority.urgent => scheme.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final Color accent = _accent(scheme);
    final String time = event.isAllDay
        ? 'All day'
        : '${_time(event.startTime)} – ${_time(event.endTime)}';

    final Widget content = Padding(
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 3,
            height: compact ? 36 : 48,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  event.title,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (compact
                              ? theme.textTheme.labelMedium
                              : theme.textTheme.titleSmall)
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: event.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: event.isCompleted
                                ? scheme.onSurfaceVariant
                                : null,
                          ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!compact &&
                    (event.location != null ||
                        event.groupId != null ||
                        hasConflict)) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      if (hasConflict)
                        StatusBadge(
                          label: 'Overlap',
                          color: scheme.error,
                          icon: Icons.warning_amber_rounded,
                        ),
                      if (event.location != null && event.location!.isNotEmpty)
                        StatusBadge(
                          label: event.location!,
                          color: scheme.primary,
                          icon: Icons.place_outlined,
                        ),
                      if (event.taskId != null)
                        StatusBadge(
                          label: 'Task',
                          color: scheme.onSurfaceVariant,
                          icon: Icons.task_alt_rounded,
                        ),
                      if (event.isCompleted)
                        const StatusBadge(
                          label: 'Completed',
                          color: AppColors.successGreen,
                          icon: Icons.check_circle_outline_rounded,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!compact && onTap != null) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant,
              size: AppSizes.iconMd,
            ),
          ],
        ],
      ),
    );

    return Semantics(
      button: onTap != null,
      label:
          '${event.title}, $time'
          '${hasConflict ? ', overlaps another event' : ''}',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: hasConflict
                ? scheme.error.withValues(alpha: 0.4)
                : scheme.outlineVariant,
          ),
        ),
        child: onTap == null
            ? content
            : Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap, child: content),
              ),
      ),
    );
  }

  String _time(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
