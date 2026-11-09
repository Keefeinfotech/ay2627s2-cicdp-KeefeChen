import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
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

            // Weather-inspired stat cards — each with its own colour
            Row(
              children: <Widget>[
                _DashboardStatCard(
                  label: 'To do',
                  value: '${store.pendingCount}',
                  accent: TabWeather.pending,
                  icon: Icons.radio_button_unchecked_rounded,
                ),
                const SizedBox(width: AppSpacing.md),
                _DashboardStatCard(
                  label: 'Due today',
                  value: '${store.dueTodayCount}',
                  accent: TabWeather.all,
                  icon: Icons.today_rounded,
                ),
                const SizedBox(width: AppSpacing.md),
                _DashboardStatCard(
                  label: 'Overdue',
                  value: '${store.overdueCount}',
                  accent: TabWeather.overdue,
                  icon: Icons.warning_amber_rounded,
                ),
                const SizedBox(width: AppSpacing.md),
                _DashboardStatCard(
                  label: 'Done',
                  value: '${store.completedCount}',
                  accent: TabWeather.completed,
                  icon: Icons.check_circle_rounded,
                ),
                const SizedBox(width: AppSpacing.md),
                _DashboardStatCard(
                  label: 'Total XP',
                  value: '${store.levelProgress.totalXp}',
                  accent: TabWeather.all,
                  icon: Icons.star_rounded,
                ),
              ],
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
  });

  final String label;
  final String value;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: accent.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
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
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
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
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
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
        gradient: const LinearGradient(
          colors: <Color>[
            AppColors.pacific,
            AppColors.malachite,
            AppColors.saffron,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(
        Icons.auto_awesome,
        size: size * 0.55,
        color: AppColors.white,
      ),
    );
  }
}

/// Weather accent colours for dashboard tabs and stats.
class TabWeather {
  static const Color all = AppColors.pacific;        // teal — ocean
  static const Color pending = AppColors.moss;        // earthy green — forest
  static const Color overdue = AppColors.persimmon;   // warm orange-red — sunset
  static const Color completed = AppColors.malachite; // vivid green — new growth
}
