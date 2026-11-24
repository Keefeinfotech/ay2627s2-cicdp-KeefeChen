/// File Name: reminders_screen.dart
/// Description: Shows task-based reminders (due/overdue/upcoming) for the user.
/// This screen is a standalone route; when no TaskStore is provided it falls back
/// to a safe empty state that directs users to manage reminders from Tasks.
library;

import 'package:flutter/material.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../home/data/task_store.dart';
import '../../home/models/task.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key, this.store});

  /// Optional task store. When null (standalone route), we show a safe
  /// informational state instead of calling a broken legacy API.
  final TaskStore? store;

  @override
  Widget build(BuildContext context) {
    final taskStore = store;
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: taskStore == null
          ? AppEmptyState(
              icon: Icons.notifications_outlined,
              title: 'Reminders live with your tasks',
              message:
                  'Open a task to add, edit, or snooze its reminder. Due reminders also appear in-app while you use Auxilia.',
              action: FilledButton.icon(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.home,
                  (route) => false,
                ),
                icon: const Icon(Icons.task_alt_outlined),
                label: const Text('Go to tasks'),
              ),
            )
          : AnimatedBuilder(
              animation: taskStore,
              builder: (context, _) {
                final reminders = taskStore.tasks
                    .where((t) => t.reminderAt != null)
                    .toList()
                  ..sort(
                    (a, b) => a.reminderAt!.compareTo(b.reminderAt!),
                  );
                if (reminders.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.notifications_outlined,
                    title: 'No reminders yet',
                    message:
                        'Add a reminder to a task and it will show up here.',
                    action: FilledButton.icon(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.home,
                        (route) => false,
                      ),
                      icon: const Icon(Icons.task_alt_outlined),
                      label: const Text('Go to tasks'),
                    ),
                  );
                }

                final now = DateTime.now();
                final overdue = <Task>[];
                final upcoming = <Task>[];
                for (final t in reminders) {
                  if (t.reminderAt!.isBefore(now) && !t.isCompleted) {
                    overdue.add(t);
                  } else {
                    upcoming.add(t);
                  }
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (overdue.isNotEmpty) ...[
                      _SectionHeader(
                        title: 'Overdue',
                        count: overdue.length,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 8),
                      ...overdue.map((t) => _ReminderTile(task: t)),
                      const SizedBox(height: 16),
                    ],
                    _SectionHeader(
                      title: 'Upcoming',
                      count: upcoming.length,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    ...upcoming.map((t) => _ReminderTile(task: t)),
                  ],
                );
              },
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = task.reminderAt!;
    final isDone = task.isCompleted;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isDone
              ? Icons.notifications_off_outlined
              : Icons.notifications_active_outlined,
          color: isDone ? theme.colorScheme.outline : theme.colorScheme.primary,
        ),
        title: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(_formatDate(due)),
        trailing: isDone
            ? const Chip(label: Text('Done'))
            : null,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (day == today) return 'Today $hh:$mm';
    if (day == today.add(const Duration(days: 1))) {
      return 'Tomorrow $hh:$mm';
    }
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hh:$mm';
  }
}
