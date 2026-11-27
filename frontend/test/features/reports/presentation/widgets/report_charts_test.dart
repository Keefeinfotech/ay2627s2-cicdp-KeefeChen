import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/reports/data/models/report_snapshot.dart';
import 'package:frontend/features/reports/presentation/widgets/report_charts.dart';

void main() {
  testWidgets('renders activity chart with points', (tester) async {
    final points = List.generate(
      12,
      (i) => ReportSeriesPoint(
        start: DateTime(2026, 1, i + 1),
        label: 'D${i + 1}',
        completed: i % 3,
        created: (i % 2) + 1,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReportActivityChart(points: points, maxValue: 4),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Created'), findsOneWidget);
    expect(find.textContaining('Busiest'), findsOneWidget);
  });

  testWidgets('renders nothing when empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ReportActivityChart(points: [], maxValue: 0)),
      ),
    );
    expect(find.byType(SizedBox), findsWidgets);
  });
}
