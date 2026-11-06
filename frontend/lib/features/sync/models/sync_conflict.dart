import '../../home/models/task.dart';
import 'sync_operation.dart';

/// Why the queue could not apply a change automatically.
enum SyncConflictKind {
  /// The task ID already exists remotely with different content.
  createCollision,

  /// The remote task changed after the local edit was based on it.
  updateCollision,

  /// The task was removed remotely while it still had local changes.
  deleteCollision,
}

extension SyncConflictKindLabel on SyncConflictKind {
  String get label => switch (this) {
    SyncConflictKind.createCollision => 'Already exists',
    SyncConflictKind.updateCollision => 'Changed elsewhere',
    SyncConflictKind.deleteCollision => 'Removed elsewhere',
  };
}

/// A queued change that needs the user's decision.
class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.operationId,
    required this.taskId,
    required this.kind,
    required this.localTask,
    required this.detectedAt,
    this.remoteTask,
  });

  final String id;
  final String operationId;
  final String taskId;
  final SyncConflictKind kind;
  final Task localTask;
  final Task? remoteTask;
  final DateTime detectedAt;

  /// The queued operation kind this conflict came from.
  SyncOperationType get operationType => switch (kind) {
    SyncConflictKind.createCollision => SyncOperationType.create,
    SyncConflictKind.updateCollision => SyncOperationType.update,
    SyncConflictKind.deleteCollision => SyncOperationType.update,
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'operationId': operationId,
    'taskId': taskId,
    'kind': kind.name,
    'localTask': localTask.toJson(),
    'remoteTask': remoteTask?.toJson(),
    'detectedAt': detectedAt.toUtc().toIso8601String(),
  };

  static SyncConflict? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final operationId = raw['operationId'];
    final taskId = raw['taskId'];
    final kindName = raw['kind'];
    final localTask = Task.tryFromJson(raw['localTask']);
    final detectedAt = raw['detectedAt'];
    if (id is! String || id.isEmpty) return null;
    if (operationId is! String || taskId is! String) return null;
    if (kindName is! String || localTask == null || detectedAt is! String) {
      return null;
    }
    SyncConflictKind? kind;
    for (final candidate in SyncConflictKind.values) {
      if (candidate.name == kindName) {
        kind = candidate;
        break;
      }
    }
    final parsedDetectedAt = DateTime.tryParse(detectedAt);
    if (kind == null || parsedDetectedAt == null) return null;
    return SyncConflict(
      id: id,
      operationId: operationId,
      taskId: taskId,
      kind: kind,
      localTask: localTask,
      remoteTask: Task.tryFromJson(raw['remoteTask']),
      detectedAt: parsedDetectedAt.toLocal(),
    );
  }
}

/// The user's decision for a conflict.
enum ConflictResolution {
  /// Overwrite the remote copy with the local task.
  keepLocal,

  /// Discard the local change and accept the remote copy.
  keepRemote,
}

/// Outcome of resolving one conflict.
class SyncResolutionResult {
  const SyncResolutionResult({
    required this.success,
    this.remoteTask,
    this.deleteLocal = false,
    this.error,
  });

  final bool success;
  final Task? remoteTask;
  final bool deleteLocal;
  final String? error;
}
