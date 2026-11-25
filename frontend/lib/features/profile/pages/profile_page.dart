import 'package:flutter/material.dart';
import 'package:frontend/features/authentication/models/session.dart';
import 'package:frontend/features/home/data/task_store.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../authentication/data/auth_service.dart';
import '../../authentication/data/session_store.dart';
import '../../home/widgets/achievements_dialog.dart';
import '../../sync/widgets/sync_center_dialog.dart';
import '../data/avatar_store.dart';
import '../widgets/avatar_editor_dialog.dart';

/// Full-page profile and workspace settings surface.
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.store,
    this.session,
    this.displayName,
    this.avatarStore,
    required this.onOpenAssistant,
    this.onOpenProjects,
    this.onOpenGroups,
    this.onOpenReports,
  });

  final TaskStore store;
  final Session? session;
  final String? displayName;
  final AvatarStore? avatarStore;
  final VoidCallback onOpenAssistant;
  final VoidCallback? onOpenProjects;
  final VoidCallback? onOpenGroups;
  final VoidCallback? onOpenReports;

  String get _name {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final sessionName = session?.name?.trim();
    if (sessionName != null && sessionName.isNotEmpty) return sessionName;
    return session == null ? 'Guest workspace' : AppConstants.appName;
  }

  Future<void> _showAchievements(BuildContext context) async {
    await showAchievementsDialog(context, achievements: store.achievements);
  }

  Future<void> _editAvatar(BuildContext context) async {
    final avatarStore = this.avatarStore;
    if (avatarStore == null) return;
    final saved = await showAvatarEditorDialog(
      context,
      avatarStore,
      name: session?.displayName ?? _name,
      email: session?.email,
    );
    if (saved && context.mounted) {
      AppSnackBar.success(context, 'Avatar updated.');
    }
  }

  Future<void> _clearTasks(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Remove all local tasks?',
      message:
          'Every task stored on this device will be permanently deleted. '
          'This cannot be undone.',
      confirmLabel: 'Remove all',
      destructive: true,
      icon: Icons.delete_sweep_outlined,
    );
    if (!confirmed || !context.mounted) return;

    final cleared = await store.clearAll();
    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      cleared
          ? 'All local tasks were removed.'
          : store.error ?? 'Could not remove local tasks.',
      type: cleared ? AppSnackType.success : AppSnackType.error,
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await AuthService().logout();
    } on SessionException catch (err) {
      if (context.mounted) AppSnackBar.error(context, err.message);
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  void _signIn(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            final unlocked = store.achievements
                .where((achievement) => achievement.unlocked)
                .length;
            final totalAchievements = store.achievements.length;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  children: <Widget>[
                    _header(context),
                    const SizedBox(height: 16),
                    _stats(context, unlocked, totalAchievements),
                    const SizedBox(height: 20),
                    _sectionLabel(context, 'WORKSPACE'),
                    const SizedBox(height: AppSpacing.sm),
                    _actionGroup(
                      context,
                      children: <Widget>[
                        if (onOpenProjects != null) ...<Widget>[
                          _ProfileActionTile(
                            icon: Icons.workspaces_outline,
                            title: 'Projects',
                            subtitle: 'Group tasks and track each project',
                            onTap: onOpenProjects!,
                          ),
                          const Divider(height: 1),
                        ],
                        if (onOpenReports != null) ...<Widget>[
                          _ProfileActionTile(
                            icon: Icons.insights_outlined,
                            title: 'Reports',
                            subtitle:
                                'Review completion, priority and workload',
                            onTap: onOpenReports!,
                          ),
                          const Divider(height: 1),
                        ],
                        if (onOpenGroups != null) ...<Widget>[
                          _ProfileActionTile(
                            icon: Icons.groups_outlined,
                            title: 'Groups',
                            subtitle:
                                'Invite teammates and assign shared tasks',
                            onTap: onOpenGroups!,
                          ),
                          const Divider(height: 1),
                        ],
                        _ProfileActionTile(
                          icon: Icons.emoji_events_outlined,
                          title: 'Achievements',
                          subtitle: '$unlocked of $totalAchievements unlocked',
                          onTap: () => _showAchievements(context),
                        ),
                        if (store.isSyncAware) ...<Widget>[
                          const Divider(height: 1),
                          _ProfileActionTile(
                            icon: Icons.cloud_sync_outlined,
                            title: 'Sync centre',
                            subtitle:
                                store.syncSnapshot?.label ??
                                'Review queued changes and conflicts',
                            onTap: () => showSyncCenterDialog(context, store),
                          ),
                        ],
                        const Divider(height: 1),
                        _ProfileActionTile(
                          icon: Icons.auto_awesome_outlined,
                          title: 'AI assistant',
                          subtitle: session == null
                              ? 'Sign in to start a conversation'
                              : 'Plan, summarise and change tasks',
                          onTap: onOpenAssistant,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _sectionLabel(context, 'ACCOUNT'),
                    const SizedBox(height: AppSpacing.sm),
                    _actionGroup(
                      context,
                      children: <Widget>[
                        if (avatarStore != null) ...<Widget>[
                          _ProfileActionTile(
                            icon: Icons.face_retouching_natural_outlined,
                            title: 'Customize avatar',
                            subtitle: 'Choose an accent colour and a glyph or initials',
                            onTap: () => _editAvatar(context),
                          ),
                          const Divider(height: 1),
                        ],
                        if (session == null)
                          _ProfileActionTile(
                            icon: Icons.login_rounded,
                            title: 'Sign in',
                            subtitle: 'Unlock the AI assistant and cloud-backed account',
                            onTap: () => _signIn(context),
                          )
                        else
                          _ProfileActionTile(
                            icon: Icons.logout_rounded,
                            title: 'Sign out',
                            subtitle: 'Keep local tasks and return to the sign-in screen',
                            onTap: () => _signOut(context),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _sectionLabel(context, 'LOCAL DATA'),
                    const SizedBox(height: AppSpacing.sm),
                    _actionGroup(
                      context,
                      children: <Widget>[
                        _ProfileActionTile(
                          icon: Icons.delete_sweep_outlined,
                          title: 'Remove all local tasks',
                          subtitle:
                              'Permanently delete tasks stored on this device',
                          destructive: true,
                          onTap: () => _clearTasks(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _sectionLabel(context, 'ABOUT AUXILIA'),
                    const SizedBox(height: AppSpacing.sm),
                    _actionGroup(
                      context,
                      children: <Widget>[
                        _ProfileActionTile(
                          icon: Icons.info_outline_rounded,
                          title: 'Introduction',
                          subtitle: 'Revisit the Auxilia overview',
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.onboarding,
                            arguments: const OnboardingArgs(
                              returnToPrevious: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Tasks stay on this device. The AI assistant sends '
                      'messages to the Auxilia server only when you use it.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final level = store.levelProgress.level;
    final isDark = scheme.brightness == Brightness.dark;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : scheme.outlineVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Row(
            children: <Widget>[
              if (avatarStore == null)
                AppAvatar(
                  name: session?.displayName ?? _name,
                  email: session?.email,
                  size: 56,
                  tooltip: 'Profile',
                )
              else
                AnimatedBuilder(
                  animation: avatarStore!,
                  builder: (context, _) => AppAvatar(
                    name: session?.displayName ?? _name,
                    email: session?.email,
                    size: 56,
                    style: avatarStore!.style,
                    tooltip: 'Customize avatar',
                    onTap: () => _editAvatar(context),
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session?.email ?? 'Tasks stored on this device',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        StatusBadge(
                          label: 'Level $level',
                          color: scheme.primary,
                          icon: Icons.workspace_premium_outlined,
                        ),
                        StatusBadge(
                          label: session == null ? 'Local workspace' : 'Signed in',
                          color: session == null
                              ? scheme.onSurfaceVariant
                              : AppColors.successGreen,
                          icon: session == null
                              ? Icons.phone_iphone_rounded
                              : Icons.verified_user_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          final progress = Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ProgressRing(
                  value: store.levelProgress.fraction,
                  diameter: 44,
                  strokeWidth: 6,
                  color: scheme.primary,
                  center: Text(
                    '${(store.levelProgress.fraction * 100).round()}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'to level ${level + 1}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );

          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [identity, const SizedBox(height: 16), progress],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: identity),
              const SizedBox(width: 16),
              progress,
            ],
          );
        },
      ),
    );
  }

  Widget _stats(BuildContext context, int unlocked, int total) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ProfileStatCard(
            label: 'Total XP',
            value: '${store.levelProgress.totalXp}',
            icon: Icons.bolt_rounded,
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ProfileStatCard(
            label: 'Completed',
            value: '${store.completedCount}',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ProfileStatCard(
            label: 'Achievements',
            value: '$unlocked/$total',
            icon: Icons.emoji_events_outlined,
            color: const Color(0xFF6366F1),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _actionGroup(BuildContext context, {required List<Widget> children}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
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
      leading: _ProfileIconTile(icon: icon, color: accent, size: 36),
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

class _ProfileIconTile extends StatelessWidget {
  const _ProfileIconTile({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, size: size, color: color),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final border = isDark ? Colors.white.withValues(alpha: 0.08) : scheme.outlineVariant;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
