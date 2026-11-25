import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/calendar/presentation/widgets/calendar_event_editor.dart';

void main() {
  testWidgets('renders event editor and validates', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => CalendarEventEditor(
                  initialDate: DateTime(2026, 1, 1),
                  projects: const ['P1'],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsWidgets);
    await tester.tap(find.text('Add event'));
    await tester.pump();
    expect(find.text('Give the event a short title.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Meeting');
    await tester.tap(find.text('Add event'));
    await tester.pumpAndSettle();
  });
}
