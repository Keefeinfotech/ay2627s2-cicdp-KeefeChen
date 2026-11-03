import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/calendar_event.dart';

/// Bottom sheet used to create a calendar event.
class CalendarEventEditor extends StatefulWidget {
  const CalendarEventEditor({
    super.key,
    required this.initialDate,
    this.projects = const <String>[],
    this.onCheckConflicts,
  });

  final DateTime initialDate;
  final List<String> projects;
  final Future<List<CalendarEvent>> Function(DateTime start, DateTime end)?
  onCheckConflicts;

  @override
  State<CalendarEventEditor> createState() => _CalendarEventEditorState();
}

class _CalendarEventEditorState extends State<CalendarEventEditor> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  late DateTime _date;
  late TimeOfDay _startTime;
  int _durationMinutes = 45;
  CalendarEventPriority _priority = CalendarEventPriority.medium;
  String? _project;
  String? _error;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    final now = DateTime.now();
    final bool isToday =
        _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
    final int hour = isToday ? (now.hour + 1).clamp(8, 20) : 9;
    _startTime = TimeOfDay(hour: hour, minute: 0);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  DateTime get _start => DateTime(
    _date.year,
    _date.month,
    _date.day,
    _startTime.hour,
    _startTime.minute,
  );

  DateTime get _end => _start.add(Duration(minutes: _durationMinutes));

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (time != null && mounted) setState(() => _startTime = time);
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the event a short title.');
      return;
    }
    if (!_end.isAfter(_start)) {
      setState(() => _error = 'Choose a duration longer than zero.');
      return;
    }

    setState(() {
      _checking = true;
      _error = null;
    });

    List<CalendarEvent> conflicts = const <CalendarEvent>[];
    try {
      conflicts =
          await widget.onCheckConflicts?.call(_start, _end) ??
          const <CalendarEvent>[];
    } catch (_) {
      conflicts = const <CalendarEvent>[];
    }

    if (!mounted) return;

    if (conflicts.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text('This event overlaps'),
          content: Text(
            'It clashes with “${conflicts.first.title}”. You can still add '
            'it, or go back and choose another time.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Choose another time'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Add anyway'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (proceed != true) {
        setState(() => _checking = false);
        return;
      }
    }

    Navigator.of(context).pop(
      CalendarEvent(
        id: 'draft-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        description: _description.text.trim(),
        startTime: _start,
        endTime: _end,
        priority: _priority,
        location: _project,
        groupId: _project,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final projects = <String>{
      ...widget.projects,
      if (_project != null && _project!.isNotEmpty) _project!,
    }.toList()..sort();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
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
              constraints: const BoxConstraints(maxWidth: 600),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'New calendar event',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Block time for classes, focus sessions and '
                              'deadlines.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close event editor',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _title,
                    labelText: 'Title',
                    hintText: 'e.g. COMP 2101 revision block',
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _description,
                    labelText: 'Notes (optional)',
                    maxLines: 2,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      _FieldButton(
                        icon: Icons.event_outlined,
                        label: formatDateOnly(_date),
                        onTap: _pickDate,
                      ),
                      _FieldButton(
                        icon: Icons.schedule_rounded,
                        label: _startTime.format(context),
                        onTap: _pickTime,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Duration',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final minutes in <int>[30, 45, 60, 90])
                        ChoiceChip(
                          label: Text('$minutes min'),
                          selected: _durationMinutes == minutes,
                          showCheckmark: false,
                          onSelected: (_) =>
                              setState(() => _durationMinutes = minutes),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final priorityField =
                          DropdownButtonFormField<CalendarEventPriority>(
                            initialValue: _priority,
                            decoration: const InputDecoration(
                              labelText: 'Priority',
                              prefixIcon: Icon(
                                Icons.flag_outlined,
                                size: AppSizes.iconMd,
                              ),
                            ),
                            items: CalendarEventPriority.values
                                .map(
                                  (priority) =>
                                      DropdownMenuItem<CalendarEventPriority>(
                                        value: priority,
                                        child: Text(priority.label),
                                      ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _priority = value);
                              }
                            },
                          );
                      final projectField = DropdownButtonFormField<String?>(
                        initialValue: _project,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Project',
                          prefixIcon: Icon(
                            Icons.workspaces_outline,
                            size: AppSizes.iconMd,
                          ),
                        ),
                        hint: const Text('No project'),
                        items: <DropdownMenuItem<String?>>[
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('No project'),
                          ),
                          for (final project in projects)
                            DropdownMenuItem<String?>(
                              value: project,
                              child: Text(
                                project,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) => setState(() => _project = value),
                      );

                      if (constraints.maxWidth < 440) {
                        return Column(
                          children: <Widget>[
                            priorityField,
                            const SizedBox(height: AppSpacing.md),
                            projectField,
                          ],
                        );
                      }
                      return Row(
                        children: <Widget>[
                          Expanded(child: priorityField),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: projectField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.schedule_rounded,
                          size: AppSizes.iconMd,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '${formatDateOnly(_date)} · '
                            '${_startTime.format(context)} – '
                            '${TimeOfDay.fromDateTime(_end).format(context)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: <Widget>[
                      TextButton(
                        onPressed: _checking
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      AppButton(
                        label: 'Add event',
                        icon: Icons.event_available_outlined,
                        onPressed: _checking ? null : _submit,
                        isLoading: _checking,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: scheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: AppSizes.iconMd, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
