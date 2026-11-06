import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/app_button.dart';
import 'package:frontend/features/authentication/models/session.dart';
import 'package:frontend/features/groups/data/groups_repository.dart';
import 'package:frontend/features/groups/models/group.dart';
import 'package:frontend/features/groups/presentation/pages/groups_page.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';
import 'package:frontend/features/home/models/task.dart';

import '../../helpers.dart';

const Session _session = Session(
  token: 'token-1',
  email: 'sam@example.com',
  name: 'Sam Lee',
);

StudyGroup _group({
  String id = 'group-1',
  String name = 'COMP 2101 Study Team',
  String role = 'OWNER',
  bool isPublic = false,
}) {
  return StudyGroup(
    id: id,
    name: name,
    description: 'Weekly problem sets',
    visibility: isPublic ? 'PUBLIC' : 'PRIVATE',
    ownerId: 'user-1',
    role: role,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

GroupMember _member({
  String id = 'user-2',
  String name = 'Alex Chen',
  String email = 'alex@example.com',
  String role = 'MEMBER',
}) {
  return GroupMember(
    userId: id,
    role: role,
    status: 'ACTIVE',
    name: name,
    email: email,
    joinedAt: DateTime(2026, 1, 1),
  );
}

class _FakeGroupsRepository extends GroupsRepository {
  _FakeGroupsRepository({
    List<StudyGroup> groups = const <StudyGroup>[],
    List<GroupMember> members = const <GroupMember>[],
  }) : groups = List<StudyGroup>.of(groups),
       membersList = List<GroupMember>.of(members),
       super(token: 'token-1');

  final List<StudyGroup> groups;
  final List<GroupMember> membersList;
  String? createdName;
  String? acceptedToken;

  @override
  Future<List<StudyGroup>> list({int page = 1, int limit = 50}) async {
    return List<StudyGroup>.of(groups);
  }

  @override
  Future<StudyGroup> create({
    required String name,
    String description = '',
    bool isPublic = false,
  }) async {
    createdName = name;
    final group = _group(id: 'group-new', name: name, isPublic: isPublic);
    groups.add(group);
    return group;
  }

  @override
  Future<List<GroupMember>> members(String groupId) async {
    return List<GroupMember>.of(membersList);
  }

  @override
  Future<GroupInvitation> invite({
    required String groupId,
    required String email,
    String role = 'MEMBER',
  }) async {
    return GroupInvitation(
      invitationId: 'invite-1',
      groupId: groupId,
      email: email,
      role: role,
      delivery: 'manual',
      token: 'invite-token-123',
      expiresAt: DateTime(2026, 2, 1),
    );
  }

  @override
  Future<void> accept(String token) async {
    acceptedToken = token;
  }
}

TaskStore _store({List<Task> seed = const <Task>[]}) {
  return TaskStore(
    repository: InMemoryTaskRepository(
      seed: <String, List<Task>>{'owner': seed},
    ),
    ownerId: 'owner',
  );
}

Widget _app(TaskStore store, {GroupsRepository? repository, Session? session}) {
  return MaterialApp(
    theme: AuxiliaTheme.light(),
    home: GroupsPage(store: store, session: session, repository: repository),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('guests see a sign-in gate instead of an empty page', (
    tester,
  ) async {
    final store = _store();

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to use groups'), findsOneWidget);
    expect(find.text('Create group'), findsNothing);
  });

  testWidgets('renders group cards with role and task counts', (tester) async {
    final store = _store(
      seed: <Task>[
        makeTask(
          id: 'task-1',
          groupId: 'group-1',
          assigneeId: 'user-2',
          assigneeName: 'Alex Chen',
        ),
        makeTask(id: 'task-2', groupId: 'group-1'),
      ],
    );
    await store.load();
    final repository = _FakeGroupsRepository(groups: <StudyGroup>[_group()]);

    await tester.pumpWidget(
      _app(store, repository: repository, session: _session),
    );
    await tester.pumpAndSettle();

    expect(find.text('COMP 2101 Study Team'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('2 tasks'), findsOneWidget);
    expect(find.text('1 assigned'), findsOneWidget);
  });

  testWidgets('opens the member roster', (tester) async {
    final store = _store();
    final repository = _FakeGroupsRepository(
      groups: <StudyGroup>[_group()],
      members: <GroupMember>[_member()],
    );

    await tester.pumpWidget(
      _app(store, repository: repository, session: _session),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();

    expect(find.text('COMP 2101 Study Team members'), findsOneWidget);
    expect(find.text('Alex Chen'), findsOneWidget);
    expect(find.text('alex@example.com'), findsOneWidget);
  });

  testWidgets('creates a group and refreshes the list', (tester) async {
    final store = _store();
    final repository = _FakeGroupsRepository();

    await tester.pumpWidget(
      _app(store, repository: repository, session: _session),
    );
    await tester.pumpAndSettle();

    expect(find.text('No groups yet'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppButton, 'Create group'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Algorithms crew');
    await tester.tap(find.widgetWithText(AppButton, 'Create group').last);
    await tester.pumpAndSettle();

    expect(repository.createdName, 'Algorithms crew');
    expect(find.text('Algorithms crew'), findsOneWidget);
  });

  testWidgets('invites a member and shows the one-time code', (tester) async {
    final store = _store();
    final repository = _FakeGroupsRepository(groups: <StudyGroup>[_group()]);

    await tester.pumpWidget(
      _app(store, repository: repository, session: _session),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'teammate@example.com');
    await tester.tap(find.widgetWithText(AppButton, 'Create invitation'));
    await tester.pumpAndSettle();

    expect(find.text('Invitation created'), findsOneWidget);
    expect(find.text('invite-token-123'), findsOneWidget);
    expect(find.textContaining('teammate@example.com'), findsOneWidget);
  });

  testWidgets('joins a group with a pasted invitation code', (tester) async {
    final store = _store();
    final repository = _FakeGroupsRepository(groups: <StudyGroup>[_group()]);

    await tester.pumpWidget(
      _app(store, repository: repository, session: _session),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join with code'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'invitation-code-that-is-long-enough',
    );
    await tester.tap(find.widgetWithText(AppButton, 'Join group'));
    await tester.pumpAndSettle();

    expect(repository.acceptedToken, 'invitation-code-that-is-long-enough');
  });
}
