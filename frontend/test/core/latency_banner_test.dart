import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/network/latency_monitor.dart';
import 'package:frontend/core/widgets/latency_banner.dart';

import '../helpers.dart';

void main() {
  final monitor = LatencyMonitor.instance;

  setUp(() => monitor.reset());
  tearDown(() => monitor.reset());

  testWidgets('renders nothing while the connection is healthy', (
    tester,
  ) async {
    await tester.pumpWidget(wrapApp(const LatencyBanner()));

    expect(find.byType(LatencyBanner), findsOneWidget);
    expect(find.textContaining('network'), findsNothing);
    expect(find.textContaining('Connection'), findsNothing);
  });

  testWidgets('shows the degraded message when responses slow down', (
    tester,
  ) async {
    for (var i = 0; i < 3; i++) {
      monitor.record(const Duration(milliseconds: 1800));
    }

    await tester.pumpWidget(wrapApp(const LatencyBanner()));

    expect(
      find.text('Slow network - responses are taking longer than usual.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.speed_rounded), findsOneWidget);
  });

  testWidgets('shows the severe message on a very slow response', (
    tester,
  ) async {
    monitor.record(const Duration(milliseconds: 5000));

    await tester.pumpWidget(wrapApp(const LatencyBanner()));

    expect(
      find.text('Connection is very slow - requests may time out.'),
      findsOneWidget,
    );
  });

  testWidgets('dismiss hides the banner until the next degraded episode', (
    tester,
  ) async {
    monitor.record(const Duration(milliseconds: 5000));
    await tester.pumpWidget(wrapApp(const LatencyBanner()));
    expect(find.byTooltip('Dismiss'), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    expect(find.byTooltip('Dismiss'), findsNothing);

    // Recovery re-arms the banner for a future slow spell.
    for (var i = 0; i < LatencyMonitor.windowSize; i++) {
      monitor.record(const Duration(milliseconds: 100));
    }
    monitor.record(const Duration(milliseconds: 5000));
    await tester.pump();
    expect(find.byTooltip('Dismiss'), findsOneWidget);
  });
}
