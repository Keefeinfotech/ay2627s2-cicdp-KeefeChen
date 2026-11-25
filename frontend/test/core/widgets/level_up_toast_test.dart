import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/level_up_toast.dart';

void main() {
  testWidgets('LevelUpToast renders and auto-dismisses', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              LevelUpToast(
                level: 5,
                duration: const Duration(milliseconds: 100),
                onDismiss: () => dismissed = true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('level-up-toast')), findsOneWidget);
    expect(find.text('Level Up!'), findsOneWidget);
    expect(find.text('You reached level 5'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
  });

  testWidgets('LevelUpToast.show inserts overlay entry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => LevelUpToast.show(
                  context,
                  level: 3,
                  duration: const Duration(seconds: 2),
                ),
                child: const Text('show'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Level Up!'), findsOneWidget);
    expect(find.text('You reached level 3'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Level Up!'), findsNothing);
  });
}
