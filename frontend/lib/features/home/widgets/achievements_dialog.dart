import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../data/gamification.dart';

/// Shows the achievements earned from persisted task state.
///
/// Achievements are derived by [Gamification], so this dialog is presentation
/// only and never stores a second progress counter.
Future<void> showAchievementsDialog(
  BuildContext context, {
  required List<Achievement> achievements,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => AchievementsDialog(achievements: achievements),
  );
}

class AchievementsDialog extends StatelessWidget {
  const AchievementsDialog({super.key, required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final int unlocked = achievements
        .where((achievement) => achievement.unlocked)
        .length;

    return AppDialog(
      title: 'Achievements',
      icon: Icons.emoji_events_rounded,
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '$unlocked of ${achievements.length} unlocked',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (achievements.isEmpty)
            const AppEmptyState(
              title: 'No achievements yet',
              message: 'Complete tasks to start unlocking milestones.',
              icon: Icons.emoji_events_outlined,
              compact: true,
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (
                      var index = 0;
                      index < achievements.length;
                      index++
                    ) ...[
                      if (index > 0) const SizedBox(height: AppSpacing.sm),
                      _AchievementTile(achievement: achievements[index]),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bool unlocked = achievement.unlocked;
    final Color accent = unlocked ? scheme.tertiary : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: unlocked
            ? scheme.tertiaryContainer
            : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: unlocked
              ? scheme.tertiary.withValues(alpha: 0.28)
              : scheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppIconTile(
            icon: unlocked
                ? Icons.emoji_events_rounded
                : Icons.lock_outline_rounded,
            color: accent,
            size: 40,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  achievement.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  achievement.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: unlocked ? scheme.tertiary : scheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: unlocked ? scheme.tertiary : scheme.outlineVariant,
              ),
            ),
            child: Text(
              unlocked ? 'Unlocked' : 'Locked',
              style: theme.textTheme.labelSmall?.copyWith(
                color: unlocked ? scheme.onTertiary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
