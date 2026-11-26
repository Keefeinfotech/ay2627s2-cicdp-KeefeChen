import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/widgets/app_status_badge.dart';
import 'package:frontend/features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';
import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/task_management/presentation/pages/task_management_page.dart';

import '../../../../helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders task management page', (tester) async {
    final store = TaskStore(
      repository: InMemoryTaskRepository(
        seed: {
          'u': [makeTask(id: '1', title: 'T')],
        },
      ),
      ownerId: 'u',
    );
    await store.load();
    await tester.pumpWidget(
      MaterialApp(
        home: TaskManagementPage(ownerId: 'u', store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TaskManagementPage), findsOneWidget);
  });

  testWidgets('header and row cells share the same column grid', (
    tester,
  ) async {
    await _pumpTaskPage(tester, size: const Size(1200, 900));

    double leftOf(Finder finder) => tester.getTopLeft(finder).dx;

    // Each cell starts directly under its header label. Icons were removed
    // from the table cells so the text itself aligns, not just the cell box.
    expect(
      leftOf(find.text('Write report')),
      closeTo(leftOf(find.text('Task Name')), 0.5),
    );
    expect(
      leftOf(find.text('CS101')),
      closeTo(leftOf(find.text('Project')), 0.5),
    );
    expect(
      leftOf(find.byType(StatusBadge)),
      closeTo(leftOf(find.text('Status')), 0.5),
    );
    expect(
      leftOf(find.byType(PriorityBadge)),
      closeTo(leftOf(find.text('Priority')), 0.5),
    );
    expect(
      leftOf(find.text('Dec 15')),
      closeTo(leftOf(find.text('Due Date')), 0.5),
    );

    // Measure the decorated pill itself. The badge widget's element resolves
    // to its Align parent, which always fills the column.
    Rect pillRect(Finder badge) => tester.getRect(
      find.descendant(of: badge, matching: find.byType(DecoratedBox)).first,
    );

    final statusRect = pillRect(find.byType(StatusBadge));
    final priorityRect = pillRect(find.byType(PriorityBadge));
    final dueRect = tester.getRect(find.text('Dec 15'));

    // The pill keeps its intrinsic width instead of stretching to fill the
    // 128px status column.
    expect(statusRect.width, lessThan(128));
    expect(priorityRect.left - statusRect.right, greaterThan(20));
    expect(dueRect.left - priorityRect.right, greaterThanOrEqualTo(16));
    expect(tester.takeException(), isNull);
  });

  testWidgets('table scrolls horizontally at tablet widths', (tester) async {
    await _pumpTaskPage(tester, size: const Size(800, 900));

    final horizontal = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    expect(horizontal, findsOneWidget);
    expect(find.text('Task Name'), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);

    await tester.drag(horizontal, const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses stacked cards on phone widths', (tester) async {
    await _pumpTaskPage(tester, size: const Size(500, 900));

    expect(find.text('Task Name'), findsNothing);
    expect(find.text('Write report'), findsOneWidget);

    final statusRect = tester.getRect(find.byType(StatusBadge));
    final priorityRect = tester.getRect(find.byType(PriorityBadge));
    final separated =
        priorityRect.left >= statusRect.right + 8 ||
        priorityRect.top >= statusRect.bottom + 8;
    expect(separated, isTrue);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpTaskPage(WidgetTester tester, {required Size size}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final store = TaskStore(
    repository: InMemoryTaskRepository(
      seed: {
        'u': [
          makeTask(
            id: '1',
            title: 'Write report',
            course: 'CS101',
            priority: TaskPriority.high,
            status: TaskStatus.completed,
            dueDate: DateTime(2026, 12, 15),
          ),
        ],
      },
    ),
    ownerId: 'u',
  );
  await store.load();
  await tester.pumpWidget(
    MaterialApp(
      home: TaskManagementPage(ownerId: 'u', store: store),
    ),
  );
  await tester.pumpAndSettle();
}
