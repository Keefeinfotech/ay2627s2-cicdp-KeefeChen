import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/authentication/widgets/auth_shell.dart';

void main() {
  testWidgets('renders auth shell', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthShell(
          title: 'Title',
          subtitle: 'Sub',
          footer: Text('footer'),
          child: Text('child'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Sub'), findsOneWidget);
    expect(find.text('child'), findsOneWidget);
    expect(find.text('footer'), findsOneWidget);
  });
}
