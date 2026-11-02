import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';

class TaskStorageException implements Exception {
  TaskStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Abstraction over local persistence so the storage engine can be replaced
/// without changing task logic or the UI.
abstract class TaskRepository {
  Future<List<Task>> load(String ownerId);

  Future<void> save(String ownerId, List<Task> tasks);

  Future<void> clear(String ownerId);
}

class SharedPreferencesTaskRepository implements TaskRepository {
  SharedPreferencesTaskRepository({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _keyPrefix = 'auxilia.tasks.v2.';
  static const String _legacyKeyPrefix = 'auxilia.tasks.v1.';
  static const int schemaVersion = 2;

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  String _keyFor(String ownerId) => '$_keyPrefix$ownerId';

  String _legacyKeyFor(String ownerId) => '$_legacyKeyPrefix$ownerId';

  @override
  Future<List<Task>> load(String ownerId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_keyFor(ownerId));
    if (raw != null && raw.isNotEmpty) return _decodeEnvelope(raw);

    final legacyRaw = prefs.getString(_legacyKeyFor(ownerId));
    if (legacyRaw == null || legacyRaw.isEmpty) return <Task>[];

    final tasks = _decodeLegacy(legacyRaw);
    await _migrate(ownerId, tasks);
    return tasks;
  }

  @override
  Future<void> save(String ownerId, List<Task> tasks) async {
    final prefs = await _prefs;
    final stored = await prefs.setString(
      _keyFor(ownerId),
      _encodeEnvelope(tasks),
    );
    if (!stored) {
      throw TaskStorageException('Local storage rejected the change');
    }
  }

  @override
  Future<void> clear(String ownerId) async {
    final prefs = await _prefs;
    final removedCurrent = await prefs.remove(_keyFor(ownerId));
    final removedLegacy = await prefs.remove(_legacyKeyFor(ownerId));
    if (!removedCurrent && !removedLegacy) {
      throw TaskStorageException('Local task data could not be removed');
    }
  }

  String _encodeEnvelope(List<Task> tasks) {
    return jsonEncode(<String, dynamic>{
      'version': schemaVersion,
      'tasks': tasks.map((task) => task.toJson()).toList(growable: false),
    });
  }

  List<Task> _decodeEnvelope(String raw) {
    final decoded = _decodeJson(raw);

    if (decoded is! Map) {
      throw TaskStorageException(
        'The local task file has an unexpected format',
      );
    }

    final version = decoded['version'];
    if (version is! int || version < 1) {
      throw TaskStorageException(
        'The local task file is missing its schema version',
      );
    }
    if (version > schemaVersion) {
      throw TaskStorageException(
        'The local task file was created by a newer version of Auxilia',
      );
    }

    final records = decoded['tasks'];
    if (records is! List) {
      throw TaskStorageException(
        'The local task file has an unexpected format',
      );
    }

    return _parseRecords(records);
  }

  List<Task> _decodeLegacy(String raw) {
    final decoded = _decodeJson(raw);
    if (decoded is! List) {
      throw TaskStorageException(
        'The local task file has an unexpected format',
      );
    }
    return _parseRecords(decoded);
  }

  Object? _decodeJson(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      throw TaskStorageException('The local task file is not valid JSON');
    }
  }

  List<Task> _parseRecords(List<dynamic> records) {
    final tasks = <Task>[];
    for (final item in records) {
      final task = Task.tryFromJson(item);
      if (task != null) tasks.add(task);
    }
    return tasks;
  }

  /// Best-effort migration: a failed write must not make existing tasks
  /// disappear from the current session.
  Future<void> _migrate(String ownerId, List<Task> tasks) async {
    try {
      await save(ownerId, tasks);
      await (await _prefs).remove(_legacyKeyFor(ownerId));
    } catch (_) {
      // Keep serving the parsed legacy data; migration retries on next load.
    }
  }
}

/// In-memory repository used by tests and for ephemeral demos.
class InMemoryTaskRepository implements TaskRepository {
  InMemoryTaskRepository({Map<String, List<Task>>? seed}) {
    if (seed != null) {
      seed.forEach((owner, tasks) {
        _data[owner] = List<Task>.of(tasks);
      });
    }
  }

  final Map<String, List<Task>> _data = <String, List<Task>>{};

  bool failOnLoad = false;
  bool failOnSave = false;
  bool failOnClear = false;

  int saveCount = 0;

  @override
  Future<List<Task>> load(String ownerId) async {
    if (failOnLoad) {
      throw TaskStorageException('Simulated read failure');
    }
    return List<Task>.of(_data[ownerId] ?? const <Task>[]);
  }

  @override
  Future<void> save(String ownerId, List<Task> tasks) async {
    saveCount += 1;
    if (failOnSave) {
      throw TaskStorageException('Simulated write failure');
    }
    _data[ownerId] = List<Task>.of(tasks);
  }

  @override
  Future<void> clear(String ownerId) async {
    if (failOnClear) {
      throw TaskStorageException('Simulated clear failure');
    }
    _data.remove(ownerId);
  }
}
