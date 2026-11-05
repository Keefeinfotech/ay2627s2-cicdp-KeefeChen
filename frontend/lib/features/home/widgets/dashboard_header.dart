import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../home/data/task_store.dart';
import '../../profile/data/avatar_store.dart';

/// The calm overview at the top of the dashboard.
///
/// It keeps the brand and profile actions together, states the current
/// workload in plain language, and shows task metrics without turning
/// each one into its own card.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.store,
    required this.displayName,
    required this.onAchievements,
    required this.onProfile,
    this.avatarStore,
  });

  final TaskStore store;
  final String? displayName;
  final VoidCallback onAchievements;
  final VoidCallback onProfile;
  final AvatarStore? avatarStore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1120),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Brand + name on mobile / wide layout
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
                        style: theme.textTheme.labelSmall,
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
                if (avatarStore == null)
                  AppAvatar(
                    name: displayName,
                    tooltip: 'Profile and settings',
                    onTap: onProfile,
                  )
                else
                  AnimatedBuilder(
                    animation: avatarStore!,
                    builder: (context, _) => AppAvatar(
                      name: displayName,
                      style: avatarStore!.style,
                      tooltip: 'Profile and settings',
                      onTap: onProfile,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Metrics row - compact, no cards
            Row(
              children: <Widget>[
                _DashboardStat(
                  label: 'To do',
                  value: '${store.pendingCount}',
                  accent: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.lg),
                _DashboardStat(
                  label: 'Due today',
                  value: '${store.dueTodayCount}',
                  accent: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.lg),
                _DashboardStat(
                  label: 'Overdue',
                  value: '${store.overdueCount}',
                  accent: store.overdueCount > 0
                      ? AppColors.warningAmber
                      : null,
                ),
                const SizedBox(width: AppSpacing.lg),
                _DashboardStat(
                  label: 'Done',
                  value: '${store.completedCount}',
                  accent: store.completedCount > 0 ? AppColors.teal : null,
                ),
                const SizedBox(width: AppSpacing.lg),
                _DashboardStat(
                  label: 'Total XP',
                  value: '${store.levelProgress.totalXp}',
                  accent: AppColors.trustBlue,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Level progress bar (no card)
            _LevelProgress(store: store),
          ],
        ),
      ),
    );
  }
}

class _DashboardStat extends StatelessWidget {
  const _DashboardStat({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: accent ?? scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.25,
            ),
          ),
        ],
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

/// Fallback BrandMark if not imported elsewhere
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.auto_awesome,
      size: size,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}
