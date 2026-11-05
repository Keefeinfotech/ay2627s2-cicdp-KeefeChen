import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../home/data/task_store.dart';
import '../../home/models/task.dart';

/// Watches the task store and surfaces due reminders as in-app banners.
///
/// Notifications are intentionally in-app: they work on every Flutter target
/// without platform permission prompts, and the reminder is still recorded on
/// the task so an OS-level notification can be added later. A reminder is
/// presented once per scheduled time; snoozing writes a new time, which makes
/// it eligible again.
class ReminderHost extends StatefulWidget {
  const ReminderHost({super.key, required this.store, required this.child});

  final TaskStore store;
  final Widget child;

  /// How often the host re-checks reminders while the app is open.
  static const Duration pollInterval = Duration(seconds: 30);

  @override
  State<ReminderHost> createState() => _ReminderHostState();
}

class _ReminderHostState extends State<ReminderHost> {
  Timer? _timer;
  final Set<String> _presented = <String>{};

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_check);
    _timer = Timer.periodic(ReminderHost.pollInterval, (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didUpdateWidget(ReminderHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store == widget.store) return;
    oldWidget.store.removeListener(_check);
    widget.store.addListener(_check);
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.store.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    for (final task in widget.store.dueReminders()) {
      final key = _keyFor(task);
      if (_presented.contains(key)) continue;
      _presented.add(key);
      _show(messenger, task);
      return;
    }
  }

  String _keyFor(Task task) =>
      '${task.id}:${task.reminderAt?.toUtc().toIso8601String()}';

  void _show(ScaffoldMessengerState messenger, Task task) {
    final theme = Theme.of(context);
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        leading: Icon(
          Icons.notifications_active_outlined,
          color: theme.colorScheme.primary,
        ),
        content: Text(
          'Reminder: ${task.title}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              widget.store.snoozeReminder(task.id);
            },
            child: const Text('Snooze 10 min'),
          ),
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              widget.store.toggleCompletion(task.id);
            },
            child: const Text('Mark done'),
          ),
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Compact reminder list shown above the task list.
///
/// Only open tasks with a reminder are listed, earliest first, so the section
/// disappears entirely when there is nothing scheduled.
class ReminderSection extends StatelessWidget {
  const ReminderSection({
    super.key,
    required this.store,
    this.onOpenTask,
    this.maxItems = 3,
  });

  final TaskStore store;
  final ValueChanged<Task>? onOpenTask;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final reminders = store.upcomingReminders;
    if (reminders.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = reminders.take(maxItems).toList(growable: false);

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
          Row(
            children: <Widget>[
              Icon(
                Icons.notifications_active_outlined,
                size: AppSizes.iconSm,
                color: scheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Reminders',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${reminders.length} scheduled',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final task in visible)
            _ReminderRow(
              task: task,
              onOpen: onOpenTask == null ? null : () => onOpenTask!(task),
              onSnooze: () => store.snoozeReminder(task.id),
              onComplete: () => store.toggleCompletion(task.id),
            ),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.task,
    required this.onSnooze,
    required this.onComplete,
    this.onOpen,
  });

  final Task task;
  final VoidCallback onSnooze;
  final VoidCallback onComplete;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final due = task.isReminderDue();
    final reminder = task.reminderAt!;

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: <Widget>[
            Icon(
              due ? Icons.notifications_active_rounded : Icons.schedule_rounded,
              size: AppSizes.iconSm,
              color: due ? scheme.error : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
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
                  Text(
                    due
                        ? 'Due now · ${_formatTime(reminder)}'
                        : _formatTime(reminder),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: due ? scheme.error : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Snooze 10 minutes',
              onPressed: onSnooze,
              icon: const Icon(Icons.snooze_rounded, size: AppSizes.iconSm),
            ),
            IconButton(
              tooltip: 'Mark done',
              onPressed: onComplete,
              icon: const Icon(Icons.check_rounded, size: AppSizes.iconSm),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final difference = day.difference(today).inDays;
    final clock =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';

    return switch (difference) {
      0 => 'Today, $clock',
      1 => 'Tomorrow, $clock',
      -1 => 'Yesterday, $clock',
      _ =>
        '${local.day.toString().padLeft(2, '0')}/'
            '${local.month.toString().padLeft(2, '0')}, $clock',
    };
  }
}
