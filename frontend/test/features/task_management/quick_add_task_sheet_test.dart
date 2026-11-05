import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/task_management/presentation/widgets/quick_add_task_sheet.dart';

Widget _host({
  required Future<bool> Function(TaskDraft draft) onSubmit,
  List<String> projects = const <String>[],
  String? initialTitle,
}) {
  return MaterialApp(
    theme: AuxiliaTheme.light(),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => QuickAddTaskSheet(
              onSubmit: onSubmit,
              projects: projects,
              initialTitle: initialTitle,
            ),
          ),
          child: const Text('Open quick add'),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Open quick add'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('parses a natural-language title into the preview', (
    tester,
  ) async {
    TaskDraft? submitted;

    await tester.pumpWidget(
      _host(
        onSubmit: (draft) async {
          submitted = draft;
          return true;
        },
        projects: const <String>['COMP 2101'],
        initialTitle:
            'Submit lab report tomorrow high priority for COMP 2101 #Maths',
      ),
    );
    await _open(tester);

    expect(find.text('Quick add'), findsOneWidget);
    expect(find.text('Parsed preview'), findsOneWidget);
    expect(find.text('Submit lab report'), findsOneWidget);
    expect(find.text('#Maths'), findsOneWidget);

    final highChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'High'),
    );
    expect(highChip.selected, isTrue);
    expect(find.text('COMP 2101'), findsWidgets);

    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.title, 'Submit lab report');
    expect(submitted!.priority, TaskPriority.high);
    expect(submitted!.course, 'COMP 2101');
    expect(submitted!.tags, <String>['Maths']);
    expect(submitted!.dueDate, isNotNull);
  });

  testWidgets('typing updates the preview and tags can be removed', (
    tester,
  ) async {
    TaskDraft? submitted;

    await tester.pumpWidget(
      _host(
        onSubmit: (draft) async {
          submitted = draft;
          return true;
        },
      ),
    );
    await _open(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Describe the task'),
      'Plan revision next Monday #Study',
    );
    await tester.pump();

    final titleField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Title'),
    );
    expect(titleField.controller?.text, contains('Plan revision'));
    expect(find.text('#Study'), findsOneWidget);

    final deleteButton = find.byTooltip('Remove tag Study');
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pump();
    expect(find.text('#Study'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Low'));
    await tester.pump();
    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();

    expect(submitted!.title, contains('Plan revision'));
    expect(submitted!.priority, TaskPriority.low);
    expect(submitted!.tags, isEmpty);
    expect(submitted!.dueDate, isNotNull);
  });

  testWidgets('blocks an empty title before calling the store', (tester) async {
    var calls = 0;

    await tester.pumpWidget(
      _host(
        onSubmit: (_) async {
          calls += 1;
          return true;
        },
      ),
    );
    await _open(tester);

    await tester.tap(find.text('Create task'));
    await tester.pump();

    expect(find.text('Enter a task title before creating it.'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('keeps the sheet open when saving fails', (tester) async {
    await tester.pumpWidget(_host(onSubmit: (_) async => false));
    await _open(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Describe the task'),
      'Read chapter 4',
    );
    await tester.pump();
    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();

    expect(
      find.text('The task could not be saved. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Create task'), findsOneWidget);
  });

  testWidgets('clears a parsed due date on request', (tester) async {
    TaskDraft? submitted;

    await tester.pumpWidget(
      _host(
        onSubmit: (draft) async {
          submitted = draft;
          return true;
        },
        initialTitle: 'Submit essay tomorrow',
      ),
    );
    await _open(tester);

    expect(find.text('Clear due date'), findsOneWidget);
    await tester.tap(find.text('Clear due date'));
    await tester.pump();
    expect(find.text('No due date'), findsOneWidget);

    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();

    expect(submitted!.dueDate, isNull);
  });

  testWidgets('manual title edits stop the parser overwriting them', (
    tester,
  ) async {
    TaskDraft? submitted;

    await tester.pumpWidget(
      _host(
        onSubmit: (draft) async {
          submitted = draft;
          return true;
        },
      ),
    );
    await _open(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Describe the task'),
      'Buy milk tomorrow',
    );
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Buy oat milk',
    );
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Describe the task'),
      'Buy milk next week',
    );
    await tester.pump();

    expect(find.text('Buy oat milk'), findsOneWidget);

    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();

    expect(submitted!.title, 'Buy oat milk');
  });
}
