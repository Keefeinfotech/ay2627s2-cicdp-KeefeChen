/*
 * File Name: accessibility_test.dart
 * Description: Accessibility testing using Flutter's built-in guidelines.
 * Checks the three machine-verifiable guidelines on the most-used surfaces:
 *   - textContrastGuideline   (WCAG 2.x contrast >= 4.5 for body text)
 *   - androidTapTargetGuideline (tap targets >= 48x48, Android)
 *   - iOSTapTargetGuideline     (tap targets >= 44x44, iOS)
 *   - labeledTapTargetGuideline (every tappable control has a label)
 *
 * Contrast is theme-level, so these tests run against both the light and
 * dark themes where relevant.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/authentication/screens/login_screen.dart';
import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/home/widgets/task_card.dart';

import '../helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('TaskCard meets all accessibility guidelines', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      wrapApp(
        Scaffold(
          body: TaskCard(
            task: makeTask(
              title: 'Accessible task',
              priority: TaskPriority.high,
              dueDate: DateTime(2026, 12, 1, 9),
            ),
            onToggle: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    handle.dispose();
  });

  testWidgets(
    'Login screen in light theme meets all accessibility guidelines',
    (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(theme: AuxiliaTheme.light(), home: const LoginScreen()),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      handle.dispose();
    },
  );

  testWidgets('Login screen in dark theme meets contrast guideline', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(theme: AuxiliaTheme.dark(), home: const LoginScreen()),
    );
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    handle.dispose();
  });
}
