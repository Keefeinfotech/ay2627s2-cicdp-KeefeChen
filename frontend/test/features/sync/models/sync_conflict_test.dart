import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/sync/models/sync_conflict.dart';
import 'package:frontend/features/sync/models/sync_operation.dart';

import '../../../helpers.dart';

void main() {
  test('SyncConflict serialization and helpers', () {
    final local = makeTask(id: 't1', title: 'Local');
    final remote = makeTask(id: 't1', title: 'Remote');
    final c = SyncConflict(
      id: 'c1',
      operationId: 'o1',
      taskId: 't1',
      kind: SyncConflictKind.updateCollision,
      localTask: local,
      remoteTask: remote,
      detectedAt: DateTime.utc(2026, 1, 1),
    );
    expect(c.operationType, SyncOperationType.update);
    expect(SyncConflictKind.createCollision.label, 'Already exists');
    expect(SyncConflictKind.updateCollision.label, 'Changed elsewhere');
    expect(SyncConflictKind.deleteCollision.label, 'Removed elsewhere');
    final json = c.toJson();
    final parsed = SyncConflict.tryFromJson(json);
    expect(parsed, isNotNull);
    expect(parsed!.id, 'c1');
    expect(parsed.remoteTask!.title, 'Remote');
    expect(SyncConflict.tryFromJson({'id': 'x'}), isNull);

    const res = SyncResolutionResult(success: true, deleteLocal: true);
    expect(res.success, true);
    expect(res.deleteLocal, true);
  });
}
