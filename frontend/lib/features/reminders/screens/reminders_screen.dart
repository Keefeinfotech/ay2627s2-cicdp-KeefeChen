/// File Name: reminders_screen.dart
/// Description: Offline-first reminders hub. Lists every open task that carries
/// a reminder, grouped by urgency, and lets the user add, snooze, complete or
/// clear reminders. Backed by the same [TaskStore] as the dashboard so it
/// works without a network connection.
/// Author: Keefe Chen
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../home/data/task_store.dart';
import '../../home/data/task_validation.dart';
import '../../home/models/task.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key, required this.store});

  /// The shared workspace store. The screen never disposes it: ownership stays
  /// with the caller (the shell or the route table) so both surfaces observe
  /// the same in-memory task list.
  final TaskStore store;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  TaskStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    // The shell passes an already-loaded store; a cold deep link receives a
    // fresh one that must load itself.
    if (!_store.hasLoaded && !_store.isLoading) {
      _store.load();
    }
  }

  List<Task> get _openWithReminders {
    final tasks = _store.tasks
        .where((task) => !task.isCompleted && task.reminderAt != null)
        .toList(growable: false);
    tasks.sort((a, b) => a.reminderAt!.compareTo(b.reminderAt!));
    return tasks;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        final tasks = _openWithReminders;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Reminders'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Add reminder',
                icon: const Icon(Icons.add_alarm_rounded),
                onPressed: () => _openAddReminderDialog(),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
          body: _body(context, tasks),
        );
      },
    );
  }

  Widget _body(BuildContext context, List<Task> tasks) {
    if (!_store.hasLoaded && _store.isLoading) {
      return const Center(child: AppLoading(label: 'Loading reminders...'));
    }

    final storeError = _store.error;
    if (storeError != null && tasks.isEmpty) {
      return Center(
        child: AppErrorState(message: storeError, onRetry: _store.retry),
      );
    }

    if (tasks.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.notifications_off_outlined,
          title: 'No reminders yet',
          message:
              'Schedule a reminder on any task and it will appear here, '
              'even without a network connection.',
          action: AppButton(
            label: 'Add reminder',
            icon: Icons.add_alarm_rounded,
            onPressed: () => _openAddReminderDialog(),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final overdue = <Task>[];
    final today = <Task>[];
    final upcoming = <Task>[];
    for (final task in tasks) {
      final reminder = task.reminderAt!.toLocal();
      if (reminder.isBefore(now)) {
        overdue.add(task);
      } else if (_isSameDay(reminder, now)) {
        today.add(task);
      } else {
        upcoming.add(task);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        if (storeError != null) ...[
          AppErrorBanner(
            message: storeError,
            onRetry: _store.retry,
            onDismiss: _store.clearError,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _section(
          context,
          icon: Icons.error_outline_rounded,
          title: 'Overdue',
          tasks: overdue,
          accent: Theme.of(context).colorScheme.error,
        ),
        _section(
          context,
          icon: Icons.today_rounded,
          title: 'Today',
          tasks: today,
          accent: Theme.of(context).colorScheme.primary,
        ),
        _section(
          context,
          icon: Icons.upcoming_outlined,
          title: 'Upcoming',
          tasks: upcoming,
          accent: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Task> tasks,
    required Color accent,
  }) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: AppSizes.iconSm, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${tasks.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final task in tasks) ...[
            _ReminderTile(
              task: task,
              onComplete: () => _complete(task),
              onSnooze: () => _snooze(task),
              onClear: () => _clear(task),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  Future<void> _complete(Task task) async {
    final ok = await _store.toggleCompletion(task.id);
    if (!mounted) return;
    if (ok) {
      AppSnackBar.success(context, '"${task.title}" marked as done.');
    } else {
      AppSnackBar.error(
        context,
        _store.error ?? 'Could not complete the task.',
      );
    }
  }

  Future<void> _snooze(Task task) async {
    final ok = await _store.snoozeReminder(task.id);
    if (!mounted) return;
    if (ok) {
      AppSnackBar.info(context, 'Reminder snoozed for 10 minutes.');
    } else {
      AppSnackBar.error(
        context,
        _store.error ?? 'Could not snooze the reminder.',
      );
    }
  }

  Future<void> _clear(Task task) async {
    final ok = await _store.clearReminder(task.id);
    if (!mounted) return;
    if (ok) {
      AppSnackBar.info(context, 'Reminder cleared for "${task.title}".');
    } else {
      AppSnackBar.error(
        context,
        _store.error ?? 'Could not clear the reminder.',
      );
    }
  }

  Future<void> _openAddReminderDialog() async {
    final result = await showDialog<_AddReminderResult>(
      context: context,
      builder: (_) => _AddReminderDialog(store: _store),
    );
    if (result == null || !mounted) return;

    final Future<bool> action = switch (result) {
      _NewReminderResult(:final title, :final at) => _store.addTask(
        TaskDraft(title: title, dueDate: at, reminderAt: at),
      ),
      _AttachReminderResult(:final task, :final at) => _store.updateTask(
        task.id,
        TaskDraft(
          title: task.title,
          notes: task.notes,
          course: task.course,
          tags: task.tags,
          groupId: task.groupId,
          assigneeId: task.assigneeId,
          assigneeName: task.assigneeName,
          priority: task.priority,
          dueDate: task.dueDate,
          reminderAt: at,
        ),
      ),
    };

    final ok = await action;
    if (!mounted) return;
    if (ok) {
      AppSnackBar.success(
        context,
        'Reminder scheduled for ${formatTaskDate(result.at)}.',
      );
    } else {
      AppSnackBar.error(
        context,
        _store.error ?? 'Could not schedule the reminder.',
      );
    }
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.task,
    required this.onComplete,
    required this.onSnooze,
    required this.onClear,
  });

  final Task task;
  final VoidCallback onComplete;
  final VoidCallback onSnooze;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reminder = task.reminderAt!.toLocal();
    final overdue = task.isReminderDue();

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      semanticLabel: 'Reminder for ${task.title}',
      child: Row(
        children: <Widget>[
          Icon(
            overdue ? Icons.notifications_active_rounded : Icons.alarm_rounded,
            size: AppSizes.iconMd,
            color: overdue ? scheme.error : scheme.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${overdue ? 'Was due' : 'Due'} ${formatTaskDate(reminder)}'
                  '${task.course.isNotEmpty ? ' · ${task.course}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: overdue ? scheme.error : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Complete task',
            onPressed: onComplete,
            icon: const Icon(Icons.check_rounded),
          ),
          IconButton(
            tooltip: 'Snooze 10 minutes',
            onPressed: onSnooze,
            icon: const Icon(Icons.snooze_rounded),
          ),
          IconButton(
            tooltip: 'Clear reminder',
            onPressed: onClear,
            icon: const Icon(Icons.alarm_off_rounded),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add-reminder dialog
// ---------------------------------------------------------------------------

sealed class _AddReminderResult {
  const _AddReminderResult();

  DateTime get at;
}

class _NewReminderResult extends _AddReminderResult {
  const _NewReminderResult({required this.title, required this.at});

  final String title;
  @override
  final DateTime at;
}

class _AttachReminderResult extends _AddReminderResult {
  const _AttachReminderResult({required this.task, required this.at});

  final Task task;
  @override
  final DateTime at;
}

/// Dialog used to schedule a reminder, either as a stand-alone reminder task
/// or attached to an existing open task.
class _AddReminderDialog extends StatefulWidget {
  const _AddReminderDialog({required this.store});

  final TaskStore store;

  @override
  State<_AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<_AddReminderDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();

  late bool _attachMode;
  String? _selectedTaskId;
  late DateTime _picked;
  String? _inlineError;

  List<Task> get _attachableTasks {
    final tasks = widget.store.tasks
        .where((task) => !task.isCompleted && task.reminderAt == null)
        .toList(growable: false);
    tasks.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return tasks;
  }

  @override
  void initState() {
    super.initState();
    // New-task mode is the safe default: attach mode only works when there
    // is at least one open task without a reminder.
    _attachMode = false;
    _picked = DateTime.now().add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Task? get _selectedTask {
    final id = _selectedTaskId;
    if (id == null) return null;
    for (final task in _attachableTasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _picked,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    setState(() {
      _picked = DateTime(
        date.year,
        date.month,
        date.day,
        _picked.hour,
        _picked.minute,
      );
      _inlineError = null;
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_picked),
    );
    if (time == null || !mounted) return;
    setState(() {
      _picked = DateTime(
        _picked.year,
        _picked.month,
        _picked.day,
        time.hour,
        time.minute,
      );
      _inlineError = null;
    });
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form != null && !form.validate()) return;

    final now = DateTime.now();
    if (_picked.isBefore(now)) {
      setState(() => _inlineError = 'Pick a time in the future.');
      return;
    }

    if (_attachMode) {
      final task = _selectedTask;
      if (task == null) {
        setState(
          () => _inlineError = 'Choose a task to attach the reminder to.',
        );
        return;
      }
      // Mirrors validateSchedule so the failure surfaces inline instead of
      // after the round trip through the store.
      final scheduleError = validateSchedule(
        dueDate: task.dueDate,
        reminderAt: _picked,
      );
      if (scheduleError != null) {
        setState(() {
          _inlineError = task.dueDate == null
              ? scheduleError
              : '$scheduleError (${formatTaskDate(task.dueDate!)}).';
        });
        return;
      }
      Navigator.of(context).pop(_AttachReminderResult(task: task, at: _picked));
      return;
    }

    final title = _titleController.text.trim();
    final titleError = validateTitle(title);
    if (titleError != null) {
      setState(() => _inlineError = titleError);
      return;
    }
    Navigator.of(context).pop(_NewReminderResult(title: title, at: _picked));
  }

  @override
  Widget build(BuildContext context) {
    final attachable = _attachableTasks;
    final scheme = Theme.of(context).colorScheme;

    return AppDialog(
      title: 'Add reminder',
      icon: Icons.add_alarm_rounded,
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(label: 'Save reminder', onPressed: _submit),
      ],
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (attachable.isNotEmpty) ...[
                SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('New reminder task'),
                      icon: Icon(Icons.note_add_outlined),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Attach to task'),
                      icon: Icon(Icons.task_alt_outlined),
                    ),
                  ],
                  selected: <bool>{_attachMode},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _attachMode = selection.first;
                      _inlineError = null;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (_attachMode) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedTaskId,
                  decoration: const InputDecoration(
                    labelText: 'Task',
                    prefixIcon: Icon(Icons.checklist_rtl_rounded),
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final task in attachable)
                      DropdownMenuItem<String>(
                        value: task.id,
                        child: Text(
                          task.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _selectedTaskId = value;
                    _inlineError = null;
                  }),
                  validator: (value) => value == null ? 'Choose a task' : null,
                ),
              ] else ...[
                AppTextField(
                  controller: _titleController,
                  labelText: 'Remind me to',
                  hintText: 'e.g. Revise ST0529 chapter 4',
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  autofocus: true,
                  validator: validateTitle,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(
                        Icons.calendar_today_outlined,
                        size: AppSizes.iconSm,
                      ),
                      label: Text(formatDateOnly(_picked)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(
                        Icons.schedule_rounded,
                        size: AppSizes.iconSm,
                      ),
                      label: Text(_formatClock(_picked)),
                    ),
                  ),
                ],
              ),
              if (_inlineError != null) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.error_outline_rounded,
                      size: AppSizes.iconSm,
                      color: scheme.error,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _inlineError!,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.error),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatClock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
