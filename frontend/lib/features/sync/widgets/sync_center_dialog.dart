import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../home/data/task_store.dart';
import '../models/sync_conflict.dart';
import '../models/sync_operation.dart';
import '../models/sync_snapshot.dart';

/// Opens the sync centre where queued changes and conflicts are explained and
/// resolved.
Future<void> showSyncCenterDialog(BuildContext context, TaskStore store) {
  return showDialog<void>(
    context: context,
    builder: (_) => SyncCenterDialog(store: store),
  );
}

class SyncCenterDialog extends StatefulWidget {
  const SyncCenterDialog({super.key, required this.store});

  final TaskStore store;

  @override
  State<SyncCenterDialog> createState() => _SyncCenterDialogState();
}

class _SyncCenterDialogState extends State<SyncCenterDialog> {
  String? _busyConflictId;

  Future<void> _resolve(
    SyncConflict conflict,
    ConflictResolution resolution,
  ) async {
    setState(() => _busyConflictId = conflict.id);
    final success = await widget.store.resolveSyncConflict(
      conflict,
      resolution,
    );
    if (!mounted) return;
    setState(() => _busyConflictId = null);
    if (!success) {
      AppSnackBar.error(
        context,
        widget.store.error ?? 'The conflict could not be resolved.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final snapshot =
            widget.store.syncSnapshot ??
            const SyncSnapshot(phase: SyncPhase.localOnly);
        final conflicts = widget.store.syncConflicts;
        final operations = widget.store.pendingOperations;

        return AlertDialog(
          icon: Icon(
            snapshot.phase == SyncPhase.conflict
                ? Icons.sync_problem_rounded
                : Icons.cloud_sync_outlined,
            size: 28,
            color: snapshot.phase == SyncPhase.conflict
                ? AppColors.warningAmber
                : scheme.primary,
          ),
          title: const Text('Sync centre'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    snapshot.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (snapshot.lastSyncedAt != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Last successful sync: '
                      '${_formatTime(snapshot.lastSyncedAt!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (snapshot.message != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      snapshot.message!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (conflicts.isEmpty && operations.isEmpty)
                    _emptyState(context)
                  else ...<Widget>[
                    if (conflicts.isNotEmpty) ...<Widget>[
                      _sectionLabel(context, 'NEEDS A DECISION'),
                      const SizedBox(height: AppSpacing.sm),
                      for (final conflict in conflicts) ...<Widget>[
                        _ConflictCard(
                          conflict: conflict,
                          busy: _busyConflictId == conflict.id,
                          onKeepLocal: () =>
                              _resolve(conflict, ConflictResolution.keepLocal),
                          onKeepRemote: () =>
                              _resolve(conflict, ConflictResolution.keepRemote),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                    if (operations.isNotEmpty) ...<Widget>[
                      _sectionLabel(context, 'WAITING TO SEND'),
                      const SizedBox(height: AppSpacing.sm),
                      for (final operation in operations)
                        _OperationRow(operation: operation),
                    ],
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: snapshot.phase == SyncPhase.syncing
                  ? null
                  : () => widget.store.retrySync(),
              child: const Text('Retry now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.cloud_done_outlined, color: AppColors.successGreen),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Every change has reached the server.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year} '
        '$hour:$minute';
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.busy,
    required this.onKeepLocal,
    required this.onKeepRemote,
  });

  final SyncConflict conflict;
  final bool busy;
  final VoidCallback onKeepLocal;
  final VoidCallback onKeepRemote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final remote = conflict.remoteTask;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningAmber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.warningAmber.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            conflict.localTask.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${conflict.kind.label}. Your version differs from the server.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (remote != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Server: ${remote.title}'
              '${remote.isCompleted ? ' (completed)' : ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              FilledButton.tonal(
                onPressed: busy ? null : onKeepLocal,
                child: const Text('Keep mine'),
              ),
              OutlinedButton(
                onPressed: busy ? null : onKeepRemote,
                child: Text(
                  remote == null ? 'Use server (deleted)' : 'Use server',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({required this.operation});

  final SyncOperation operation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final task = operation.task;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            switch (operation.type) {
              SyncOperationType.create => Icons.add_circle_outline_rounded,
              SyncOperationType.update => Icons.edit_outlined,
              SyncOperationType.delete => Icons.delete_outline_rounded,
            },
            size: AppSizes.iconSm,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  task?.title ?? 'Unknown task',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${operation.type.label}'
                  '${operation.attempts > 0 ? ' · ${operation.attempts} attempts' : ''}'
                  '${operation.lastError == null ? '' : ' · ${operation.lastError}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: operation.lastError == null
                        ? scheme.onSurfaceVariant
                        : scheme.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
