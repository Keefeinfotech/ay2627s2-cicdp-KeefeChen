import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/authentication/models/session.dart';
import 'package:frontend/features/groups/data/groups_repository.dart';
import 'package:frontend/features/groups/models/group.dart';
import 'package:frontend/features/groups/presentation/pages/groups_page.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';

import '../../../../helpers.dart';

class _FakeGroupsRepo extends GroupsRepository {
  _FakeGroupsRepo() : super(token: 't');
  @override
  Future<List<StudyGroup>> list({int page = 1, int limit = 50}) async => [
    StudyGroup(
      id: 'g1',
      name: 'Study Group',
      description: 'Desc',
      visibility: 'PRIVATE',
      ownerId: 'u',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      role: 'OWNER',
    ),
  ];
}

void main() {
  testWidgets('renders groups page', (tester) async {
    final store = TaskStore(
      repository: InMemoryTaskRepository(
        seed: {
          'u': [makeTask(id: '1')],
        },
      ),
      ownerId: 'u',
    );
    await store.load();
    const session = Session(token: 't', email: 'a@b.com');
    await tester.pumpWidget(
      MaterialApp(
        home: GroupsPage(
          store: store,
          session: session,
          repository: _FakeGroupsRepo(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GroupsPage), findsOneWidget);
  });
}
