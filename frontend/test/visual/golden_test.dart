/*
 * File Name: golden_test.dart
 * Description: Visual (golden image) testing for Auxilia's most stable,
 * high-traffic widget — TaskCard. Failing goldens indicate an unintended
 * visual regression in spacing, typography, colors or iconography.
 *
 * Regenerate baselines intentionally with:
 *   flutter test test/visual --update-goldens
 *
 * Any baseline change must be justified in the PR that updates it.
 * Baselines live in test/visual/goldens/.
 *
 * Determinism notes (why these two tests do not flake):
 * - All timestamps are fixed; no assertion depends on the wall clock.
 * - `pumpAndSettle()` drains the AnimatedContainer and any implicitly
 *   animated children before the image is captured.
 * - Neither task is overdue (no `dueDate`), so no time-dependent branch of
 *   the widget can diverge between runs.
 * - Goldens are generated with Flutter 3.47.8 (the version pinned in CI).
 *   If CI (ubuntu-latest) disagrees with local (Windows) baselines,
 *   regenerate the baselines inside the CI runner and commit those.
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
                status: TaskStatus.pending,
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
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(TaskCard),
      matchesGoldenFile('goldens/task_card_completed.png'),
    );
  });
}
