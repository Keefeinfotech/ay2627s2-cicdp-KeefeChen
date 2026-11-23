import 'package:flutter/material.dart';

import '../../../core/design_system/ds_tokens.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../home/data/task_store.dart';
import '../../profile/data/avatar_store.dart';

/// Weather-inspired dashboard header.
///
/// Each stat card carries its own accent colour — pacific teal for "To do",
/// moss green for pending, persimmon for overdue, malachite for done,
/// saffron for XP — so the header reads like a spread of cafe weather rather
/// than one flat navy surface.
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
            // Brand + name + actions
            Row(
              children: <Widget>[
                const BrandMark(size: 36),
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
                  icon: const Icon(Icons.emoji_events_outlined),
                  color: TabWeather.completed,
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

            // Weather-inspired stat cards - each with its own colour.
            // On phones the five cards wrap into a compact grid instead of
            // squeezing into a single unreadable row.
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 620;
                final gap = isNarrow ? AppSpacing.xs : AppSpacing.md;

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
                  // Three columns on top, two below - labels stay readable.
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: <Widget>[
                      for (final card in cards)
                        SizedBox(
                          width: (constraints.maxWidth - 2 * gap) / 3,
                          child: card,
                        ),
                    ],
                  );
                }

                return Row(
                  children: <Widget>[
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) SizedBox(width: gap),
                      cards[i],
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // Level progress bar
            _LevelProgress(store: store),
          ],
        ),
      ),
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

  /// Tighter layout for narrow phone widths.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final Widget card = Container(
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Ds.rLg),
        border: Border.all(color: accent),
        boxShadow: Ds.elevation2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Ds.rSm),
              ),
              child: Icon(icon, size: 18, color: accent),
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
    );

    return compact ? card : Expanded(child: card);
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
          border: Border.all(color: Ds.border),
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
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(Ds.rSm),
              child: LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 8,
                backgroundColor: scheme.outlineVariant,
                color: TabWeather.pending,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fallback BrandMark if not imported elsewhere
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Ds.trustBlue,
        borderRadius: BorderRadius.circular(Ds.rMd),
      ),
      child: Icon(
        Icons.dashboard_rounded,
        size: size * 0.55,
        color: Ds.onPrimary,
      ),
    );
  }
}

/// Weather accent colours for dashboard tabs and stats.
class TabWeather {
  static const Color all = Ds.trustBlue;
  static const Color pending = Ds.warningAmber;
  static const Color overdue = Ds.dangerRed;
  static const Color completed = Ds.accentGreen;
}
