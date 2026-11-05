import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/assistant/screens/ai_chat_screen.dart';
import 'package:frontend/features/authentication/models/session.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const Session _session = Session(
  token: 'token-123',
  email: 'student@example.com',
  name: 'Sam',
);

ApiClient _apiReturning(String body, {int statusCode = 200}) {
  return ApiClient(
    baseUrl: 'https://auxilia.test',
    client: MockClient((_) async {
      return http.Response(
        body,
        statusCode,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }),
  );
}

Future<void> _pumpChat(
  WidgetTester tester, {
  Session? session = _session,
  ApiClient? api,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AuxiliaTheme.light(),
      home: AiChatScreen(session: session, api: api),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the sign-in gate without a session', (tester) async {
    await _pumpChat(tester, session: null);

    expect(find.text('Sign in to use the assistant'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Continue offline'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('sends a message and renders the assistant reply', (
    tester,
  ) async {
    await _pumpChat(
      tester,
      api: _apiReturning(
        jsonEncode(<String, String>{'reply': 'Start with one assignment.'}),
      ),
    );

    expect(find.text('Ask me anything'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Plan my week');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(find.text('Plan my week'), findsOneWidget);
    expect(find.text('Start with one assignment.'), findsOneWidget);
  });

  testWidgets('shows a session-expired message on 401', (tester) async {
    await _pumpChat(
      tester,
      api: _apiReturning(
        jsonEncode(<String, String>{'error': 'Unauthorized'}),
        statusCode: 401,
      ),
    );

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(
      find.text('Your session has expired. Please sign in again.'),
      findsOneWidget,
    );
  });

  testWidgets('suggestions fill the composer', (tester) async {
    await _pumpChat(tester);

    await tester.tap(find.text('Plan my week'));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, contains('Help me plan my study week'));
  });
}
