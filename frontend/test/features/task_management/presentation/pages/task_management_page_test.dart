import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';
import 'package:frontend/features/task_management/presentation/pages/task_management_page.dart';

import '../../../../helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('renders task management page', (tester) async {
    final store = TaskStore(
      repository: InMemoryTaskRepository(
        seed: {
          'u': [makeTask(id: '1', title: 'T')],
        },
      ),
      ownerId: 'u',
    );
    await store.load();
    await tester.pumpWidget(
      MaterialApp(
        home: TaskManagementPage(ownerId: 'u', store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TaskManagementPage), findsOneWidget);
  });
}
