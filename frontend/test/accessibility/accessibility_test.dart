/*
 * File Name: accessibility_test.dart
 * Description: Machine-checkable WCAG 2.x accessibility guidelines for the
 * most stable, highest-traffic surfaces — the TaskCard and the LoginScreen
 * (light and dark). These were the surfaces the (never-committed) a11y suite
 * covered before the UI rewrite; this suite recreates that coverage.
 *
 *   textContrastGuideline        – W3C AA contrast for text
 *   androidTapTargetGuideline    – 48x48 dp touch targets (Android)
 *   iOSTapTargetGuideline        – 44x44 pt touch targets (iOS)
 *   labeledTapTargetGuideline    – every tappable control carries a label
 *
 * Run:  flutter test test/accessibility
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

  Future<void> pumpLight(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AuxiliaTheme.light(),
        home: Scaffold(body: SizedBox(width: 360, child: child)),
      ),
    );
  }

  testWidgets('TaskCard (light) meets WCAG guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpLight(
      tester,
      TaskCard(
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
    );
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('LoginScreen (light) meets WCAG guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(theme: AuxiliaTheme.light(), home: const LoginScreen()),
    );
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('LoginScreen (dark) meets WCAG guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(theme: AuxiliaTheme.dark(), home: const LoginScreen()),
    );
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
