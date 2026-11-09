import 'package:flutter/material.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/level_up_toast.dart';
import '../../../core/widgets/toast_box.dart';
import '../../authentication/data/auth_service.dart';
import '../../authentication/data/session_store.dart';
import '../../profile/data/avatar_store.dart';
import '../../profile/widgets/profile_sheet.dart';
import '../../reminders/widgets/reminder_host.dart';
import '../data/api_task_repository.dart';
import '../data/gamification.dart';
import '../data/task_store.dart';
import '../data/task_validation.dart';
import '../models/task.dart';
import '../widgets/achievements_dialog.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/task_card.dart';
import '../widgets/task_editor.dart';
import '../widgets/task_filter_bar.dart';

/// The student's task dashboard.
///
/// The screen keeps the original offline-first [TaskStore] flow and only
/// changes presentation. Navigation arguments, owner scoping and all task
/// actions are unchanged.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.ownerId,
    this.displayName,
    this.session,
    this.store,
    this.avatarStore,
    this.onOpenAssistant,
    this.onOpenProfile,
  });

  final String ownerId;
  final String? displayName;
  final Session? session;
  final TaskStore? store;
  final AvatarStore? avatarStore;

  /// When provided, the shell selects its Assistant tab instead of pushing the
  /// legacy chat route.
  final VoidCallback? onOpenAssistant;

  /// When provided, the shell selects its Profile tab instead of opening the
  /// quick profile sheet.
  final VoidCallback? onOpenProfile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _search = TextEditingController();
  late final TaskStore _store;
  late final bool _ownsStore;

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.store == null;
    _store =
        widget.store ??
        TaskStore(
          repository: ApiTaskRepository(token: widget.session?.token ?? ''),
          ownerId: widget.ownerId,
        );
    _store.addListener(_handleStoreChanged);
    _store.load();
  }

  @override
  void dispose() {
    _store.removeListener(_handleStoreChanged);
    if (_ownsStore) _store.dispose();
    _search.dispose();
    super.dispose();
  }

  void _handleStoreChanged() {
    if (mounted) setState(() {});
  }

  void _showSnack(
    String message, {
    AppSnackType type = AppSnackType.info,
    SnackBarAction? action,
  }) {
    AppSnackBar.show(context, message, type: type, action: action);
  }

  Future<void> _createTask() async {
    final draft = await showModalBottomSheet<TaskDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaskEditor(existingTags: _store.allTags),
    );
    if (draft == null || !mounted) return;

    try {
      final saved = await _store.addTask(draft);
      if (!mounted) return;
      if (saved) {
        _showSnack('Task created.', type: AppSnackType.success);
      } else {
        _showSnack(
          _store.error ?? 'Could not create the task.',
          type: AppSnackType.error,
        );
      }
    } on TaskValidationException catch (err) {
      if (mounted) _showSnack(err.message, type: AppSnackType.error);
    }
  }

  Future<void> _editTask(Task task) async {
    final draft = await showModalBottomSheet<TaskDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaskEditor(initial: task, existingTags: _store.allTags),
    );
    if (draft == null || !mounted) return;

    try {
      final saved = await _store.updateTask(task.id, draft);
      if (!mounted) return;
      if (saved) {
        _showSnack('Task updated.', type: AppSnackType.success);
      } else {
        _showSnack(
          _store.error ?? 'Could not update the task.',
          type: AppSnackType.error,
        );
      }
    } on TaskValidationException catch (err) {
      if (mounted) _showSnack(err.message, type: AppSnackType.error);
    }
  }

  Future<void> _toggleTask(Task task) async {
    final xpGain = !task.isCompleted && !task.xpAwarded
        ? Gamification.xpByPriority[task.priority] ?? 0
        : 0;
    final wasCompleted = task.isCompleted;

    // Capture state before toggle so we can detect newly unlocked achievements
    // and level-ups after the store updates.
    final oldLevel = _store.levelProgress.level;
    final oldAchievements = _store.achievements.toSet();

    final saved = await _store.toggleCompletion(task.id);
    if (!mounted) return;

    if (!saved) {
      _showSnack(
        _store.error ?? 'Could not update the task.',
        type: AppSnackType.error,
      );
      return;
    }

    if (wasCompleted) {
      _showSnack('Task reopened. Earned XP is kept.', type: AppSnackType.info);
      return;
    }

    // Task completed — detect newly unlocked achievements and level ups.
    final newLevel = Gamification.levelForXp(Gamification.totalXp(_store.tasks));
    final newAchievements = _store.achievements.toSet();
    final newUnlocked = newAchievements.difference(oldAchievements);
    final leveledUp = newLevel > oldLevel;

    // Celebrate level up first (most prominent animation).
    if (leveledUp) {
      LevelUpToast.show(context, level: newLevel);
    }

    // Toast each newly unlocked achievement.
    for (final achievement in newUnlocked) {
      ToastBox.success(
        context,
        message: 'Achievement unlocked: ${achievement.title}',
        duration: const Duration(seconds: 5),
      );
    }

    // Task completion confirmation.
    ToastBox.success(
      context,
      message: xpGain > 0 ? 'Task completed · +$xpGain XP' : 'Task completed.',
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete task?',
      message: '"${task.title}" will be removed from this device.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    final saved = await _store.deleteTask(task.id);
    if (!mounted) return;
    if (!saved) {
      _showSnack(
        _store.error ?? 'Could not delete the task.',
        type: AppSnackType.error,
      );
      return;
    }

    _showSnack(
      'Task deleted.',
      type: AppSnackType.success,
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          final restored = await _store.restoreTask(task);
          if (!mounted) return;
          _showSnack(
            restored
                ? 'Task restored.'
                : _store.error ?? 'Could not restore the task.',
            type: restored ? AppSnackType.success : AppSnackType.error,
          );
        },
      ),
    );
  }

  Future<void> _clearAllTasks() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Remove all local tasks?',
      message:
          'Every task stored on this device will be permanently deleted. '
          'This cannot be undone.',
      confirmLabel: 'Remove all',
      destructive: true,
      icon: Icons.delete_sweep_outlined,
    );
    if (!confirmed || !mounted) return;

    final cleared = await _store.clearAll();
    if (!mounted) return;
    _showSnack(
      cleared
          ? 'All local tasks were removed.'
          : _store.error ?? 'Could not remove local tasks.',
      type: cleared ? AppSnackType.success : AppSnackType.error,
    );
  }

  Future<void> _signOut() async {
    try {
      await AuthService().logout();
    } on SessionException catch (err) {
      if (mounted) _showSnack(err.message, type: AppSnackType.error);
      return;
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  void _openLogin() {
    Navigator.pushNamed(context, AppRoutes.login);
  }

  void _openAssistant() {
    final session = widget.session;
    if (session == null) {
      _showSnack(
        'Sign in to use the AI assistant.',
        action: SnackBarAction(label: 'Sign in', onPressed: _openLogin),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.assistant,
      arguments: AssistantArgs(session: session),
    );
  }

  void _showAchievements() {
    showAchievementsDialog(context, achievements: _store.achievements);
  }

  void _showProfile() {
    showProfileSheet(
      context,
      store: _store,
      session: widget.session,
      displayName: widget.displayName,
      onAchievements: _showAchievements,
      onAssistant: _openAssistant,
      onClearTasks: _clearAllTasks,
      onSignOut: _signOut,
      onSignIn: _openLogin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTask,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New task'),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_store.isLoading && !_store.hasLoaded) {
      return const Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: AppLoading(label: 'Loading your tasks...'),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DashboardHeader(
            store: _store,
            displayName: widget.displayName,
            avatarStore: widget.avatarStore,
            onAchievements: _showAchievements,
            onProfile: _showProfile,
          ),
          const SizedBox(height: AppSpacing.lg),
          _toolbar(context),
          if (_store.pageCount > 1) ...[
            const SizedBox(height: AppSpacing.md),
            _pagination(context),
          ],
          if (_store.upcomingReminders.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            ReminderSection(store: _store, onOpenTask: _editTask),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppSectionHeader(
            title: 'Your tasks',
            subtitle: '${_store.filteredCount} shown',
          ),
          if (_store.isLoading && _store.hasLoaded) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: const LinearProgressIndicator(minHeight: 3),
            ),
          ],
          if (_store.error != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppErrorBanner(
              message: _store.error!,
              onRetry: _store.retry,
              onDismiss: _store.clearError,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          ..._taskSection(context),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTextField(
          controller: _search,
          onChanged: _store.setQuery,
          useFormField: false,
          hintText: 'Search tasks',
          prefixIcon: Icons.search_rounded,
          textInputAction: TextInputAction.search,
          suffixIcon: _store.query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _search.clear();
                    _store.setQuery('');
                  },
                  icon: const Icon(Icons.clear_rounded),
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        TaskFilterBar(store: _store),
      ],
    );
  }

  List<Widget> _taskSection(BuildContext context) {
    if (_store.tasks.isEmpty) {
      return <Widget>[
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppEmptyState(
            icon: Icons.checklist_rounded,
            title: 'No tasks yet',
            message:
                'Create your first task to start tracking progress and '
                'earning XP.',
            action: AppButton(
              label: 'Create your first task',
              icon: Icons.add_rounded,
              onPressed: _createTask,
              expand: true,
            ),
          ),
        ),
      ];
    }

    if (_store.filteredCount == 0) {
      return <Widget>[
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppEmptyState(
            compact: true,
            icon: Icons.filter_alt_off_outlined,
            title: 'No matching tasks',
            message: 'No tasks match your search or filter.',
            action: AppButton(
              label: 'Clear filters',
              icon: Icons.filter_alt_off_rounded,
              variant: AppButtonVariant.outline,
              onPressed: () {
                _search.clear();
                _store.setQuery('');
                _store.setFilter(TaskFilter.all);
              },
            ),
          ),
        ),
      ];
    }

    final cards = _store.visibleTasks
        .map(
          (task) => TaskCard(
            task: task,
            onToggle: () => _toggleTask(task),
            onEdit: () => _editTask(task),
            onDelete: () => _deleteTask(task),
          ),
        )
        .toList(growable: false);

    return <Widget>[
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          children: <Widget>[
            for (var index = 0; index < cards.length; index++) ...<Widget>[
              if (index > 0)
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              cards[index],
            ],
          ],
        ),
      ),
    ];
  }

  Widget _pagination(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        IconButton(
          tooltip: 'Previous page',
          onPressed: _store.canGoToPreviousPage ? _store.previousPage : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Flexible(
          child: Text(
            'Page ${_store.page + 1} of ${_store.pageCount}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: _store.canGoToNextPage ? _store.nextPage : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}
