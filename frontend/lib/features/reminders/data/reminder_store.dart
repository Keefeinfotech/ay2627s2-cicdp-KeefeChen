/// File Name: reminder_store.dart
/// Description: Riverpod provider definitions for reminders state.
/// Author: Keefe Chen
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'reminder_repository.dart';
import '../models/reminder_model.dart';

// Repository provider
final reminderRepositoryProvider = Provider((ref) => ReminderRepository());

// Future providers watched by screens via ref.watch()
final remindersProvider = FutureProvider.autoDispose<List<ReminderModel>>((ref) {
  final repo = ref.watch(reminderRepositoryProvider);
  return repo.fetchAll();
});

final pendingRemindersProvider =
    FutureProvider.autoDispose<List<ReminderModel>>((ref) {
  final repo = ref.watch(reminderRepositoryProvider);
  return repo.fetchPending();
});

// Loading state — Riverpod 3.x uses NotifierProvider
// (StateProvider was removed in Riverpod 3.0).
class _BoolNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setLoading(bool value) {
    state = value;
  }
}

final isLoadingRemindersProvider =
    NotifierProvider<_BoolNotifier, bool>(_BoolNotifier.new);

// Function to create a reminder - called from WidgetRef context
Future<ReminderModel> createReminder(
  WidgetRef ref,
  String message,
  DateTime dueAt,
) async {
  final repo = ref.watch(reminderRepositoryProvider);
  final isLoading = ref.watch(isLoadingRemindersProvider);
  if (isLoading) {
    throw Exception('Please wait, previous request still in progress');
  }
  ref.read(isLoadingRemindersProvider.notifier).setLoading(true);
  try {
    final reminder = await repo.create(message, dueAt);
    ref.invalidate(remindersProvider);
    ref.invalidate(pendingRemindersProvider);
    return reminder;
  } finally {
    ref.read(isLoadingRemindersProvider.notifier).setLoading(false);
  }
}

// Function to complete a reminder - called from WidgetRef context
Future<ReminderModel> completeReminder(WidgetRef ref, String id) async {
  final repo = ref.watch(reminderRepositoryProvider);
  final isLoading = ref.watch(isLoadingRemindersProvider);
  if (isLoading) {
    throw Exception('Please wait, previous request still in progress');
  }
  ref.read(isLoadingRemindersProvider.notifier).setLoading(true);
  try {
    final reminder = await repo.complete(id);
    ref.invalidate(remindersProvider);
    ref.invalidate(pendingRemindersProvider);
    return reminder;
  } finally {
    ref.read(isLoadingRemindersProvider.notifier).setLoading(false);
  }
}
