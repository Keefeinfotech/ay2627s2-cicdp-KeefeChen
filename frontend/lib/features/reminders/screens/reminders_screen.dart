/// File Name: reminders_screen.dart
/// Description: Shows task-based reminders (due/overdue/upcoming) for the user.
/// The standalone route supplies an authenticated [TaskStore]; a null store is
/// kept only for direct instantiation and shows an informational state.
library;

import 'package:flutter/material.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../home/data/task_store.dart';
import '../../home/models/task.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key, this.store});

  /// Optional task store. The router supplies one; direct callers without a
  /// store see guidance instead of a false empty state.
  final TaskStore? store;

  void _goToTasks(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
    );
  }

  Widget _goToTasksButton(BuildContext context) {
    return AppButton(
      label: 'Go to tasks',
      icon: Icons.task_alt_outlined,
      onPressed: () => _goToTasks(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskStore = store;
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: taskStore == null
          ? Center(
              child: AppEmptyState(
                icon: Icons.notifications_outlined,
                title: 'Reminders live with your tasks',
                message: 'Open a task to add, edit, or snooze its reminder. Due reminders also appear in-app while you use Auxilia.',
                action: _goToTasksButton(context),
              ),
            )
          : AnimatedBuilder(
              animation: taskStore,
              builder: (context, _) {
                if (taskStore.isLoading && !taskStore.hasLoaded) {
                  return const Center(
                    child: AppLoading(label: 'Loading reminders...'),
                  );
                }
                if (taskStore.error != null && !taskStore.hasLoaded) {
                  return Center(
                    child: AppErrorState(
                      title: 'Could not load reminders',
                      message: taskStore.error!,
                      onRetry: taskStore.load,
                    ),
                  );
                }

                final reminders =
                    taskStore.tasks.where((t) => t.hasReminder).toList()
                      ..sort((a, b) => a.reminderAt!.compareTo(b.reminderAt!));
                if (reminders.isEmpty) {
                  return Center(
                    child: AppEmptyState(
                      icon: Icons.notifications_outlined,
                      title: 'No reminders yet',
                      message:
                          'Add a reminder to a task and it will show up here.',
                      action: _goToTasksButton(context),
                    ),
                  );
                }

                final now = DateTime.now();
                final overdue = <Task>[];
                final upcoming = <Task>[];
                for (final task in reminders) {
                  if (task.isReminderDue(now)) {
                    overdue.add(task);
                  } else {
                    upcoming.add(task);
                  }
                }

                return Column(
                  children: [
                    if (taskStore.error != null)
                      AppErrorBanner(
                        message: taskStore.error!,
                        onRetry: taskStore.load,
                      ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (overdue.isNotEmpty) ...[
                            _SectionHeader(
                              title: 'Overdue',
                              count: overdue.length,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(height: 8),
                            ...overdue.map((task) => _ReminderTile(task: task)),
                            const SizedBox(height: 16),
                          ],
                          _SectionHeader(
                            title: 'Upcoming',
                            count: upcoming.length,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          ...upcoming.map((task) => _ReminderTile(task: task)),
                        ],
                      ),
                    ),
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
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
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
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
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
        title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(_formatDate(due)),
        trailing: isDone ? const Chip(label: Text('Done')) : null,
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
