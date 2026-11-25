import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/projects/data/models/project.dart';
import 'package:frontend/features/projects/presentation/widgets/project_card.dart';

import '../../../../helpers.dart';

void main() {
  testWidgets('renders project card with progress and menu', (tester) async {
    var tapped = false;
    var menu = false;
    final project = Project(
      id: 'p1',
      name: 'Capstone',
      description: 'Final year project',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
      deadline: DateTime(2026, 12, 1),
      tasks: [
        makeTask(id: 't1', title: 'A', status: TaskStatus.completed),
        makeTask(
          id: 't2',
          title: 'B',
          status: TaskStatus.pending,
          dueDate: DateTime(2025, 1, 1),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectCard(
            project: project,
            onTap: () => tapped = true,
            onMenu: () => menu = true,
          ),
        ),
      ),
    );

    expect(find.text('Capstone'), findsOneWidget);
    expect(find.text('Final year project'), findsOneWidget);
    expect(find.textContaining('overdue'), findsOneWidget);

    await tester.tap(find.text('Capstone'));
    await tester.pump();
    expect(tapped, isTrue);

    await tester.tap(find.byTooltip('Project actions for Capstone'));
    await tester.pump();
    expect(menu, isTrue);
  });
}
