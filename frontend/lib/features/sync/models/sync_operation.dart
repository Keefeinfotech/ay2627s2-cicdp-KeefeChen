import '../../home/models/task.dart';

/// The kind of change that must be replayed against the API.
enum SyncOperationType { create, update, delete }

extension SyncOperationTypeLabel on SyncOperationType {
  String get label => switch (this) {
    SyncOperationType.create => 'Create',
    SyncOperationType.update => 'Update',
    SyncOperationType.delete => 'Delete',
  };
}

/// One durable change in the offline queue.
///
/// The payload is the full local task snapshot, not a partial patch. Replaying
/// a full snapshot makes the queue idempotent and lets the conflict detector
/// compare the local and remote versions field by field.
class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.taskId,
    required this.type,
    required this.payload,
    required this.queuedAt,
    this.baseUpdatedAt,
    this.attempts = 0,
    this.lastError,
  });

  final String id;
  final String taskId;
  final SyncOperationType type;
  final Map<String, dynamic> payload;
  final DateTime queuedAt;

  /// The remote `updatedAt` the local edit was based on. Used to detect a
  /// concurrent remote change before overwriting it.
  final DateTime? baseUpdatedAt;

  final int attempts;
  final String? lastError;

  Task? get task => Task.tryFromJson(payload);

  SyncOperation copyWith({
    String? taskId,
    SyncOperationType? type,
    Map<String, dynamic>? payload,
    DateTime? baseUpdatedAt,
    int? attempts,
    String? lastError,
    bool clearError = false,
  }) {
    return SyncOperation(
      id: id,
      taskId: taskId ?? this.taskId,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      queuedAt: queuedAt,
      baseUpdatedAt: baseUpdatedAt ?? this.baseUpdatedAt,
      attempts: attempts ?? this.attempts,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'taskId': taskId,
    'type': type.name,
    'payload': payload,
    'queuedAt': queuedAt.toUtc().toIso8601String(),
    'baseUpdatedAt': baseUpdatedAt?.toUtc().toIso8601String(),
    'attempts': attempts,
    'lastError': lastError,
  };

  static SyncOperation? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final taskId = raw['taskId'];
    final typeName = raw['type'];
    final payload = raw['payload'];
    final queuedAt = raw['queuedAt'];
    if (id is! String || id.isEmpty) return null;
    if (taskId is! String || taskId.isEmpty) return null;
    if (typeName is! String || payload is! Map || queuedAt is! String) {
      return null;
    }
    SyncOperationType? type;
    for (final candidate in SyncOperationType.values) {
      if (candidate.name == typeName) {
        type = candidate;
        break;
      }
    }
    final parsedQueuedAt = DateTime.tryParse(queuedAt);
    if (type == null || parsedQueuedAt == null) return null;
    return SyncOperation(
      id: id,
      taskId: taskId,
      type: type,
      payload: payload.cast<String, dynamic>(),
      queuedAt: parsedQueuedAt.toLocal(),
      baseUpdatedAt: _date(raw['baseUpdatedAt']),
      attempts: raw['attempts'] is int ? raw['attempts'] as int : 0,
      lastError: raw['lastError'] is String ? raw['lastError'] as String : null,
    );
  }

  static DateTime? _date(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}
