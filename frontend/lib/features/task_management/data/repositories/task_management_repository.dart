import '../../../home/data/task_store.dart';
import '../../../home/models/task.dart';

/// Thin repository boundary for the task-management feature.
///
/// The existing offline-first [TaskStore] remains the implementation so tasks
/// created in the dashboard, quick-add sheet or assistant preview all appear in
/// the same list.
class TaskManagementRepository {
  const TaskManagementRepository(this.store);

  final TaskStore store;

  Future<bool> create(TaskDraft draft) => store.addTask(draft);

  Future<bool> update(String id, TaskDraft draft) =>
      store.updateTask(id, draft);

  Future<bool> toggle(String id) => store.toggleCompletion(id);

  Future<bool> delete(String id) => store.deleteTask(id);

  Future<bool> restore(Task task) => store.restoreTask(task);

  Future<void> refresh() => store.load();

  List<String> get projects {
    final values = <String>{
      for (final task in store.tasks)
        if (task.course.trim().isNotEmpty) task.course.trim(),
    };
    final sorted = values.toList()..sort();
    return sorted;
  }
}
