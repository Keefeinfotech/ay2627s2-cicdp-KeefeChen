import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../home/data/task_store.dart';
import '../../data/models/calendar_event.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../domain/usecases/analyze_schedule.dart';

enum CalendarViewMode { daily, weekly, monthly }

/// Owns the calendar range query, view state and schedule analysis.
class CalendarController extends ChangeNotifier {
  CalendarController({
    required this.repository,
    required this.store,
    this.token,
    DateTime? initialDate,
    this.analyzer = const AnalyzeSchedule(),
  }) : _focusDate = _dateOnly(initialDate ?? DateTime.now());

  final CalendarRepository repository;
  final TaskStore store;
  final String? token;
  final AnalyzeSchedule analyzer;

  DateTime _focusDate;
  CalendarViewMode _view = CalendarViewMode.weekly;
  String? _groupId;
  List<CalendarEvent> _events = const <CalendarEvent>[];
  ScheduleAnalysis? _analysis;
  bool _loading = false;
  bool _hasLoaded = false;
  bool _isRemote = false;
  String? _error;
  String? _warning;
  int _request = 0;
  bool _reloadRequested = false;

  DateTime get focusDate => _focusDate;
  CalendarViewMode get view => _view;
  String? get groupId => _groupId;
  List<CalendarEvent> get events => List<CalendarEvent>.unmodifiable(_events);
  bool get isLoading => _loading;
  bool get hasLoaded => _hasLoaded;
  bool get isRemote => _isRemote;
  String? get error => _error;
  String? get warning => _warning;
  List<String> get projects => repository.projects;

  ScheduleAnalysis get analysis =>
      _analysis ??
      analyzer(
        _events,
        startDate: rangeStart,
        endDate: rangeEnd.subtract(const Duration(days: 1)),
      );

  DateTime get rangeStart => switch (_view) {
    CalendarViewMode.daily => _focusDate,
    CalendarViewMode.weekly => _startOfWeek(_focusDate),
    CalendarViewMode.monthly => DateTime(_focusDate.year, _focusDate.month),
  };

  DateTime get rangeEnd => switch (_view) {
    CalendarViewMode.daily => _focusDate.add(const Duration(days: 1)),
    CalendarViewMode.weekly => _startOfWeek(
      _focusDate,
    ).add(const Duration(days: 7)),
    CalendarViewMode.monthly => DateTime(_focusDate.year, _focusDate.month + 1),
  };

  List<CalendarDaySummary> get visibleDays {
    final analysis = this.analysis;
    return analysis.days
        .where(
          (day) =>
              !day.date.isBefore(rangeStart) && day.date.isBefore(rangeEnd),
        )
        .toList(growable: false);
  }

  CalendarDaySummary get focusDay => analysis.dayFor(_focusDate);

  bool get hasOverlaps => analysis.overlaps.isNotEmpty;

  int get overloadedDayCount => analysis.overloadedDayCount;

  void setView(CalendarViewMode mode) {
    if (_view == mode) return;
    _view = mode;
    notifyListeners();
    load();
  }

  void setGroup(String? groupId) {
    final normalized = groupId == null || groupId.trim().isEmpty
        ? null
        : groupId.trim();
    if (_groupId == normalized) return;
    _groupId = normalized;
    notifyListeners();
    load();
  }

  void selectDate(DateTime date) {
    final next = _dateOnly(date);
    if (_focusDate == next) return;
    final wasOutsideRange =
        next.isBefore(rangeStart) || !next.isBefore(rangeEnd);
    _focusDate = next;
    notifyListeners();
    if (wasOutsideRange || !_hasLoaded) load();
  }

  void moveBy(int amount) {
    _focusDate = switch (_view) {
      CalendarViewMode.daily => _focusDate.add(Duration(days: amount)),
      CalendarViewMode.weekly => _focusDate.add(Duration(days: 7 * amount)),
      CalendarViewMode.monthly => DateTime(
        _focusDate.year,
        _focusDate.month + amount,
        1,
      ),
    };
    notifyListeners();
    load();
  }

  void goToToday() {
    _focusDate = _dateOnly(DateTime.now());
    notifyListeners();
    load();
  }

  Future<void> load() async {
    if (_loading) {
      // Remember the request so the newest query still runs once the
      // in-flight one finishes instead of silently dropping a view change.
      _reloadRequested = true;
      return;
    }
    final request = ++_request;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await repository.loadEvents(
        startDate: rangeStart,
        endDate: rangeEnd,
        groupId: _groupId,
        token: token,
      );
      if (request != _request) return;
      _events = result.events;
      _isRemote = result.isRemote;
      _warning = result.warning;
      _hasLoaded = true;
      _analysis = analyzer(
        _events,
        startDate: rangeStart,
        endDate: rangeEnd.subtract(const Duration(days: 1)),
      );
    } catch (_) {
      if (request != _request) return;
      _error = 'The calendar could not be loaded. Please try again.';
    } finally {
      if (request == _request) {
        _loading = false;
        notifyListeners();
        if (_reloadRequested) {
          _reloadRequested = false;
          unawaited(load());
        }
      }
    }
  }

  Future<void> retry() => load();

  Future<CalendarWriteResult?> createEvent(CalendarEvent event) async {
    try {
      final result = await repository.createEvent(event: event, token: token);
      _warning = result.warning;
      _events = <CalendarEvent>[..._events, result.event]
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      _analysis = analyzer(
        _events,
        startDate: rangeStart,
        endDate: rangeEnd.subtract(const Duration(days: 1)),
      );
      _hasLoaded = true;
      notifyListeners();
      return result;
    } catch (_) {
      _error = 'The event could not be created. Please try again.';
      notifyListeners();
      return null;
    }
  }

  Future<List<CalendarEvent>> conflictsFor(DateTime start, DateTime end) async {
    final remote = await repository.checkConflicts(
      startTime: start,
      endTime: end,
      token: token,
    );
    if (remote.isNotEmpty) return remote;
    return _events
        .where(
          (event) =>
              event.startTime.isBefore(end) && start.isBefore(event.endTime),
        )
        .toList(growable: false);
  }

  CalendarWriteResult? applySuggestion(ScheduleSuggestion suggestion) {
    final event = suggestion.event;
    final start = suggestion.suggestedStart;
    if (event == null || start == null) return null;

    final result = repository.applyLocalMove(event, start);
    _events =
        _events
            .where((existing) => existing.id != event.id)
            .toList(growable: true)
          ..add(result.event)
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
    _warning = result.warning;
    _analysis = analyzer(
      _events,
      startDate: rangeStart,
      endDate: rangeEnd.subtract(const Duration(days: 1)),
    );
    notifyListeners();
    return result;
  }

  void dismissWarning() {
    if (_warning == null) return;
    _warning = null;
    notifyListeners();
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _startOfWeek(DateTime date) {
    final day = _dateOnly(date);
    return day.subtract(Duration(days: day.weekday - 1));
  }
}
