import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../home/data/task_store.dart';

/// The calm overview at the top of the dashboard.
///
/// It keeps the brand and profile actions together, states the current
/// workload in plain language, and shows the six existing task metrics without
/// turning each one into its own card.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.store,
    required this.displayName,
    required this.onAchievements,
    required this.onProfile,
  });

  final TaskStore store;
  final String? displayName;
  final VoidCallback onAchievements;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = store.levelProgress;

    final Widget greeting = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Welcome back',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          displayName ?? 'My workspace',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${progress.totalXp} XP · '
          '${store.completedCount} of ${store.tasks.length} complete',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool wide = constraints.maxWidth >= 680;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const BrandMark(size: 34),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Auxilia',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Workspace',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Achievements',
                    onPressed: onAchievements,
                    icon: const Icon(Icons.emoji_events_outlined),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  AppAvatar(
                    name: displayName,
                    tooltip: 'Profile and settings',
                    onTap: onProfile,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          greeting,
                          const SizedBox(height: AppSpacing.md),
                          _LevelProgress(store: store),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(flex: 6, child: DashboardStats(store: store)),
                  ],
                )
              else ...<Widget>[
                greeting,
                const SizedBox(height: AppSpacing.md),
                _LevelProgress(store: store),
                const SizedBox(height: AppSpacing.lg),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: AppSpacing.lg),
                DashboardStats(store: store),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LevelProgress extends StatelessWidget {
  const _LevelProgress({required this.store});

  final TaskStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = store.levelProgress;

    return Semantics(
      label:
          'Level ${progress.level}. ${progress.xpIntoLevel} of '
          '${progress.xpForNextLevel} XP earned toward the next level.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Level ${progress.level}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  '${progress.xpIntoLevel} / ${progress.xpForNextLevel} XP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 6,
              backgroundColor: scheme.outlineVariant,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Six compact workload metrics laid out without individual card chrome.
class DashboardStats extends StatelessWidget {
  const DashboardStats({super.key, required this.store});

  final TaskStore store;

  @override
  Widget build(BuildContext context) {
    final stats = <_StatData>[
      _StatData(label: 'To do', value: '${store.pendingCount}'),
      _StatData(label: 'Due today', value: '${store.dueTodayCount}'),
      _StatData(
        label: 'Overdue',
        value: '${store.overdueCount}',
        accent: store.overdueCount > 0 ? AppColors.warningAmber : null,
      ),
      _StatData(
        label: 'Done',
        value: '${store.completedCount}',
        accent: store.completedCount > 0 ? AppColors.teal : null,
      ),
      _StatData(label: 'This week', value: '${store.completedThisWeek}'),
      _StatData(label: 'Total XP', value: '${store.levelProgress.totalXp}'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = constraints.maxWidth >= 360 ? 3 : 2;
        const double spacing = AppSpacing.lg;
        final double tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: AppSpacing.lg,
          children: stats
              .map(
                (stat) => SizedBox(
                  width: tileWidth,
                  child: _Stat(stat: stat),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _StatData {
  const _StatData({required this.label, required this.value, this.accent});

  final String label;
  final String value;
  final Color? accent;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.stat});

  final _StatData stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          stat.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            color: stat.accent ?? scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          stat.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}
