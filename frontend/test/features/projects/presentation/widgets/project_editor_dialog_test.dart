import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/projects/data/models/project.dart';
import 'package:frontend/features/projects/presentation/widgets/project_editor_dialog.dart';

void main() {
  testWidgets('creates a project draft', (tester) async {
    ProjectDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showProjectEditorDialog(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('New project'), findsOneWidget);

    await tester.tap(find.text('Create project'));
    await tester.pump();
    expect(find.text('Give the project a name.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'My Project');
    await tester.enterText(find.byType(TextFormField).at(1), 'Desc');
    await tester.tap(find.text('Create project'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'My Project');
    expect(result!.description, 'Desc');
  });

  testWidgets('edits an existing project', (tester) async {
    final initial = Project(
      id: 'p1',
      name: 'Old',
      description: 'D',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      deadline: DateTime(2026, 12, 1),
    );
    ProjectDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showProjectEditorDialog(
                  context,
                  initial: initial,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Edit project'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear project deadline'));
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(result!.deadline, isNull);
  });
}
