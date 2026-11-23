import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/widgets/app_snackbar.dart';

void main() {
  setUp(AppSnackBar.dismiss);
  tearDown(AppSnackBar.dismiss);

  Future<void> pumpHost(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: () =>
                        AppSnackBar.error(context, 'Something went wrong'),
                    child: const Text('show error'),
                  ),
                  ElevatedButton(
                    onPressed: () => AppSnackBar.show(
                      context,
                      'Saved',
                      type: AppSnackType.success,
                      action: SnackBarAction(label: 'Undo', onPressed: () {}),
                    ),
                    child: const Text('show success with action'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('toast is anchored near the top and does not stretch', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.text('show error'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Something went wrong'), findsOneWidget);
    final toast = tester.getRect(find.byKey(const Key('app-toast')));
    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;

    expect(toast.top, lessThan(120), reason: 'toast must sit at the top');
    expect(
      toast.width,
      lessThan(screenWidth - 100),
      reason: 'toast must not stretch across the page',
    );
    expect(toast.left, greaterThan(0));
  });

  testWidgets('a new toast replaces the previous one', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.text('show error'));
    await tester.pump();
    await tester.tap(find.text('show success with action'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Something went wrong'), findsNothing);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('action label is rendered inline with the message', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.text('show success with action'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final message = tester.getRect(find.text('Saved'));
    final action = tester.getRect(find.text('Undo'));
    final toast = tester.getRect(find.byKey(const Key('app-toast')));

    expect(action.top, greaterThanOrEqualTo(toast.top));
    expect(action.bottom, lessThanOrEqualTo(toast.bottom));
    expect(action.left, greaterThan(message.right));
  });
}
