/*
 * File Name: golden_test.dart
 * Description: Visual (golden image) testing for Auxilia's most stable,
 * high-traffic widget — TaskCard. Failing goldens indicate an unintended
 * visual regression in spacing, typography, colors or iconography.
 *
 * Regenerate baselines intentionally with:
 *   flutter test --update-goldens test/visual/golden_test.dart
 *
 * Any baseline change must be justified in the PR that updates it.
 * Goldens are written to test/goldens/.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/home/widgets/task_card.dart';

import '../helpers.dart';

void main() {
  testWidgets('TaskCard (pending, high priority) matches golden', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapApp(
        Scaffold(
          body: SizedBox(
            width: 360,
            child: TaskCard(
              task: makeTask(
                title: 'Submit report',
                course: 'COMP 2101',
                priority: TaskPriority.high,
                createdAt: DateTime(2026, 1, 1, 9),
                updatedAt: DateTime(2026, 1, 1, 9),
              ),
              onToggle: () {},
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(TaskCard),
      matchesGoldenFile('goldens/task_card_pending_high.png'),
    );
  });

  testWidgets('TaskCard (completed) matches golden', (tester) async {
    await tester.pumpWidget(
      wrapApp(
        Scaffold(
          body: SizedBox(
            width: 360,
            child: TaskCard(
              task: makeTask(
                title: 'Finished essay',
                priority: TaskPriority.medium,
                status: TaskStatus.completed,
                completedAt: DateTime(2026, 1, 1, 10),
                createdAt: DateTime(2026, 1, 1, 9),
                updatedAt: DateTime(2026, 1, 1, 10),
                xpAwarded: true,
              ),
              onToggle: () {},
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(TaskCard),
      matchesGoldenFile('goldens/task_card_completed.png'),
    );
  });
}
