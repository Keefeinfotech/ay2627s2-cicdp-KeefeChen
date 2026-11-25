import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/sync/models/sync_snapshot.dart';

void main() {
  test('SyncSnapshot labels and copyWith', () {
    const a = SyncSnapshot();
    expect(a.phase, SyncPhase.localOnly);
    expect(a.label, 'On this device');
    expect(a.hasWork, false);
    expect(a.needsAttention, false);

    const b = SyncSnapshot(phase: SyncPhase.pending, pendingCount: 1);
    expect(b.label, '1 change waiting');
    expect(b.hasWork, true);
    const b2 = SyncSnapshot(phase: SyncPhase.pending, pendingCount: 2);
    expect(b2.label, '2 changes waiting');
    const c = SyncSnapshot(phase: SyncPhase.syncing);
    expect(c.label, 'Saving changes…');
    const d = SyncSnapshot(phase: SyncPhase.offline);
    expect(d.label, 'Offline — changes queued');
    const e = SyncSnapshot(phase: SyncPhase.failed);
    expect(e.needsAttention, true);
    const f = SyncSnapshot(phase: SyncPhase.conflict, conflictCount: 1);
    expect(f.label, '1 conflict to resolve');
    expect(f.needsAttention, true);
    const f2 = SyncSnapshot(phase: SyncPhase.conflict, conflictCount: 3);
    expect(f2.label, '3 conflicts to resolve');
    const g = SyncSnapshot(phase: SyncPhase.synced);
    expect(g.label, 'All changes saved');

    final h = g.copyWith(
      phase: SyncPhase.failed,
      message: 'err',
      pendingCount: 1,
      conflictCount: 2,
    );
    expect(h.phase, SyncPhase.failed);
    expect(h.message, 'err');
    final i = h.copyWith(clearMessage: true);
    expect(i.message, null);
  });
}
