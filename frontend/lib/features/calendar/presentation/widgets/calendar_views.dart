import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../data/models/calendar_event.dart';
import '../../domain/usecases/analyze_schedule.dart';
import 'calendar_event_card.dart';

const List<String> _weekdayShort = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _weekdayLong = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> _months = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String calendarDateLabel(DateTime date, {bool includeWeekday = true}) {
  final base = '${date.day} ${_months[date.month - 1]} ${date.year}';
  if (!includeWeekday) return base;
  return '${_weekdayLong[date.weekday - 1]}, $base';
}

String calendarWeekLabel(DateTime start) {
  final end = start.add(const Duration(days: 6));
  if (start.month == end.month) {
    return '${start.day} – ${end.day} ${_months[end.month - 1]} ${end.year}';
  }
  return '${start.day} ${_months[start.month - 1]} – '
      '${end.day} ${_months[end.month - 1]} ${end.year}';
}

String calendarMonthLabel(DateTime date) =>
    '${_months[date.month - 1]} ${date.year}';

/// Timeline view for one day.
class DailyCalendarView extends StatelessWidget {
  const DailyCalendarView({
    super.key,
    required this.day,
    required this.overlaps,
    required this.onEventTap,
    required this.onCreate,
  });

  final CalendarDaySummary day;
  final List<CalendarOverlap> overlaps;
  final ValueChanged<CalendarEvent> onEventTap;
  final VoidCallback onCreate;

  Set<String> get _overlapIds => <String>{
    for (final overlap in overlaps) ...[overlap.first.id, overlap.second.id],
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _SummaryValue(
                label: 'Events',
                value: '${day.events.length}',
                icon: Icons.event_outlined,
              ),
              _SummaryValue(
                label: 'Scheduled time',
                value: day.busyLabel,
                icon: Icons.schedule_rounded,
              ),
              if (day.hasOverlap)
                StatusBadge(
                  label:
                      '${day.overlapCount} '
                      '${day.overlapCount == 1 ? 'overlap' : 'overlaps'}',
                  color: scheme.error,
                  icon: Icons.warning_amber_rounded,
                ),
              if (day.isOverloaded)
                const StatusBadge(
                  label: 'Heavy day',
                  color: AppColors.warningAmber,
                  icon: Icons.local_fire_department_outlined,
                ),
              TextButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add event'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (day.events.isEmpty)
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: AppEmptyState(
              compact: true,
              icon: Icons.event_available_outlined,
              title: 'Nothing scheduled',
              message:
                  'This day is open. Add a focus block or leave room for '
                  'the work that matters most.',
              action: AppButton(
                label: 'Schedule an event',
                icon: Icons.add_rounded,
                variant: AppButtonVariant.outline,
                onPressed: onCreate,
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              children: <Widget>[
                for (var index = 0; index < day.events.length; index++) ...[
                  if (index > 0) const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 48,
                          child: Text(
                            _time(day.events[index].startTime),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: CalendarEventCard(
                            event: day.events[index],
                            hasConflict: _overlapIds.contains(
                              day.events[index].id,
                            ),
                            onTap: () => onEventTap(day.events[index]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: AppSizes.iconMd, color: scheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Seven-day overview. Wide layouts use columns; narrow layouts use day cards.
class WeeklyCalendarView extends StatelessWidget {
  const WeeklyCalendarView({
    super.key,
    required this.days,
    required this.selectedDate,
    required this.onSelectDate,
    required this.onEventTap,
    required this.onCreate,
  });

  final List<CalendarDaySummary> days;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<CalendarEvent> onEventTap;
  final ValueChanged<DateTime> onCreate;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: AppEmptyState(
          compact: true,
          icon: Icons.calendar_view_week_outlined,
          title: 'A blank week',
          message: 'Add an event to start shaping this week.',
          action: AppButton(
            label: 'Add event',
            icon: Icons.add_rounded,
            variant: AppButtonVariant.outline,
            onPressed: () => onCreate(selectedDate),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var index = 0; index < days.length; index++) ...<Widget>[
                if (index > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _WeekColumn(
                    day: days[index],
                    selected: _sameDate(days[index].date, selectedDate),
                    onSelect: () => onSelectDate(days[index].date),
                    onEventTap: onEventTap,
                    onCreate: () => onCreate(days[index].date),
                  ),
                ),
              ],
            ],
          );
        }

        return Column(
          children: <Widget>[
            for (final day in days) ...<Widget>[
              _WeekDayCard(
                day: day,
                selected: _sameDate(day.date, selectedDate),
                onSelect: () => onSelectDate(day.date),
                onEventTap: onEventTap,
                onCreate: () => onCreate(day.date),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _WeekColumn extends StatelessWidget {
  const _WeekColumn({
    required this.day,
    required this.selected,
    required this.onSelect,
    required this.onEventTap,
    required this.onCreate,
  });

  final CalendarDaySummary day;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<CalendarEvent> onEventTap;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return GestureDetector(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.4)
              : scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _weekdayShort[day.date.weekday - 1],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${day.date.day}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? scheme.primary : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            if (day.hasOverlap)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: scheme.error,
                ),
              )
            else if (day.isOverloaded)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.xs),
                child: Icon(
                  Icons.local_fire_department_outlined,
                  size: 14,
                  color: AppColors.warningAmber,
                ),
              ),
            if (day.events.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  'Open',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final event in day.events.take(4)) ...<Widget>[
                CalendarEventCard(
                  event: event,
                  compact: true,
                  hasConflict: day.hasOverlap,
                  onTap: () => onEventTap(event),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
            if (day.events.length > 4)
              Text(
                '+${day.events.length - 4} more',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Add event on ${_weekdayShort[day.date.weekday - 1]}',
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: AppSizes.iconMd),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDayCard extends StatelessWidget {
  const _WeekDayCard({
    required this.day,
    required this.selected,
    required this.onSelect,
    required this.onEventTap,
    required this.onCreate,
  });

  final CalendarDaySummary day;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<CalendarEvent> onEventTap;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: onSelect,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? scheme.primary : scheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: selected ? scheme.primary : scheme.outline,
                      ),
                    ),
                    child: Text(
                      '${day.date.day}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: selected ? scheme.onPrimary : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _weekdayLong[day.date.weekday - 1],
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${day.events.length} '
                          '${day.events.length == 1 ? 'event' : 'events'} · '
                          '${day.busyLabel}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (day.hasOverlap)
                    StatusBadge(
                      label: 'Overlap',
                      color: scheme.error,
                      icon: Icons.warning_amber_rounded,
                    )
                  else if (day.isOverloaded)
                    const StatusBadge(
                      label: 'Heavy',
                      color: AppColors.warningAmber,
                      icon: Icons.local_fire_department_outlined,
                    ),
                  IconButton(
                    tooltip:
                        'Add event on ${_weekdayLong[day.date.weekday - 1]}',
                    onPressed: onCreate,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
          ),
          if (day.events.isNotEmpty) ...<Widget>[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: <Widget>[
                  for (final event in day.events) ...<Widget>[
                    CalendarEventCard(
                      event: event,
                      compact: true,
                      hasConflict: day.hasOverlap,
                      onTap: () => onEventTap(event),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Month grid with workload markers and the selected day's agenda.
class MonthlyCalendarView extends StatelessWidget {
  const MonthlyCalendarView({
    super.key,
    required this.focusDate,
    required this.selectedDate,
    required this.analysis,
    required this.onSelectDate,
    required this.onEventTap,
    required this.onCreate,
  });

  final DateTime focusDate;
  final DateTime selectedDate;
  final ScheduleAnalysis analysis;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<CalendarEvent> onEventTap;
  final ValueChanged<DateTime> onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final first = DateTime(focusDate.year, focusDate.month);
    final daysInMonth = DateTime(focusDate.year, focusDate.month + 1, 0).day;
    final leading = first.weekday - 1;
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double cellWidth = constraints.maxWidth / 7;
              final double cellHeight = (cellWidth * 0.8).clamp(58, 108);
              return Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      for (final label in _weekdayShort)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: totalCells,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisExtent: cellHeight,
                    ),
                    itemBuilder: (context, index) {
                      final dayNumber = index - leading + 1;
                      if (dayNumber < 1 || dayNumber > daysInMonth) {
                        return const SizedBox.shrink();
                      }
                      final date = DateTime(
                        focusDate.year,
                        focusDate.month,
                        dayNumber,
                      );
                      final summary = analysis.dayFor(date);
                      return _MonthCell(
                        date: date,
                        summary: summary,
                        selected: _sameDate(date, selectedDate),
                        today: _sameDate(date, DateTime.now()),
                        onTap: () => onSelectDate(date),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _SelectedDayAgenda(
          date: selectedDate,
          summary: analysis.dayFor(selectedDate),
          onEventTap: onEventTap,
          onCreate: () => onCreate(selectedDate),
        ),
      ],
    );
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.date,
    required this.summary,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DateTime date;
  final CalendarDaySummary summary;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: selected
            ? scheme.primary
            : summary.isOverloaded
            ? AppColors.warningTint.withValues(alpha: 0.55)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: today && !selected
                            ? Border.all(color: scheme.primary, width: 1.4)
                            : null,
                      ),
                      child: Text(
                        '${date.day}',
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: today || selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected ? scheme.onPrimary : null,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (summary.hasOverlap)
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 12,
                        color: selected ? scheme.onPrimary : scheme.error,
                      )
                    else if (summary.isOverloaded)
                      Icon(
                        Icons.local_fire_department_outlined,
                        size: 12,
                        color: selected
                            ? scheme.onPrimary
                            : AppColors.warningAmber,
                      ),
                  ],
                ),
                const Spacer(),
                if (summary.events.isNotEmpty)
                  Wrap(
                    spacing: 2,
                    runSpacing: 2,
                    children: <Widget>[
                      for (final event in summary.events.take(3))
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? scheme.onPrimary
                                : event.isCompleted
                                ? AppColors.successGreen
                                : event.priority == CalendarEventPriority.urgent
                                ? scheme.error
                                : scheme.primary,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedDayAgenda extends StatelessWidget {
  const _SelectedDayAgenda({
    required this.date,
    required this.summary,
    required this.onEventTap,
    required this.onCreate,
  });

  final DateTime date;
  final CalendarDaySummary summary;
  final ValueChanged<CalendarEvent> onEventTap;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      calendarDateLabel(date),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      summary.events.isEmpty
                          ? 'No events scheduled'
                          : '${summary.events.length} '
                                '${summary.events.length == 1 ? 'event' : 'events'}'
                                ' · ${summary.busyLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Add event on ${calendarDateLabel(date)}',
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          if (summary.events.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Select another day or add a focus block to get started.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            for (final event in summary.events) ...<Widget>[
              CalendarEventCard(
                event: event,
                hasConflict: summary.hasOverlap,
                onTap: () => onEventTap(event),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ],
      ),
    );
  }
}
