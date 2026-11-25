import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/features/calendar/data/calendar_preferences_store.dart';
import 'package:frontend/features/calendar/presentation/pages/calendar_page.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';

import '../../../../helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders calendar page', (tester) async {
    final store = TaskStore(
      repository: InMemoryTaskRepository(
        seed: {
          'u': [
            makeTask(
              id: 't1',
              title: 'Task',
              dueDate: DateTime.now().add(const Duration(days: 1)),
            ),
          ],
        },
      ),
      ownerId: 'u',
    );
    await store.load();
    final prefs = CalendarPreferencesStore(ownerId: 'u');
    await prefs.load();

    await tester.pumpWidget(
      MaterialApp(
        home: CalendarPage(ownerId: 'u', store: store, preferencesStore: prefs),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarPage), findsOneWidget);
  });
}
