import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/reports/data/models/report_snapshot.dart';
import 'package:frontend/features/reports/presentation/widgets/report_charts.dart';

void main() {
  testWidgets('renders dense activity chart', (tester) async {
    final points = List.generate(
      20,
      (i) => ReportSeriesPoint(
        start: DateTime(2026, 1, i + 1),
        label: 'D${i + 1}',
        completed: i,
        created: i + 1,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: ReportActivityChart(
              points: points,
              maxValue: 21,
              height: 200,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
  });
}
