import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../authentication/models/session.dart';
import '../../home/data/task_store.dart';

/// Profile and settings sheet built from actions that already exist in the
/// dashboard: achievements, the AI assistant, local data removal and sign out.
///
/// It deliberately does not introduce account editing, cloud sync or any other
/// feature that the backend does not support.
Future<void> showProfileSheet(
  BuildContext context, {
  required TaskStore store,
  required Session? session,
  required String? displayName,
  required VoidCallback onAchievements,
  required VoidCallback onAssistant,
  required VoidCallback onClearTasks,
  required Future<void> Function() onSignOut,
  required VoidCallback onSignIn,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ProfileSheet(
      store: store,
      session: session,
      displayName: displayName,
      onAchievements: onAchievements,
      onAssistant: onAssistant,
      onClearTasks: onClearTasks,
      onSignOut: onSignOut,
      onSignIn: onSignIn,
    ),
  );
}

class ProfileSheet extends StatelessWidget {
  const ProfileSheet({
    super.key,
    required this.store,
    required this.session,
    required this.displayName,
    required this.onAchievements,
    required this.onAssistant,
    required this.onClearTasks,
    required this.onSignOut,
    required this.onSignIn,
  });

  final TaskStore store;
  final Session? session;
  final String? displayName;
  final VoidCallback onAchievements;
  final VoidCallback onAssistant;
  final VoidCallback onClearTasks;
  final Future<void> Function() onSignOut;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final int unlocked = store.achievements
        .where((achievement) => achievement.unlocked)
        .length;
    final int total = store.achievements.length;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _ProfileHeader(
                  displayName: displayName,
                  session: session,
                  level: store.levelProgress.level,
                ),
                const SizedBox(height: AppSpacing.lg),
                _StatsPanel(
                  totalXp: store.levelProgress.totalXp,
                  completed: store.completedCount,
                  unlocked: unlocked,
                  total: total,
                ),
                const SizedBox(height: AppSpacing.xl),
                const _SectionLabel('ACCOUNT'),
                const SizedBox(height: AppSpacing.sm),
                _ActionGroup(
                  children: <Widget>[
                    _ActionTile(
                      icon: Icons.emoji_events_outlined,
                      title: 'Achievements',
                      subtitle: '$unlocked of $total unlocked',
                      onTap: () => _run(context, onAchievements),
                    ),
                    const Divider(height: 1),
                    _ActionTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'AI assistant',
                      subtitle: session == null
                          ? 'Sign in to start a conversation'
                          : 'Ask for help planning or revising',
                      onTap: () => _run(context, onAssistant),
                    ),
                    const Divider(height: 1),
                    if (session == null)
                      _ActionTile(
                        icon: Icons.login_rounded,
                        title: 'Sign in',
                        subtitle: 'Unlock the AI assistant on this device',
                        onTap: () => _run(context, onSignIn),
                      )
                    else
                      _ActionTile(
                        icon: Icons.logout_rounded,
                        title: 'Sign out',
                        subtitle: 'Keep local tasks and return to sign in',
                        onTap: () => _runAsync(context, onSignOut),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const _SectionLabel('LOCAL DATA'),
                const SizedBox(height: AppSpacing.sm),
                _ActionGroup(
                  children: <Widget>[
                    _ActionTile(
                      icon: Icons.delete_sweep_outlined,
                      title: 'Remove all local tasks',
                      subtitle:
                          'Permanently delete tasks stored on this device',
                      destructive: true,
                      onTap: () => _run(context, onClearTasks),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Tasks stay on this device. The AI assistant sends messages '
                  'to the Auxilia server only when you use it.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _run(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    Future<void>.microtask(action);
  }

  void _runAsync(BuildContext context, Future<void> Function() action) {
    Navigator.of(context).pop();
    Future<void>.microtask(action);
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.session,
    required this.level,
  });

  final String? displayName;
  final Session? session;
  final int level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final String name = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : AppConstants.appName;
    final String subtitle = session?.email ?? 'Guest workspace';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          AppAvatar(
            name: session?.displayName ?? name,
            email: session?.email,
            size: 48,
            tooltip: 'Profile',
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              'L$level',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({
    required this.totalXp,
    required this.completed,
    required this.unlocked,
    required this.total,
  });

  final int totalXp;
  final int completed;
  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: _Stat(label: 'Total XP', value: '$totalXp'),
            ),
            VerticalDivider(width: 1, color: scheme.outlineVariant),
            Expanded(
              child: _Stat(label: 'Completed', value: '$completed'),
            ),
            VerticalDivider(width: 1, color: scheme.outlineVariant),
            Expanded(
              child: _Stat(label: 'Achievements', value: '$unlocked/$total'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(children: children),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final Color accent = destructive ? scheme.error : scheme.primary;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: AppIconTile(icon: icon, color: accent, size: 36),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: destructive ? scheme.error : scheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
    );
  }
}
