import 'package:flutter/foundation.dart';

import '../../../home/data/task_store.dart';
import '../../data/models/report_snapshot.dart';
import '../../data/repositories/reports_repository.dart';

/// Coordinates the selected reporting window with live task changes.
class ReportsController extends ChangeNotifier {
  ReportsController({
    required this.store,
    this._repository = const ReportsRepository(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    store.addListener(_storeChanged);
    _snapshot = _build();
  }

  final TaskStore store;
  final ReportsRepository _repository;
  final DateTime Function() _clock;

  ReportPeriod _period = ReportPeriod.week;
  late ReportSnapshot _snapshot;

  ReportPeriod get period => _period;
  ReportSnapshot get snapshot => _snapshot;
  bool get isLoading => store.isLoading && !store.hasLoaded;
  bool get hasLoaded => store.hasLoaded;
  String? get error => store.error;

  Future<void> initialize() async {
    if (!store.hasLoaded && !store.isLoading) {
      await store.load();
    }
    _rebuild();
  }

  Future<void> refresh() async {
    await store.retry();
    _rebuild();
  }

  void setPeriod(ReportPeriod period) {
    if (_period == period) return;
    _period = period;
    _rebuild(notify: true);
  }

  void clearError() {
    store.clearError();
  }

  void _storeChanged() {
    _rebuild(notify: true);
  }

  ReportSnapshot _build() {
    return _repository.load(tasks: store.tasks, period: _period, now: _clock());
  }

  void _rebuild({bool notify = false}) {
    _snapshot = _build();
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    store.removeListener(_storeChanged);
    super.dispose();
  }
}
