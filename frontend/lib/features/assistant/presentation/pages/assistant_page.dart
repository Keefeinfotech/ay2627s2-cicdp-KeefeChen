import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_app_bar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../authentication/models/session.dart';
import 'package:frontend/features/home/data/api_task_repository.dart';
import '../../../home/data/task_store.dart';
import '../../../home/models/task.dart';
import '../../../task_management/data/models/task_breakdown.dart';
import '../../../task_management/domain/usecases/parse_quick_add.dart';
import '../../../task_management/presentation/widgets/task_breakdown_sheet.dart';
import '../../data/assistant_service.dart';
import '../../models/chat_message.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/chat_composer.dart';

const List<String> _quickPrompts = <String>[
  'What should I work on today?',
  'Create a task',
  'Plan my week',
  'Summarise my progress',
  'Break down a project',
];

/// Conversational assistant surface used inside the responsive application
/// shell. It keeps the existing `{message}` -> `{reply}` API contract while
/// adding local, confirmation-first task actions.
class AssistantPage extends StatefulWidget {
  const AssistantPage({
    super.key,
    required this.ownerId,
    this.session,
    this.store,
    this.api,
  });

  final String ownerId;
  final Session? session;
  final TaskStore? store;
  final ApiClient? api;

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _composerFocus = FocusNode();
  final List<Object> _entries = <Object>[];
  late final AssistantService _service = AssistantService(api: widget.api);
  late final TaskStore _store;
  late final bool _ownsStore;
  final ParseQuickAdd _parser = const ParseQuickAdd();
  bool _typing = false;
  bool _awaitingTaskDescription = false;

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.store == null;
    _store =
        widget.store ??
        TaskStore(repository: ApiTaskRepository(), ownerId: widget.ownerId);
    if (_ownsStore && !_store.hasLoaded && !_store.isLoading) _store.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _composerFocus.dispose();
    if (_ownsStore) _store.dispose();
    super.dispose();
  }

  bool get _hasMessages => _entries.isNotEmpty;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _addAssistantMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _entries.add(
        _MessageEntry(
          ChatMessage(role: ChatRole.assistant, text: text, isError: isError),
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _typing) return;
    _controller.clear();
    setState(() {
      _entries.add(_MessageEntry(ChatMessage(role: ChatRole.user, text: text)));
      _typing = true;
    });
    _scrollToBottom();

    try {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      await _respondTo(text);
    } finally {
      if (mounted) {
        setState(() => _typing = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _respondTo(String text) async {
    final normalized = text.trim().toLowerCase().replaceAll(
      RegExp(r'[.!?]+$'),
      '',
    );

    if (normalized == 'create a task' || normalized == 'create task') {
      _awaitingTaskDescription = true;
      _addAssistantMessage(
        'Tell me what the task is. Include a due date, priority or project '
        'if you want, for example: "Revise calculus tomorrow high priority".',
      );
      return;
    }

    if (normalized == 'update a task' || normalized == 'edit a task') {
      _addAssistantMessage(
        'Include the task title and the change, for example: '
        '"Update task Revise calculus tomorrow high priority".',
      );
      return;
    }

    if (normalized == 'delete a task' || normalized == 'remove a task') {
      _addAssistantMessage(
        'Include the task title you want to remove, for example: '
        '"Delete task Revise calculus".',
      );
      return;
    }

    if (_awaitingTaskDescription) {
      _awaitingTaskDescription = false;
      _showAction(
        _AssistantAction(kind: _ActionKind.create, preview: _parse(text)),
      );
      return;
    }

    final action = _detectAction(text);
    if (action != null) {
      _showAction(action);
      return;
    }

    if (normalized == 'what should i work on today?') {
      _addAssistantMessage(_focusAdvice());
      return;
    }
    if (normalized == 'summarise my progress' ||
        normalized == 'summarize my progress') {
      _addAssistantMessage(_progressSummary());
      return;
    }
    if (normalized == 'break down a project') {
      await _breakDownProject();
      return;
    }
    if (normalized == 'plan my week' && widget.session == null) {
      _addAssistantMessage(_weekPlan());
      return;
    }

    final session = widget.session;
    if (session == null) {
      _addAssistantMessage(
        'Sign in to chat with the AI assistant. Local task actions still work: '
        'try "Create a task to revise calculus tomorrow".',
      );
      return;
    }

    try {
      final reply = await _service.sendMessage(
        token: session.token,
        message: text,
      );
      if (!mounted) return;
      _addAssistantMessage(reply);
    } on ApiException catch (err) {
      if (!mounted) return;
      _addAssistantMessage(
        err.isUnauthorized
            ? 'Your session has expired. Please sign in again.'
            : err.message,
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;
      _addAssistantMessage(
        'Something went wrong while contacting the assistant. '
        'Your tasks were not changed.',
        isError: true,
      );
    }
  }

  Future<void> _usePrompt(String prompt) async {
    if (_typing) return;
    _controller.text = prompt;
    _controller.selection = TextSelection.collapsed(offset: prompt.length);
    _composerFocus.requestFocus();
    await _send();
  }

  _AssistantAction? _detectAction(String text) {
    final lower = text.trim().toLowerCase();

    if (_startsWithAny(lower, <String>[
      'create a task',
      'create task',
      'add a task',
      'add task',
      'new task',
      'remind me to',
    ])) {
      return _AssistantAction(kind: _ActionKind.create, preview: _parse(text));
    }

    if (_startsWithAny(lower, <String>[
      'update task ',
      'update the task ',
      'edit task ',
      'edit the task ',
      'change task ',
      'rename task ',
    ])) {
      final rest = _stripPrefix(lower, <String>[
        'update task ',
        'update the task ',
        'edit task ',
        'edit the task ',
        'change task ',
        'rename task ',
      ]);
      final task = _resolveTaskMatch(_taskLookupQuery(rest), action: 'update');
      if (task == null) return null;
      return _AssistantAction(
        kind: _ActionKind.update,
        task: task,
        preview: _parse(rest.isEmpty ? task.title : rest),
      );
    }

    if (_startsWithAny(lower, <String>[
      'delete task ',
      'delete the task ',
      'remove task ',
      'remove the task ',
    ])) {
      final rest = _stripPrefix(lower, <String>[
        'delete task ',
        'delete the task ',
        'remove task ',
        'remove the task ',
      ]);
      final task = _resolveTaskMatch(_taskLookupQuery(rest), action: 'delete');
      if (task == null) return null;
      return _AssistantAction(
        kind: _ActionKind.delete,
        task: task,
        preview: _parse(task.title),
      );
    }

    return null;
  }

  bool _startsWithAny(String text, List<String> prefixes) {
    for (final prefix in prefixes) {
      if (text.startsWith(prefix)) return true;
    }
    return false;
  }

  String _stripPrefix(String text, List<String> prefixes) {
    for (final prefix in prefixes) {
      if (text.startsWith(prefix)) {
        return text.substring(prefix.length).trim();
      }
    }
    return text.trim();
  }

  /// Resolves a user-supplied title to one task. Exact matches win; when
  /// several partial matches remain, the assistant asks for clarification
  /// instead of silently choosing one.
  Task? _resolveTaskMatch(String query, {required String action}) {
    final candidates = _findTaskCandidates(query);
    if (candidates.isEmpty) {
      _addAssistantMessage(
        'I could not find a task matching that title. Try using the exact '
        'task title, or $action it from the Tasks tab.',
      );
      return null;
    }

    final normalized = _normalize(query);
    final exact = candidates
        .where((task) => _normalize(task.title) == normalized)
        .toList(growable: false);
    if (exact.length == 1) return exact.single;

    if (candidates.length > 1) {
      final preview = candidates
          .take(3)
          .map((task) => '"${task.title}"')
          .join(', ');
      _addAssistantMessage(
        'I found several matching tasks: $preview. '
        'Please use the exact task title so I do not $action the wrong one.',
      );
      return null;
    }

    return candidates.single;
  }

  List<Task> _findTaskCandidates(String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return const <Task>[];

    final matches = <Task>[];
    for (final task in _store.tasks) {
      final title = _normalize(task.title);
      if (title.isEmpty) continue;
      if (title == normalized ||
          normalized.contains(title) ||
          title.contains(normalized)) {
        matches.add(task);
      }
    }
    matches.sort((a, b) => b.title.length.compareTo(a.title.length));
    return List<Task>.unmodifiable(matches);
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Extracts the likely existing-task title from a natural-language command.
  /// Dates and priorities are modifiers, not part of the title.
  String _taskLookupQuery(String text) {
    return _parse(text).title;
  }

  TaskQuickAddData _parse(String text) {
    final projects = <String>{
      for (final task in _store.tasks)
        if (task.course.trim().isNotEmpty) task.course.trim(),
    }.toList();
    final preview = _parser(text, projects: projects);
    return TaskQuickAddData(
      title: _capitalise(preview.title),
      priority: preview.priority,
      dueDate: preview.dueDate,
      project: preview.project,
      dueLabel: preview.dueLabel,
    );
  }

  /// Assistant previews should read like task titles even when the parser
  /// stripped a lowercase conversational prefix (for example
  /// "create a task to buy milk" becomes "Buy milk").
  String _capitalise(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  void _showAction(_AssistantAction action) {
    final String message = switch (action.kind) {
      _ActionKind.create =>
        'I prepared this task. Review it, then confirm to add it to your list.',
      _ActionKind.update =>
        'I found “${action.task?.title ?? action.preview.title}”. Review the '
            'changes before applying them.',
      _ActionKind.delete =>
        'I found “${action.task?.title ?? action.preview.title}”. Deleting it '
            'cannot be undone from this conversation.',
    };
    setState(() {
      _entries.add(
        _MessageEntry(ChatMessage(role: ChatRole.assistant, text: message)),
      );
      _entries.add(_ActionEntry(action));
    });
    _scrollToBottom();
  }

  Future<void> _confirmAction(_AssistantAction action) async {
    if (action.status != _ActionStatus.pending) return;
    setState(() => action.status = _ActionStatus.working);

    bool saved = false;
    String success = 'Action applied.';
    try {
      switch (action.kind) {
        case _ActionKind.create:
          saved = await _store.addTask(
            TaskDraft(
              title: action.preview.title,
              priority: action.preview.priority,
              dueDate: action.preview.dueDate,
              course: action.preview.project ?? '',
            ),
          );
          success = 'Task created: ${action.preview.title}.';
        case _ActionKind.update:
          final task = action.task;
          if (task == null) break;
          saved = await _store.updateTask(
            task.id,
            TaskDraft(
              title: action.preview.title.trim().isEmpty
                  ? task.title
                  : action.preview.title,
              notes: task.notes,
              course: action.preview.project ?? task.course,
              priority: action.preview.priority,
              dueDate: action.preview.dueDate ?? task.dueDate,
              reminderAt: task.reminderAt,
            ),
          );
          success = 'Task updated: ${action.preview.title}.';
        case _ActionKind.delete:
          final task = action.task;
          if (task == null) break;
          saved = await _store.deleteTask(task.id);
          success = 'Task deleted: ${task.title}.';
      }
    } finally {
      if (mounted) {
        setState(() {
          action.status = saved ? _ActionStatus.done : _ActionStatus.pending;
        });
        if (saved) {
          _addAssistantMessage(success);
          if (action.kind == _ActionKind.delete && action.task != null) {
            final deleted = action.task!;
            AppSnackBar.show(
              context,
              'Task deleted.',
              type: AppSnackType.success,
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  final restored = await _store.restoreTask(deleted);
                  if (!mounted) return;
                  AppSnackBar.show(
                    context,
                    restored ? 'Task restored.' : 'Could not restore the task.',
                    type: restored ? AppSnackType.success : AppSnackType.error,
                  );
                },
              ),
            );
          }
        } else {
          _addAssistantMessage(
            _store.error ?? 'The action could not be saved. Please try again.',
            isError: true,
          );
        }
      }
    }
  }

  void _cancelAction(_AssistantAction action) {
    if (action.status != _ActionStatus.pending) return;
    setState(() => action.status = _ActionStatus.cancelled);
    _addAssistantMessage('Cancelled. Nothing was changed.');
  }

  Future<void> _breakDownProject() async {
    final candidates = _store.tasks
        .where((task) => !task.isCompleted)
        .toList(growable: false);
    if (candidates.isEmpty) {
      _addAssistantMessage(
        'There are no open tasks to break down yet. Add a task first, then ask '
        'me to plan its steps.',
      );
      return;
    }

    final sorted = List<Task>.of(candidates);
    sorted.sort((a, b) {
      final courseA = a.course.trim().isEmpty ? 1 : 0;
      final courseB = b.course.trim().isEmpty ? 1 : 0;
      if (courseA != courseB) return courseA.compareTo(courseB);
      final dueA = a.dueDate;
      final dueB = b.dueDate;
      if (dueA != null && dueB != null) return dueA.compareTo(dueB);
      if (dueA != null) return -1;
      if (dueB != null) return 1;
      return 0;
    });
    final task = sorted.first;

    setState(() => _typing = false);
    var created = 0;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaskBreakdownSheet(
        taskTitle: task.title,
        project: task.course.trim().isEmpty ? null : task.course.trim(),
        onApprove: (subtasks) async {
          created = await _addSubtasks(task, subtasks);
          return created;
        },
      ),
    );
    if (!mounted) return;
    if (created > 0) {
      _addAssistantMessage(
        'Added $created planning ${created == 1 ? 'step' : 'steps'} to '
        '“${task.title}”.',
      );
    }
  }

  Future<int> _addSubtasks(
    Task parent,
    List<SubtaskSuggestion> subtasks,
  ) async {
    var created = 0;
    for (final subtask in subtasks) {
      final saved = await _store.addTask(
        TaskDraft(
          title: subtask.title,
          notes: '${subtask.description}\n\nPart of: ${parent.title}',
          course: parent.course,
          priority: parent.priority,
          dueDate: DateTime.now().add(Duration(days: subtask.order)),
        ),
      );
      if (saved) created += 1;
    }
    return created;
  }

  String _focusAdvice() {
    final pending = _store.tasks
        .where((task) => !task.isCompleted)
        .toList(growable: false);
    if (pending.isEmpty) {
      return _store.tasks.isEmpty
          ? 'You have no tasks yet. Create your first task and I will help you '
                'decide what to work on next.'
          : 'Everything on your list is complete. Take a moment to review the '
                'week in Reports, or add the next piece of work.';
    }

    final sorted = List<Task>.of(pending);
    sorted.sort((a, b) {
      if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
      final dueA = a.dueDate;
      final dueB = b.dueDate;
      if (dueA != null && dueB != null) return dueA.compareTo(dueB);
      if (dueA != null) return -1;
      if (dueB != null) return 1;
      return b.priority.index.compareTo(a.priority.index);
    });

    final top = sorted.take(3).toList(growable: false);
    final buffer = StringBuffer('Start with these, in order:\n');
    for (var index = 0; index < top.length; index++) {
      final task = top[index];
      final due = task.dueDate == null
          ? 'no due date'
          : task.isOverdue
          ? 'overdue since ${formatDateOnly(task.dueDate!)}'
          : 'due ${formatTaskDate(task.dueDate!)}';
      buffer.write(
        '\n${index + 1}. ${task.title} · ${task.priority.label} priority, $due',
      );
    }
    if (sorted.length > top.length) {
      buffer.write(
        '\n\n${sorted.length - top.length} more '
        '${sorted.length - top.length == 1 ? 'task is' : 'tasks are'} waiting.',
      );
    }
    return buffer.toString();
  }

  String _progressSummary() {
    if (_store.tasks.isEmpty) {
      return 'You have no tasks yet. Add a task or use Reports once work is '
          'underway to see completion trends.';
    }
    final total = _store.tasks.length;
    final completed = _store.completedCount;
    final rate = (completed / total * 100).round();
    final String overdue = _store.overdueCount == 0
        ? 'nothing is overdue'
        : '${_store.overdueCount} '
              '${_store.overdueCount == 1 ? 'task is' : 'tasks are'} overdue';
    final String dueToday = _store.dueTodayCount == 0
        ? ''
        : '\nDue today: ${_store.dueTodayCount}.';
    final String week = _store.completedThisWeek == 0
        ? ''
        : '\nCompleted this week: ${_store.completedThisWeek}.';

    return 'You have completed $completed of $total tasks ($rate%).\n'
        'Right now $overdue.$dueToday$week\n\n'
        'Open Reports for the priority and project breakdowns.';
  }

  String _weekPlan() {
    final pending = _store.tasks
        .where((task) => !task.isCompleted)
        .toList(growable: false);
    if (pending.isEmpty) {
      return 'No open tasks to schedule. Add work first and I will help you '
          'spread it across the week.';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final horizon = today.add(const Duration(days: 7));
    final scheduled = pending
        .where((task) {
          final due = task.dueDate;
          return due != null && !due.isBefore(today) && due.isBefore(horizon);
        })
        .toList(growable: false);
    if (scheduled.isEmpty) {
      return 'Nothing is due in the next seven days. Use the time to get ahead '
          'on the highest priority task: ${_focusAdvice()}';
    }

    scheduled.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    final buffer = StringBuffer('Here is a simple plan for the next 7 days:\n');
    for (final task in scheduled.take(7)) {
      buffer.write(
        '\n• ${formatDateOnly(task.dueDate!)} — ${task.title} '
        '(${task.priority.label} priority)',
      );
    }
    return buffer.toString();
  }

  void _clearConversation() {
    setState(() {
      _entries.clear();
      _awaitingTaskDescription = false;
    });
  }

  void _openLogin() {
    Navigator.pushNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AuxiliaAppBar(
        title: 'Assistant',
        subtitle: 'Plan, organise and act in one conversation',
        actions: <Widget>[
          if (_hasMessages)
            IconButton(
              tooltip: 'New conversation',
              onPressed: _typing ? null : _clearConversation,
              icon: const Icon(Icons.add_comment_outlined),
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.maxChatWidth),
            child: Column(
              children: <Widget>[
                if (widget.session == null) _SignInBanner(onSignIn: _openLogin),
                Expanded(
                  child: _entries.isEmpty
                      ? _emptyConversation(context)
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.lg,
                            AppSpacing.lg,
                            AppSpacing.sm,
                          ),
                          itemCount: _entries.length + (_typing ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _entries.length) {
                              return const _TypingIndicator();
                            }
                            final entry = _entries[index];
                            if (entry is _MessageEntry) {
                              return ChatBubble(message: entry.message);
                            }
                            if (entry is _ActionEntry) {
                              return _ActionCard(
                                action: entry.action,
                                onConfirm: () => _confirmAction(entry.action),
                                onCancel: () => _cancelAction(entry.action),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                ),
                if (_typing && _entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _TypingIndicator(),
                  ),
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                  child: ChatComposer(
                    controller: _controller,
                    focusNode: _composerFocus,
                    onSend: _send,
                    isSending: _typing,
                    hintText: 'Ask Auxilia to plan, create or change a task...',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyConversation(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight > AppSpacing.huge
                  ? constraints.maxHeight - AppSpacing.huge
                  : 0,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: Icon(
                      Icons.auto_awesome_outlined,
                      size: AppSizes.iconXl,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'How can I help?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Text(
                      'Ask a question or manage work in plain language. I will '
                      'preview any task change before it is applied.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _quickPrompts
                        .map(
                          (prompt) => ActionChip(
                            avatar: Icon(
                              _promptIcon(prompt),
                              size: AppSizes.iconSm,
                              color: scheme.primary,
                            ),
                            label: Text(prompt),
                            onPressed: _typing
                                ? null
                                : () => _usePrompt(prompt),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.lock_outline_rounded,
                          size: AppSizes.iconSm,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Task previews stay on this device. Sending a '
                            'message to the AI assistant uses your signed-in '
                            'session.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _promptIcon(String prompt) {
    return switch (prompt) {
      'What should I work on today?' => Icons.bolt_outlined,
      'Create a task' => Icons.add_task_rounded,
      'Plan my week' => Icons.event_note_outlined,
      'Summarise my progress' => Icons.insights_outlined,
      'Break down a project' => Icons.account_tree_outlined,
      _ => Icons.chat_bubble_outline_rounded,
    };
  }
}

class _SignInBanner extends StatelessWidget {
  const _SignInBanner({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            size: AppSizes.iconSm,
            color: scheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Sign in for AI replies. Local task previews still work.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          TextButton(onPressed: onSignIn, child: const Text('Sign in')),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.auto_awesome_outlined,
              size: AppSizes.iconSm,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var index = 0; index < 3; index++) ...<Widget>[
                  if (index > 0) const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(
                        alpha: 0.35 + index * 0.2,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Auxilia is typing…',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.onConfirm,
    required this.onCancel,
  });

  final _AssistantAction action;
  final Future<void> Function() onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bool pending = action.status == _ActionStatus.pending;
    final bool working = action.status == _ActionStatus.working;
    final bool done = action.status == _ActionStatus.done;
    final bool cancelled = action.status == _ActionStatus.cancelled;
    final Color accent = action.kind == _ActionKind.delete
        ? scheme.error
        : done
        ? AppColors.successGreen
        : scheme.primary;

    return Padding(
      padding: const EdgeInsets.only(left: 40, bottom: AppSpacing.lg),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: pending || working
                ? accent.withValues(alpha: 0.45)
                : scheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    _kindIcon(action.kind),
                    size: AppSizes.iconSm,
                    color: accent,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _kindLabel(action.kind),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _kindCaption(action.kind),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: cancelled
                      ? 'Cancelled'
                      : done
                      ? 'Applied'
                      : working
                      ? 'Saving'
                      : 'Review',
                  color: cancelled
                      ? scheme.onSurfaceVariant
                      : done
                      ? AppColors.successGreen
                      : accent,
                  icon: cancelled
                      ? Icons.close_rounded
                      : done
                      ? Icons.check_rounded
                      : Icons.pending_outlined,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (action.kind == _ActionKind.delete && action.task != null)
              Text(
                action.task!.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.lineThrough,
                ),
              )
            else
              Text(
                action.preview.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                PriorityBadge(
                  label: '${action.preview.priority.label} priority',
                  color: switch (action.preview.priority) {
                    TaskPriority.high => scheme.error,
                    TaskPriority.medium => AppColors.warningAmber,
                    TaskPriority.low => scheme.primary,
                  },
                ),
                StatusBadge(
                  label: action.preview.dueDate == null
                      ? 'No due date'
                      : 'Due ${action.preview.dueLabel}',
                  color: action.preview.dueDate == null
                      ? scheme.onSurfaceVariant
                      : scheme.primary,
                  icon: Icons.event_outlined,
                ),
                StatusBadge(
                  label: action.preview.project?.trim().isNotEmpty == true
                      ? action.preview.project!
                      : action.task?.course.trim().isNotEmpty == true
                      ? action.task!.course
                      : 'No project',
                  color: scheme.onSurfaceVariant,
                  icon: Icons.workspaces_outline,
                ),
              ],
            ),
            if (action.kind == _ActionKind.update && action.task != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Current title: ${action.task!.title}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (pending || working) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.ghost,
                    onPressed: working ? null : onCancel,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    label: 'Confirm',
                    icon: Icons.check_rounded,
                    variant: action.kind == _ActionKind.delete
                        ? AppButtonVariant.danger
                        : AppButtonVariant.primary,
                    isLoading: working,
                    onPressed: working ? null : onConfirm,
                  ),
                ],
              ),
            ] else if (cancelled || done) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                cancelled
                    ? 'No changes were made.'
                    : 'This change has been applied.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cancelled
                      ? scheme.onSurfaceVariant
                      : AppColors.successGreen,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _kindIcon(_ActionKind kind) {
    return switch (kind) {
      _ActionKind.create => Icons.add_task_rounded,
      _ActionKind.update => Icons.edit_outlined,
      _ActionKind.delete => Icons.delete_outline_rounded,
    };
  }

  String _kindLabel(_ActionKind kind) {
    return switch (kind) {
      _ActionKind.create => 'Create task',
      _ActionKind.update => 'Update task',
      _ActionKind.delete => 'Delete task',
    };
  }

  String _kindCaption(_ActionKind kind) {
    return switch (kind) {
      _ActionKind.create => 'AI-assisted · Review before adding',
      _ActionKind.update => 'AI-assisted · Review before saving',
      _ActionKind.delete => 'AI-assisted · Review before removing',
    };
  }
}

class _MessageEntry {
  const _MessageEntry(this.message);

  final ChatMessage message;
}

class _ActionEntry {
  const _ActionEntry(this.action);

  final _AssistantAction action;
}

class _AssistantAction {
  _AssistantAction({required this.kind, required this.preview, this.task});

  final _ActionKind kind;
  final TaskQuickAddData preview;
  final Task? task;
  _ActionStatus status = _ActionStatus.pending;
}

enum _ActionKind { create, update, delete }

enum _ActionStatus { pending, working, done, cancelled }

/// Small value object shared by the preview card and task draft creation.
class TaskQuickAddData {
  const TaskQuickAddData({
    required this.title,
    required this.priority,
    required this.dueDate,
    required this.project,
    required this.dueLabel,
  });

  final String title;
  final TaskPriority priority;
  final DateTime? dueDate;
  final String? project;
  final String dueLabel;
}
