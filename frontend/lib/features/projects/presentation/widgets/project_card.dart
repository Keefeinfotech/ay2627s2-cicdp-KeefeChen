import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../data/models/project.dart';

/// Project summary card shared by the projects grid and dashboard previews.
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    this.onTap,
    this.onMenu,
  });

  final Project project;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;

  Color get _accent => switch (project.effectiveStatus) {
    ProjectStatus.active => AppColors.trustBlue,
    ProjectStatus.completed => AppColors.successGreen,
    ProjectStatus.archived => AppColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final next = project.nextDeadline;
    final String deadlineLabel = next == null
        ? 'No deadline'
        : project.isAtRisk
        ? 'Overdue · ${formatDateOnly(next)}'
        : 'Next ${formatDateOnly(next)}';
    final String taskLabel =
        '${project.completedTasks}/${project.totalTasks} '
        '${project.totalTasks == 1 ? 'task' : 'tasks'}';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        project.effectiveStatus == ProjectStatus.completed
                            ? Icons.check_circle_outline_rounded
                            : Icons.workspaces_outline,
                        color: _accent,
                        size: AppSizes.iconMd,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            project.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (project.description
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              project.description.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onMenu != null)
                      IconButton(
                        tooltip: 'Project actions for ${project.name}',
                        onPressed: onMenu,
                        icon: const Icon(Icons.more_vert_rounded),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    StatusBadge(
                      label: project.effectiveStatus.label,
                      color: _accent,
                      icon: project.effectiveStatus == ProjectStatus.completed
                          ? Icons.check_circle_outline_rounded
                          : project.effectiveStatus == ProjectStatus.archived
                          ? Icons.archive_outlined
                          : Icons.bolt_outlined,
                    ),
                    if (project.overdueTasks > 0)
                      StatusBadge(
                        label: '${project.overdueTasks} overdue',
                        color: scheme.error,
                        icon: Icons.warning_amber_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: CompletionBar(
                        value: project.progress,
                        color: _accent,
                        label:
                            '${(project.progress * 100).round()} percent of '
                            '${project.name} complete',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${(project.progress * 100).round()}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.task_alt_rounded,
                      size: AppSizes.iconSm,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        taskLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        deadlineLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: project.isAtRisk
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                          fontWeight: project.isAtRisk
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
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
