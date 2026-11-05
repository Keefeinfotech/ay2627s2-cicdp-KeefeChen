import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../home/data/task_store.dart';
import '../models/sync_snapshot.dart';
import 'sync_center_dialog.dart';

/// Slim, dismissible-by-resolution status strip shown only when the offline
/// queue needs the user's attention.
///
/// A clean "all changes saved" state deliberately renders nothing so the
/// application chrome stays quiet.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key, required this.store});

  final TaskStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final snapshot = store.syncSnapshot;
        if (snapshot == null) return const SizedBox.shrink();
        if (snapshot.phase == SyncPhase.synced ||
            snapshot.phase == SyncPhase.localOnly) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final bool needsReview = snapshot.phase == SyncPhase.conflict;
        final Color accent = switch (snapshot.phase) {
          SyncPhase.conflict => AppColors.warningAmber,
          SyncPhase.failed => scheme.error,
          SyncPhase.offline => scheme.onSurfaceVariant,
          _ => scheme.primary,
        };
        final IconData icon = switch (snapshot.phase) {
          SyncPhase.syncing => Icons.sync_rounded,
          SyncPhase.conflict => Icons.sync_problem_rounded,
          SyncPhase.failed => Icons.error_outline_rounded,
          SyncPhase.offline => Icons.cloud_off_outlined,
          _ => Icons.cloud_upload_outlined,
        };

        return Material(
          color: accent.withValues(alpha: 0.1),
          child: Semantics(
            liveRegion: true,
            label: 'Synchronization status: ${snapshot.label}',
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  Icon(icon, size: AppSizes.iconSm, color: accent),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      snapshot.message ?? snapshot.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: () => showSyncCenterDialog(context, store),
                    child: Text(needsReview ? 'Review' : 'Details'),
                  ),
                  if (!needsReview)
                    TextButton(
                      onPressed: snapshot.phase == SyncPhase.syncing
                          ? null
                          : store.retrySync,
                      child: const Text('Retry'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
