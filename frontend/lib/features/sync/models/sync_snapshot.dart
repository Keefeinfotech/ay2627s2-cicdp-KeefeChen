/// Coarse state of the offline queue, suitable for a status badge.
enum SyncPhase {
  /// No account token is available, so tasks are intentionally local-only.
  localOnly,

  /// Everything in the queue has been accepted by the server.
  synced,

  /// Changes are waiting to be sent.
  pending,

  /// A flush is currently running.
  syncing,

  /// The server could not be reached; changes remain queued.
  offline,

  /// The server rejected a change for a reason other than a conflict.
  failed,

  /// At least one change needs the user's decision.
  conflict,
}

/// Immutable snapshot consumed by the shell status indicator.
class SyncSnapshot {
  const SyncSnapshot({
    this.phase = SyncPhase.localOnly,
    this.pendingCount = 0,
    this.conflictCount = 0,
    this.lastSyncedAt,
    this.message,
  });

  final SyncPhase phase;
  final int pendingCount;
  final int conflictCount;
  final DateTime? lastSyncedAt;
  final String? message;

  bool get hasWork => pendingCount > 0 || conflictCount > 0;

  bool get needsAttention =>
      phase == SyncPhase.failed || phase == SyncPhase.conflict;

  String get label => switch (phase) {
    SyncPhase.localOnly => 'On this device',
    SyncPhase.synced => 'All changes saved',
    SyncPhase.pending =>
      pendingCount == 1 ? '1 change waiting' : '$pendingCount changes waiting',
    SyncPhase.syncing => 'Saving changes…',
    SyncPhase.offline => 'Offline — changes queued',
    SyncPhase.failed => 'Sync needs attention',
    SyncPhase.conflict =>
      conflictCount == 1
          ? '1 conflict to resolve'
          : '$conflictCount conflicts to resolve',
  };

  SyncSnapshot copyWith({
    SyncPhase? phase,
    int? pendingCount,
    int? conflictCount,
    DateTime? lastSyncedAt,
    String? message,
    bool clearMessage = false,
  }) {
    return SyncSnapshot(
      phase: phase ?? this.phase,
      pendingCount: pendingCount ?? this.pendingCount,
      conflictCount: conflictCount ?? this.conflictCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
