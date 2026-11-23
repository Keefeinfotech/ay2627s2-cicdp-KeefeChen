import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/app_navigation.dart';

const AppNavDestination _home = AppNavDestination(
  label: 'Home',
  icon: Icons.home_outlined,
  selectedIcon: Icons.home_rounded,
);

double _contrast(Color a, Color b) {
  final double l1 = a.computeLuminance();
  final double l2 = b.computeLuminance();
  final double lighter = l1 > l2 ? l1 : l2;
  final double darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  for (final MapEntry<String, ThemeData> entry in <String, ThemeData>{
    'light': AuxiliaTheme.light(),
    'dark': AuxiliaTheme.dark(),
  }.entries) {
    testWidgets('${entry.key} theme: selected item is legible', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: entry.value,
          home: Scaffold(
            body: AppSidebar(
              destinations: const <AppNavDestination>[_home],
              selectedIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      final Finder labelFinder = find.text('Home');
      final Text label = tester.widget<Text>(labelFinder);
      final Icon icon = tester.widget<Icon>(find.byIcon(Icons.home_rounded));
      final Color selectedColor = entry.value.colorScheme.onPrimaryContainer;

      // Icon and label share one state colour instead of fighting each other.
      expect(label.style?.color, isNotNull);
      expect(icon.color, label.style!.color);
      expect(label.style!.color, selectedColor);

      // WCAG AA for normal text on the filled selected pill.
      expect(
        _contrast(
          label.style!.color!,
          entry.value.colorScheme.primaryContainer,
        ),
        greaterThanOrEqualTo(4.5),
      );

      // The filled pill, bolder text and filled icon already convey state;
      // there must be no redundant trailing dot.
      final Finder item = find
          .ancestor(of: labelFinder, matching: find.byType(Material))
          .first;
      expect(
        find.descendant(
          of: item,
          matching: find.byWidgetPredicate(
            (Widget widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
          ),
        ),
        findsNothing,
      );
    });
  }
}
