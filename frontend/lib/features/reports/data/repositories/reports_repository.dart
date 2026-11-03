import '../../../home/models/task.dart';
import '../../domain/usecases/build_report_snapshot.dart';
import '../models/report_snapshot.dart';

/// Produces report snapshots from task data without persisting derived values.
class ReportsRepository {
  const ReportsRepository({this.buildSnapshot = const BuildReportSnapshot()});

  final BuildReportSnapshot buildSnapshot;

  ReportSnapshot load({
    required List<Task> tasks,
    required ReportPeriod period,
    DateTime? now,
  }) {
    return buildSnapshot(tasks: tasks, period: period, now: now);
  }
}
