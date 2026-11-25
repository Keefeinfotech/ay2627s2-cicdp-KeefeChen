import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../home/data/task_store.dart';
import '../../profile/data/avatar_store.dart';

/// Dashboard header: brand lockup, five status stats and level progress.
///
/// Layout is owned by the parent (HomeScreen): this widget no longer adds its
/// own outer padding or a second max-width constraint, which previously made
/// the header sit 16px further in than the search field below it.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Brand + name + actions
        Row(
          children: <Widget>[
            const BrandMark(size: AppSizes.iconTile),
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    'Workspace · ${_greeting()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Achievements',
              onPressed: onAchievements,
              icon: Icon(
                Icons.emoji_events_outlined,
                size: AppSizes.iconLg,
                color: TabWeather.display(TabWeather.completed, scheme),
              ),
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

        // Status stats: Trust Blue is the default accent, green only for
        // completion and red only for genuine overdue urgency. All five
        // cards share the same neutral border, height and icon tile size.
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < AppSizes.compactBreakpoint;
            final columns = isNarrow ? 2 : 5;
            final gap = isNarrow ? AppSpacing.sm : AppSpacing.md;

            final cards = <Widget>[
              _DashboardStatCard(
                label: 'To do',
                value: '${store.pendingCount}',
                accent: TabWeather.pending,
                icon: Icons.radio_button_unchecked_rounded,
                compact: isNarrow,
              ),
              _DashboardStatCard(
                label: 'Due today',
                value: '${store.dueTodayCount}',
                accent: TabWeather.all,
                icon: Icons.today_rounded,
                compact: isNarrow,
              ),
              _DashboardStatCard(
                label: 'Overdue',
                value: '${store.overdueCount}',
                accent: TabWeather.overdue,
                icon: Icons.warning_amber_rounded,
                compact: isNarrow,
              ),
              _DashboardStatCard(
                label: 'Done',
                value: '${store.completedCount}',
                accent: TabWeather.completed,
                icon: Icons.check_circle_rounded,
                compact: isNarrow,
              ),
              _DashboardStatCard(
                label: 'XP',
                value: '${store.levelProgress.totalXp}',
                accent: TabWeather.all,
                icon: Icons.star_rounded,
                compact: isNarrow,
              ),
            ];

            if (isNarrow) {
              final width =
                  (constraints.maxWidth - (columns - 1) * gap) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: <Widget>[
                  for (var i = 0; i < cards.length; i++)
                    SizedBox(
                      width: i == cards.length - 1 && cards.length.isOdd
                          ? constraints.maxWidth
                          : width,
                      child: cards[i],
                    ),
                ],
              );
            }

            return Row(
              children: <Widget>[
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(child: cards[i]),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),

        // Level progress
        _LevelProgress(store: store),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
    this.compact = false,
  });

  final String label;
  final String value;
  final Color accent;
  final IconData icon;

  /// Tighter typography for narrow phone widths.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.statCardMinHeight),
      child: Container(
        padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: AppSizes.iconTile,
                height: AppSizes.iconTile,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  icon,
                  size: AppSizes.iconMd,
                  color: TabWeather.display(accent, scheme),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (compact
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.headlineSmall)
                      ?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: LinearProgressIndicator(
                value: progress.fraction,
                minHeight: AppSizes.progressHeight,
                backgroundColor: scheme.outlineVariant,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
