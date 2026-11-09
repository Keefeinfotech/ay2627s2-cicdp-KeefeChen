import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/widgets/app_video_background.dart';

Widget _app({bool reduceMotion = true}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: const AppVideoBackground(
        assetPath: 'assets/videos/auth_bg.mp4',
        child: Scaffold(body: Center(child: Text('Sign in form'))),
      ),
    ),
  );
}

void main() {
  testWidgets('always renders the brand fallback and its child', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    expect(find.text('Sign in form'), findsOneWidget);
    final fallback = tester.widget<ColoredBox>(
      find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == AppColors.deepNavy,
      ),
    );
    expect(fallback.color, AppColors.deepNavy);
  });

  testWidgets('skips video entirely when motion is reduced', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // The form Scaffold also uses a Stack internally; crucially there is no
    // VideoPlayer because the video path was skipped entirely.
    expect(find.byType(VideoPlayer), findsNothing);
    expect(find.byType(Stack), findsWidgets);
  });

  testWidgets('ignores lifecycle changes before a controller exists', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('Sign in form'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposes cleanly when the page is removed', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    expect(find.byType(AppVideoBackground), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
