import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/groups/models/group.dart';
import 'package:frontend/features/groups/presentation/widgets/group_dialogs.dart';

StudyGroup _g() => StudyGroup(
  id: 'g1',
  name: 'Study',
  description: 'd',
  visibility: 'PRIVATE',
  ownerId: 'u',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  role: 'OWNER',
);

void main() {
  testWidgets('group form dialog validates and submits', (tester) async {
    GroupFormResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showGroupFormDialog(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create group'));
    await tester.pump();
    expect(find.textContaining('at least 2 characters'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'My Group');
    await tester.enterText(find.byType(TextFormField).at(1), 'Desc');
    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();
    expect(result?.name, 'My Group');
  });

  testWidgets('group form edit mode', (tester) async {
    GroupFormResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showGroupFormDialog(context, initial: _g());
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Edit group'), findsOneWidget);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(result?.name, 'Study');
  });

  testWidgets('invite dialog validates and submits', (tester) async {
    InviteRequest? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showInviteMemberDialog(context, group: _g());
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Invite to Study'), findsOneWidget);
    await tester.tap(find.text('Create invitation'));
    await tester.pump();
    expect(find.textContaining('valid email'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
    await tester.tap(find.text('Create invitation'));
    await tester.pumpAndSettle();
    expect(result?.email, 'a@b.com');
  });

  testWidgets('invitation token dialog', (tester) async {
    final inv = GroupInvitation(
      invitationId: 'i1',
      groupId: 'g1',
      email: 'a@b.com',
      role: 'MEMBER',
      delivery: 'manual',
      token: 'tok123',
      expiresAt: DateTime(2026, 12, 1),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showInvitationTokenDialog(context, inv),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tok123'), findsWidgets);
  });
}
