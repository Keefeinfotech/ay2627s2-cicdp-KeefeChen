import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';
import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/reports/presentation/pages/reports_page.dart';

import '../../../../helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('renders reports page', (tester) async {
    final store = TaskStore(
      repository: InMemoryTaskRepository(
        seed: {
          'u': [makeTask(id: '1', title: 'T', createdAt: DateTime.now())],
        },
      ),
      ownerId: 'u',
    );
    await store.load();
    await tester.pumpWidget(
      MaterialApp(
        home: ReportsPage(ownerId: 'u', store: store),
      ),
    );
    await tester.pumpAndSettle();
    // The page title lives in the shell header; the redesigned page leads with
    // its summary metrics instead of duplicating the title.
    expect(find.text('Completion rate'), findsOneWidget);
    expect(find.text('Still open'), findsOneWidget);
  });

  testWidgets('shows the completion percentage only once', (tester) async {
    final store = TaskStore(
      repository: InMemoryTaskRepository(
        seed: {
          'u': [
            makeTask(
              id: '1',
              title: 'T',
              status: TaskStatus.completed,
              createdAt: DateTime.now(),
              completedAt: DateTime.now(),
            ),
          ],
        },
      ),
      ownerId: 'u',
    );
    await store.load();
    await tester.pumpWidget(
      MaterialApp(
        home: ReportsPage(ownerId: 'u', store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('100%'), findsOneWidget);
    expect(find.text('of 1 in view'), findsOneWidget);
  });
}
