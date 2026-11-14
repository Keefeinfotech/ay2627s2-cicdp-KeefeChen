import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/sync_conflict.dart';
import '../models/sync_operation.dart';

/// Durable state for the offline queue.
class SyncQueueData {
  const SyncQueueData({
    this.operations = const <SyncOperation>[],
    this.conflicts = const <SyncConflict>[],
    this.lastSyncedAt,
  });

  final List<SyncOperation> operations;
  final List<SyncConflict> conflicts;
  final DateTime? lastSyncedAt;

  bool get isEmpty => operations.isEmpty && conflicts.isEmpty;

  SyncQueueData copyWith({
    List<SyncOperation>? operations,
    List<SyncConflict>? conflicts,
    DateTime? lastSyncedAt,
  }) {
    return SyncQueueData(
      operations: operations ?? this.operations,
      conflicts: conflicts ?? this.conflicts,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

/// Persists the queue and conflicts in SharedPreferences.
///
/// The queue is intentionally separate from the task cache: a corrupt queue
/// must never make the user's tasks unreadable, and a corrupt cache must never
/// make pending changes disappear.
class SyncQueueStore {
  SyncQueueStore({this._preferences});

  static const String _keyPrefix = 'auxilia.sync.queue.v1.';
  static const int schemaVersion = 1;

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  String _keyFor(String ownerId) => '$_keyPrefix$ownerId';

  Future<SyncQueueData> load(String ownerId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_keyFor(ownerId));
    if (raw == null || raw.isEmpty) return const SyncQueueData();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const SyncQueueData();
      final version = decoded['version'];
      if (version is! int || version > schemaVersion) {
        return const SyncQueueData();
      }

      final operationsRaw = decoded['operations'];
      final conflictsRaw = decoded['conflicts'];
      final operations = <SyncOperation>[];
      if (operationsRaw is List) {
        for (final item in operationsRaw) {
          final operation = SyncOperation.tryFromJson(item);
          if (operation != null) operations.add(operation);
        }
      }
      final conflicts = <SyncConflict>[];
      if (conflictsRaw is List) {
        for (final item in conflictsRaw) {
          final conflict = SyncConflict.tryFromJson(item);
          if (conflict != null) conflicts.add(conflict);
        }
      }

      return SyncQueueData(
        operations: operations,
        conflicts: conflicts,
        lastSyncedAt: _parseDate(decoded['lastSyncedAt']),
      );
    } on FormatException {
      // A malformed queue is discarded rather than blocking the app. The task
      // cache still holds the user's data.
      return const SyncQueueData();
    }
  }

  Future<void> save(String ownerId, SyncQueueData data) async {
    final prefs = await _prefs;
    await prefs.setString(
      _keyFor(ownerId),
      jsonEncode(<String, dynamic>{
        'version': schemaVersion,
        'operations': data.operations
            .map((operation) => operation.toJson())
            .toList(growable: false),
        'conflicts': data.conflicts
            .map((conflict) => conflict.toJson())
            .toList(growable: false),
        'lastSyncedAt': data.lastSyncedAt?.toUtc().toIso8601String(),
      }),
    );
  }

  Future<void> clear(String ownerId) async {
    final prefs = await _prefs;
    await prefs.remove(_keyFor(ownerId));
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}
