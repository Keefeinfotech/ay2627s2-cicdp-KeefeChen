import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/app_app_bar.dart';
import 'package:frontend/core/widgets/app_button.dart';
import 'package:frontend/core/widgets/app_error_state.dart';
import 'package:frontend/core/widgets/app_loading.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/core/widgets/app_status_badge.dart';
import 'package:frontend/features/authentication/models/session.dart';
import 'package:frontend/features/calendar/data/datasources/calendar_api_data_source.dart';
import 'package:frontend/features/calendar/data/models/calendar_event.dart';
import 'package:frontend/features/calendar/data/repositories/calendar_repository.dart';
import 'package:frontend/features/calendar/domain/usecases/analyze_schedule.dart';
import 'package:frontend/features/calendar/presentation/controllers/calendar_controller.dart';
import 'package:frontend/features/calendar/presentation/widgets/calendar_event_editor.dart';
import 'package:frontend/features/calendar/presentation/widgets/calendar_views.dart';
import 'package:frontend/features/calendar/presentation/widgets/schedule_optimization_banner.dart';
import 'package:frontend/features/home/data/api_task_repository.dart';
import 'package:frontend/features/home/data/task_store.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Calendar surface with range queries, workload analysis and three views.
class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.ownerId,
    this.store,
    this.session,
    this.api,
  });

  final String ownerId;
  final TaskStore? store;
  final Session? session;
  final ApiClient? api;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final TaskStore _store;
  late final bool _ownsStore;
  late final CalendarController _controller;

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.store == null;
    _store =
        widget.store ??
        TaskStore(repository: ApiTaskRepository(), ownerId: widget.ownerId);
    final repository = CalendarRepository(
      store: _store,
      api: CalendarApiDataSource(api: widget.api),
    );
    _controller = CalendarController(
      repository: repository,
      store: _store,
      token: widget.session?.token,
    )..addListener(_changed);
    _store.addListener(_storeChanged);
    if (!_store.hasLoaded && !_store.isLoading) _store.load();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _store.removeListener(_storeChanged);
    _controller.dispose();
    if (_ownsStore) _store.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _storeChanged() {
    if (!mounted || !_store.hasLoaded) return;
    _controller.load();
  }

  void _snack(String message, {AppSnackType type = AppSnackType.info}) {
    AppSnackBar.show(context, message, type: type);
  }

  Future<void> _addEvent(DateTime date) async {
    final event = await showModalBottomSheet<CalendarEvent>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CalendarEventEditor(
        initialDate: date,
        projects: _controller.projects,
        onCheckConflicts: _controller.conflictsFor,
      ),
    );
    if (event == null || !mounted) return;

    final result = await _controller.createEvent(event);
    if (!mounted) return;
    if (result == null) {
      _snack(
        _controller.error ?? 'The event could not be created.',
        type: AppSnackType.error,
      );
      return;
    }

    _snack(
      result.synced
          ? 'Event added to your calendar.'
          : 'Event saved on this device.',
      type: result.warning == null
          ? AppSnackType.success
          : AppSnackType.warning,
    );
  }

  void _openEvent(CalendarEvent event) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EventDetailsSheet(event: event),
    );
  }

  Future<void> _reviewSchedule() async {
    final selection = await showModalBottomSheet<ScheduleSuggestion>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ScheduleOptimizationSheet(
        analysis: _controller.analysis,
        onApply: (_) {},
      ),
    );
    if (selection == null || !mounted) return;

    final result = _controller.applySuggestion(selection);
    if (!mounted) return;
    _snack(
      result == null
          ? 'That suggestion could not be applied.'
          : 'Schedule preview updated.',
      type: result == null ? AppSnackType.error : AppSnackType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AuxiliaAppBar(
        title: 'Calendar',
        subtitle: 'Plan deadlines, events and focus time',
        actions: <Widget>[
          IconButton(
            tooltip: 'Add event',
            onPressed: () => _addEvent(_controller.focusDate),
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: 'Refresh calendar',
            onPressed: _controller.isLoading ? null : _controller.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: RefreshIndicator(
              onRefresh: _controller.retry,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: <Widget>[
                  _buildToolbar(context),
                  const SizedBox(height: AppSpacing.lg),
                  if (_controller.warning != null) ...<Widget>[
                    _WarningBanner(
                      message: _controller.warning!,
                      onDismiss: _controller.dismissWarning,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (_controller.error != null) ...<Widget>[
                    AppErrorBanner(
                      message: _controller.error!,
                      onRetry: _controller.retry,
                      onDismiss: null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (_controller.isLoading && !_controller.hasLoaded)
                    const _CalendarSkeleton()
                  else ...<Widget>[
                    ScheduleOptimizationBanner(
                      analysis: _controller.analysis,
                      onReview: _reviewSchedule,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildCalendarBody(context),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bool isDaily = _controller.view == CalendarViewMode.daily;
    final bool isWeekly = _controller.view == CalendarViewMode.weekly;
    final String label = isDaily
        ? _calendarDateLabel(_controller.focusDate)
        : isWeekly
        ? _calendarWeekLabel(_controller.rangeStart)
        : _calendarMonthLabel(_controller.focusDate);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LayoutBuilder(
            builder: (context, constraints) {
              final nav = Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Previous period',
                    onPressed: () => _controller.moveBy(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  TextButton(
                    onPressed: _controller.goToToday,
                    child: const Text('Today'),
                  ),
                  IconButton(
                    tooltip: 'Next period',
                    onPressed: () => _controller.moveBy(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              );

              final heading = Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              );

              if (constraints.maxWidth < 540) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    heading,
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        nav,
                        _ProjectFilter(controller: _controller),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(child: heading),
                  Flexible(flex: 1, fit: FlexFit.loose, child: nav),
                  const SizedBox(width: AppSpacing.sm),
                  _ProjectFilter(controller: _controller),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<CalendarViewMode>(
              showSelectedIcon: false,
              segments: const <ButtonSegment<CalendarViewMode>>[
                ButtonSegment<CalendarViewMode>(
                  value: CalendarViewMode.daily,
                  label: Text('Daily'),
                  icon: Icon(Icons.view_day_outlined),
                ),
                ButtonSegment<CalendarViewMode>(
                  value: CalendarViewMode.weekly,
                  label: Text('Weekly'),
                  icon: Icon(Icons.view_week_outlined),
                ),
                ButtonSegment<CalendarViewMode>(
                  value: CalendarViewMode.monthly,
                  label: Text('Monthly'),
                  icon: Icon(Icons.calendar_month_outlined),
                ),
              ],
              selected: <CalendarViewMode>{_controller.view},
              onSelectionChanged: (selection) =>
                  _controller.setView(selection.first),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarBody(BuildContext context) {
    switch (_controller.view) {
      case CalendarViewMode.daily:
        return DailyCalendarView(
          day: _controller.focusDay,
          overlaps: _controller.analysis.overlaps,
          onEventTap: _openEvent,
          onCreate: () => _addEvent(_controller.focusDate),
        );
      case CalendarViewMode.weekly:
        return WeeklyCalendarView(
          days: _controller.visibleDays,
          selectedDate: _controller.focusDate,
          onSelectDate: _controller.selectDate,
          onEventTap: _openEvent,
          onCreate: _addEvent,
        );
      case CalendarViewMode.monthly:
        return MonthlyCalendarView(
          focusDate: _controller.focusDate,
          selectedDate: _controller.focusDate,
          analysis: _controller.analysis,
          onSelectDate: _controller.selectDate,
          onEventTap: _openEvent,
          onCreate: _addEvent,
        );
    }
  }

  String _calendarDateLabel(DateTime date) =>
      '${_monthName(date.month)} ${date.day}, ${date.year}';

  String _calendarWeekLabel(DateTime rangeStart) =>
      'Week of ${_monthName(rangeStart.month)} ${rangeStart.day}';

  String _calendarMonthLabel(DateTime focusDate) => _monthName(focusDate.month);

  String _monthName(int month) {
    const names = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[month - 1];
  }
}

class _ProjectFilter extends StatelessWidget {
  const _ProjectFilter({required this.controller});

  final CalendarController controller;

  @override
  Widget build(BuildContext context) {
    final projects = <String>{
      ...controller.projects,
      if (controller.groupId != null) controller.groupId!,
    }.toList()..sort();

    return DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: controller.groupId,
        isExpanded: false,
        borderRadius: BorderRadius.circular(AppRadius.md),
        hint: const Text('All projects'),
        items: <DropdownMenuItem<String?>>[
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('All projects'),
          ),
          for (final project in projects)
            DropdownMenuItem<String?>(
              value: project,
              child: Text(project, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: controller.setGroup,
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.cloud_off_outlined,
            color: Color(0xFFD97706),
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF92400E)),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss calendar warning',
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: const Color(0xFF92400E),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _CalendarSkeleton extends StatelessWidget {
  const _CalendarSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Expanded(child: LoadingSkeleton(height: 18)),
              SizedBox(width: AppSpacing.xl),
              LoadingSkeleton(width: 84, height: 18),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          for (var row = 0; row < 3; row++) ...<Widget>[
            Row(
              children: <Widget>[
                for (var column = 0; column < 4; column++) ...<Widget>[
                  if (column > 0) const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: LoadingSkeleton(height: 76, borderRadius: 10),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _EventDetailsSheet extends StatelessWidget {
  const _EventDetailsSheet({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        event.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close event details',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    StatusBadge(
                      label: event.status.label,
                      color: event.isCompleted
                          ? AppColors.successGreen
                          : event.isCancelled
                          ? scheme.onSurfaceVariant
                          : scheme.primary,
                      icon: event.isCompleted
                          ? Icons.check_circle_outline_rounded
                          : Icons.schedule_rounded,
                    ),
                    StatusBadge(
                      label: '${event.priority.label} priority',
                      color: event.priority == CalendarEventPriority.urgent
                          ? scheme.error
                          : event.priority == CalendarEventPriority.high
                          ? AppColors.warningAmber
                          : scheme.primary,
                      icon: Icons.flag_outlined,
                    ),
                    if (event.taskId != null)
                      StatusBadge(
                        label: 'Linked task',
                        color: scheme.onSurfaceVariant,
                        icon: Icons.task_alt_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _DetailRow(
                  icon: Icons.event_outlined,
                  label: 'Date',
                  value: _calendarDateLabel(event.startTime),
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  icon: Icons.schedule_rounded,
                  label: 'Time',
                  value:
                      '${_time(event.startTime)} – ${_time(event.endTime)} '
                      '(${event.duration.inMinutes} min)',
                ),
                if (event.location != null &&
                    event.location!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _DetailRow(
                    icon: Icons.workspaces_outline,
                    label: 'Project',
                    value: event.location!,
                  ),
                ],
                if (event.description.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _DetailRow(
                    icon: Icons.notes_rounded,
                    label: 'Notes',
                    value: event.description,
                  ),
                ],
                if (event.taskId != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      'This event comes from a task due date. Update the task '
                      'in Tasks to change its deadline.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Close',
                  variant: AppButtonVariant.outline,
                  onPressed: () => Navigator.of(context).pop(),
                  expand: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  String _calendarDateLabel(DateTime date) =>
      '${_monthName(date.month)} ${date.day}, ${date.year}';

  String _monthName(int month) {
    const names = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[month - 1];
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: AppSizes.iconMd, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
