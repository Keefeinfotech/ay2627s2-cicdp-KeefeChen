import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/admin/data/admin_repository.dart';
import 'package:frontend/features/admin/data/models.dart';
import 'package:frontend/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:frontend/features/authentication/models/session.dart';

class _FakeAdminRepository extends AdminRepository {
  _FakeAdminRepository({this.stats, this.error})
      : super(token: 'demo-token');

  final AdminStats? stats;
  final Object? error;

  @override
  Future<AdminStats> fetchStats() async {
    if (error != null) throw error!;
    return stats!;
  }
}

const Session _adminSession = Session(
  token: 'demo-token',
  email: 'admin@auxilia.demo',
  name: 'Demo Admin',
  role: 'admin',
);

const AdminStats _sampleStats = AdminStats(
  users: AdminUserStats(
    total: 42,
    active: 30,
    disabled: 10,
    pending: 2,
    newLast7Days: 5,
  ),
  tasks: AdminTaskStats(
    total: 130,
    todo: 40,
    inProgress: 20,
    completed: 60,
    archived: 10,
    completionRate: 0.5,
    createdLast7Days: 12,
    completedLast7Days: 9,
  ),
  taskCreationTrend: <AdminTrendPoint>[
    AdminTrendPoint(date: '2026-11-01', count: 3),
    AdminTrendPoint(date: '2026-11-02', count: 4),
  ],
  taskCompletionTrend: <AdminTrendPoint>[
    AdminTrendPoint(date: '2026-11-01', count: 2),
    AdminTrendPoint(date: '2026-11-02', count: 1),
  ],
);

void main() {
  testWidgets('renders the overview sections and stat cards', (tester) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardPage(
          session: _adminSession,
          repository: _FakeAdminRepository(stats: _sampleStats),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Administration'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Registered users'), findsOneWidget);
    expect(find.text('42'), findsWidgets);
    expect(find.text('30'), findsWidgets);
    expect(find.text('Task activity'), findsOneWidget);
    expect(find.text('User accounts'), findsOneWidget);
    expect(find.text('User management'), findsOneWidget);
    expect(find.text('System monitoring'), findsOneWidget);
    expect(find.text('/metrics'), findsOneWidget);
  });

  testWidgets('renders an error state with retry when stats fail', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardPage(
          session: _adminSession,
          repository: _FakeAdminRepository(
            error: AdminException('Insufficient permissions', statusCode: 403),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Insufficient permissions'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
