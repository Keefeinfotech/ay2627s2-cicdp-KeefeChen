import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';
import 'package:frontend/features/projects/presentation/pages/projects_page.dart';

import '../../../../helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('renders projects page', (tester) async {
    final store = TaskStore(
      repository: InMemoryTaskRepository(
        seed: {
          'u': [makeTask(id: '1', title: 'T', course: 'Capstone')],
        },
      ),
      ownerId: 'u',
    );
    await store.load();
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectsPage(ownerId: 'u', store: store),
      ),
    );
    await tester.pumpAndSettle();
    // The page title lives in the shell header; the page itself exposes its
    // primary action and the seeded project card.
    expect(find.text('New project'), findsOneWidget);
    expect(find.text('Capstone'), findsWidgets);
  });
}
