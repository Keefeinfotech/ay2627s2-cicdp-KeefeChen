import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/home/data/task_repository.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('persists tasks across repository instances', () async {
    final first = SharedPreferencesTaskRepository();
    await first.save('owner', <Task>[makeTask(title: 'Persisted')]);

    final second = SharedPreferencesTaskRepository();
    final loaded = await second.load('owner');

    expect(loaded, hasLength(1));
    expect(loaded.single.title, 'Persisted');
  });

  test('keeps each owner separate', () async {
    final repository = SharedPreferencesTaskRepository();
    await repository.save('a', <Task>[makeTask(id: 'a1', title: 'A')]);
    await repository.save('b', <Task>[makeTask(id: 'b1', title: 'B')]);

    expect((await repository.load('a')).single.title, 'A');
    expect((await repository.load('b')).single.title, 'B');
  });

  test('returns an empty list when nothing is stored', () async {
    final repository = SharedPreferencesTaskRepository();
    expect(await repository.load('new-owner'), isEmpty);
  });

  test('throws a readable error for corrupt JSON', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auxilia.tasks.v1.owner': 'not-json',
    });
    final repository = SharedPreferencesTaskRepository();

    await expectLater(
      repository.load('owner'),
      throwsA(isA<TaskStorageException>()),
    );
  });

  test('throws when the stored shape is not a list', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auxilia.tasks.v1.owner': jsonEncode(<String, dynamic>{'tasks': []}),
    });
    final repository = SharedPreferencesTaskRepository();

    await expectLater(
      repository.load('owner'),
      throwsA(isA<TaskStorageException>()),
    );
  });

  test('skips individual malformed records', () async {
    final valid = makeTask(title: 'Valid');
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auxilia.tasks.v1.owner': jsonEncode(<dynamic>[
        valid.toJson(),
        <String, dynamic>{'id': 'broken'},
        'not-a-record',
      ]),
    });

    final loaded = await SharedPreferencesTaskRepository().load('owner');

    expect(loaded, hasLength(1));
    expect(loaded.single.title, 'Valid');
  });

  test('writes a versioned envelope', () async {
    final repository = SharedPreferencesTaskRepository();
    await repository.save('owner', <Task>[makeTask(title: 'Stored')]);

    final prefs = await SharedPreferences.getInstance();
    final decoded =
        jsonDecode(prefs.getString('auxilia.tasks.v2.owner')!)
            as Map<String, dynamic>;

    expect(decoded['version'], SharedPreferencesTaskRepository.schemaVersion);
    expect(decoded['tasks'], hasLength(1));
  });

  test('migrates legacy v1 data to the v2 schema once', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auxilia.tasks.v1.owner': jsonEncode(<dynamic>[
        makeTask(title: 'Legacy', course: 'COMP 2101').toJson(),
      ]),
    });
    final repository = SharedPreferencesTaskRepository();

    final loaded = await repository.load('owner');

    expect(loaded.single.title, 'Legacy');
    expect(loaded.single.course, 'COMP 2101');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auxilia.tasks.v2.owner'), isNotNull);
    expect(prefs.getString('auxilia.tasks.v1.owner'), isNull);

    final reloaded = await repository.load('owner');
    expect(reloaded.single.title, 'Legacy');
  });

  test('rejects data written by a newer schema version', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auxilia.tasks.v2.owner': jsonEncode(<String, dynamic>{
        'version': SharedPreferencesTaskRepository.schemaVersion + 1,
        'tasks': <dynamic>[],
      }),
    });
    final repository = SharedPreferencesTaskRepository();

    await expectLater(
      repository.load('owner'),
      throwsA(
        isA<TaskStorageException>().having(
          (err) => err.message,
          'message',
          contains('newer version'),
        ),
      ),
    );
  });

  test('clears both current and legacy keys', () async {
    final repository = SharedPreferencesTaskRepository();
    await repository.save('owner', <Task>[makeTask(title: 'Current')]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'auxilia.tasks.v1.owner',
      jsonEncode(<dynamic>[makeTask(title: 'Legacy').toJson()]),
    );

    await repository.clear('owner');

    expect(prefs.getString('auxilia.tasks.v2.owner'), isNull);
    expect(prefs.getString('auxilia.tasks.v1.owner'), isNull);
  });

  test('clears stored tasks', () async {
    final repository = SharedPreferencesTaskRepository();
    await repository.save('owner', <Task>[makeTask()]);
    await repository.clear('owner');

    expect(await repository.load('owner'), isEmpty);
  });
}
