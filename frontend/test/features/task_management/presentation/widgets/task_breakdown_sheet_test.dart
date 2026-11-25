import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/task_management/data/models/task_breakdown.dart';
import 'package:frontend/features/task_management/presentation/widgets/task_breakdown_sheet.dart';

void main() {
  testWidgets('renders breakdown sheet and approves selected subtasks', (
    tester,
  ) async {
    List<SubtaskSuggestion>? approved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => TaskBreakdownSheet(
                  taskTitle: 'Write report',
                  project: 'Capstone',
                  onApprove: (selected) async {
                    approved = selected;
                    return selected.length;
                  },
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Task breakdown'), findsOneWidget);

    final checkboxes = find.byType(Checkbox);
    if (checkboxes.evaluate().isNotEmpty) {
      await tester.tap(checkboxes.first);
      await tester.pump();
    }

    await tester.tap(find.textContaining('Add').last);
    await tester.pumpAndSettle();
    expect(approved, isNotNull);
  });
}
