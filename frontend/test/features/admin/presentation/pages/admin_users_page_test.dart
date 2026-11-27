import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/admin/data/admin_repository.dart';
import 'package:frontend/features/admin/data/models.dart';
import 'package:frontend/features/admin/presentation/pages/admin_users_page.dart';
import 'package:frontend/features/authentication/models/session.dart';

class _FakeAdminRepo extends AdminRepository {
  _FakeAdminRepo() : super(token: 't');
  @override
  Future<AdminUsersPageData> fetchUsers({
    String? search,
    String? status,
    int page = 1,
    int limit = 10,
  }) async {
    return const AdminUsersPageData(
      items: [
        AdminUserSummary(
          id: '1',
          name: 'Ada',
          email: 'ada@x.com',
          role: 'user',
          status: 'active',
        ),
        AdminUserSummary(
          id: '2',
          name: 'Bob',
          email: 'bob@x.com',
          role: 'admin',
          status: 'disabled',
        ),
      ],
      total: 2,
      page: 1,
      limit: 10,
      totalPages: 1,
    );
  }

  @override
  Future<AdminUserSummary> updateUserStatus(
    String userId,
    String status,
  ) async {
    return AdminUserSummary(
      id: userId,
      name: 'Ada',
      email: 'ada@x.com',
      role: 'user',
      status: status,
    );
  }
}

void main() {
  testWidgets('renders admin users page', (tester) async {
    const session = Session(token: 't', email: 'admin@x.com', role: 'admin');
    await tester.pumpWidget(
      MaterialApp(
        home: AdminUsersPage(session: session, repository: _FakeAdminRepo()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('User management'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });
}
