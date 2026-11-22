/// File Name: reminders_screen.dart
/// Description: Screen for displaying and managing user reminders.
/// Author: Keefe Chen
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../data/reminder_store.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key, this.store});

  final dynamic store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPending = ref.watch(pendingRemindersProvider);
    final isLoading = ref.watch(isLoadingRemindersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: isLoading
          ? const Center(
              child: SingleChildScrollView(
                child: TaskListSkeleton(itemCount: 4),
              ),
            )
          : Column(
              children: [
                // Pending reminders section
                if (asyncPending.value?.isNotEmpty == true) ...[
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Pending Reminders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: asyncPending.value?.length ?? 0,
                      itemBuilder: (context, index) {
                        final reminder = asyncPending.value![index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            title: Text(reminder.message),
                            subtitle: Text(
                              'Due: ${_formatDate(reminder.dueAt)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Semantics(
                                  label:
                                      'Mark "${reminder.message}" as completed',
                                  child: Checkbox(
                                    value: reminder.completed,
                                    onChanged: (bool? value) async {
                                      await completeReminder(ref, reminder.id);
                                      ref.invalidate(remindersProvider);
                                      ref.invalidate(pendingRemindersProvider);
                                    },
                                  ),
                                ),
                                if (!reminder.completed)
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    tooltip: 'Delete reminder',
                                    onPressed: () {
                                      ref
                                          .watch(reminderRepositoryProvider)
                                          .delete(reminder.id);
                                      ref.invalidate(remindersProvider);
                                      ref.invalidate(pendingRemindersProvider);
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No pending reminders.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],

                const Divider(),

                // Create new reminder
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.add_alert),
                      title: const Text('Add New Reminder'),
                      onTap: () {
                        // TODO: Show dialog to create reminder
                        AppSnackBar.info(
                          context,
                          'Adding reminders from this screen is coming soon.',
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return 'Today';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}
