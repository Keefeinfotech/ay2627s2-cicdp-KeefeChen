import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/responsive_page_layout.dart';

import 'package:frontend/features/home/data/api_task_repository.dart';

import '../../../home/data/task_store.dart';
import '../../data/models/project.dart';
import '../controllers/project_controller.dart';
import '../widgets/project_card.dart';
import '../widgets/project_editor_dialog.dart';
import 'project_detail_page.dart';

/// Project workspace grouping tasks by course or personal initiative.
class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key, required this.ownerId, this.store});

  final String ownerId;
  final TaskStore? store;

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  final TextEditingController _search = TextEditingController();
  late final TaskStore _store;
  late final bool _ownsStore;
  late final ProjectController _controller;
  String _view = 'table';

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.store == null;
    _store =
        widget.store ??
        TaskStore(repository: ApiTaskRepository(), ownerId: widget.ownerId);
    _controller = ProjectController(store: _store, ownerId: widget.ownerId)
      ..addListener(_changed);
    if (!_store.hasLoaded && !_store.isLoading) _store.load();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    if (_ownsStore) _store.dispose();
    _search.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _createProject() async {
    final draft = await showProjectEditorDialog(context);
    if (draft == null || !mounted) return;
    final saved = await _controller.createProject(draft);
    if (!mounted) return;
    AppSnackBar.show(
      context,
      saved
          ? 'Project created.'
          : _controller.error ?? 'Could not create the project.',
      type: saved ? AppSnackType.success : AppSnackType.error,
    );
  }

  Future<void> _editProject(Project project) async {
    final draft = await showProjectEditorDialog(context, initial: project);
    if (draft == null || !mounted) return;
    final saved = await _controller.updateProject(project.id, draft);
    if (!mounted) return;
    AppSnackBar.show(
      context,
      saved ? 'Project updated.' : _controller.error ?? 'Update failed.',
      type: saved ? AppSnackType.success : AppSnackType.error,
    );
  }

  Future<void> _archiveProject(Project project) async {
    final archived = project.effectiveStatus == ProjectStatus.archived;
    final saved = await _controller.setArchived(project.id, !archived);
    if (!mounted) return;
    AppSnackBar.show(
      context,
      saved
          ? archived
                ? 'Project restored.'
                : 'Project archived.'
          : _controller.error ?? 'Could not update the project.',
      type: saved ? AppSnackType.success : AppSnackType.error,
    );
  }

  Future<void> _deleteProject(Project project) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete project?',
      message:
          '“${project.name}” will be removed. Its tasks stay in Tasks but are '
          'no longer grouped under this project.',
      confirmLabel: 'Delete project',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;
    final saved = await _controller.deleteProject(project.id);
    if (!mounted) return;
    AppSnackBar.show(
      context,
      saved ? 'Project deleted.' : _controller.error ?? 'Delete failed.',
      type: saved ? AppSnackType.success : AppSnackType.error,
    );
  }

  Future<void> _showActions(Project project) async {
    final archived = project.effectiveStatus == ProjectStatus.archived;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit project'),
              onTap: () => Navigator.of(sheetContext).pop('edit'),
            ),
            ListTile(
              leading: Icon(
                archived ? Icons.unarchive_outlined : Icons.archive_outlined,
              ),
              title: Text(archived ? 'Restore project' : 'Archive project'),
              onTap: () => Navigator.of(sheetContext).pop('archive'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: Text(
                'Delete project',
                style: TextStyle(
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
              ),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        await _editProject(project);
      case 'archive':
        await _archiveProject(project);
      case 'delete':
        await _deleteProject(project);
    }
  }

  void _openProject(Project project) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDetailPage(
          projectId: project.id,
          ownerId: widget.ownerId,
          store: _store,
          controller: _controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: RefreshIndicator(
              onRefresh: _controller.retry,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: <Widget>[
                  _buildProjectViewSwitcher(context),
                  const SizedBox(height: 12),
                  _buildProjectToolbar(context),
                  const SizedBox(height: 16),
                  if (_controller.hasLoaded) _summary(context),
                  if (_controller.hasLoaded)
                    const SizedBox(height: AppSpacing.lg),
                  if (_controller.error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppErrorBanner(
                      message: _controller.error!,
                      onRetry: _controller.retry,
                      onDismiss: _controller.clearError,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  if (_controller.isLoading && !_controller.hasLoaded)
                    const TaskListSkeleton(itemCount: 4)
                  else if (_controller.projects.isEmpty)
                    _emptyState(context)
                  else if (_controller.filteredProjects.isEmpty)
                    _noMatches(context)
                  else
                    ResponsiveGrid(
                      minItemWidth: 280,
                      children: _controller.filteredProjects
                          .map(
                            (project) => ProjectCard(
                              project: project,
                              onTap: () => _openProject(project),
                              onMenu: () => _showActions(project),
                            ),
                          )
                          .toList(growable: false),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectViewSwitcher(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    Widget chip(String id, String label, IconData icon) {
      final sel = _view == id;
      return ChoiceChip(
        showCheckmark: false,
        avatar: Icon(
          icon,
          size: 16,
          color: sel ? scheme.primary : scheme.onSurfaceVariant,
        ),
        label: Text(label),
        selected: sel,
        onSelected: (_) => setState(() => _view = id),
        selectedColor: scheme.primary.withValues(alpha: 0.12),
        side: BorderSide(
          color: sel
              ? scheme.primary.withValues(alpha: 0.4)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : scheme.outlineVariant),
        ),
        labelStyle: TextStyle(
          fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
          color: sel ? scheme.primary : scheme.onSurfaceVariant,
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : scheme.surface,
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('table', 'Main Table', Icons.table_rows_rounded),
        chip('board', 'Board', Icons.view_kanban_outlined),
        chip('calendar', 'Calendar', Icons.calendar_month_outlined),
      ],
    );
  }

  Widget _buildProjectToolbar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : scheme.outlineVariant;
    OutlinedButton ghost(IconData icon, String label, VoidCallback onTap) =>
        OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 16),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: scheme.onSurfaceVariant,
            side: BorderSide(color: border),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: _createProject,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New project'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        SizedBox(
          width: 220,
          height: 40,
          child: TextField(
            controller: _search,
            onChanged: (v) {
              _controller.setQuery(v);
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              isDense: true,
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : scheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border),
              ),
            ),
          ),
        ),
        ghost(Icons.filter_list_rounded, 'Filter', () {}),
        ghost(Icons.swap_vert_rounded, 'Sort', () {}),
        ghost(Icons.layers_outlined, 'Group by', () {}),
      ],
    );
  }

  Widget _summary(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final progress = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Portfolio progress',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${_controller.completedTasks} of '
                '${_controller.totalTasks} tasks complete across '
                '${_controller.activeCount} active '
                '${_controller.activeCount == 1 ? 'project' : 'projects'}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: CompletionBar(
                      value: _controller.overallProgress,
                      color: AppColors.successGreen,
                      label: 'Overall project completion',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${(_controller.overallProgress * 100).round()}%',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.successGreen,
                    ),
                  ),
                ],
              ),
            ],
          );

          final stats = Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              _ProjectStat(
                label: 'Active',
                value: '${_controller.activeCount}',
              ),
              _ProjectStat(
                label: 'Completed',
                value: '${_controller.completedCount}',
                color: AppColors.successGreen,
              ),
              _ProjectStat(
                label: 'Archived',
                value: '${_controller.archivedCount}',
                color: scheme.onSurfaceVariant,
              ),
            ],
          );

          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                progress,
                const SizedBox(height: AppSpacing.lg),
                stats,
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(flex: 3, child: progress),
              const SizedBox(width: AppSpacing.xl),
              Expanded(flex: 2, child: stats),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AppEmptyState(
        icon: Icons.workspaces_outline,
        title: 'No projects yet',
        message:
            'Create a project to group related tasks, track progress and see '
            'what needs attention next. Tasks with a matching course appear '
            'here automatically.',
        action: AppButton(
          label: 'Create your first project',
          icon: Icons.add_rounded,
          onPressed: _createProject,
          expand: true,
        ),
      ),
    );
  }

  Widget _noMatches(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AppEmptyState(
        compact: true,
        icon: Icons.filter_alt_off_outlined,
        title: 'No matching projects',
        message: 'Try another search or switch the project filter.',
        action: AppButton(
          label: 'Clear filters',
          icon: Icons.filter_alt_off_rounded,
          variant: AppButtonVariant.outline,
          onPressed: () {
            _search.clear();
            _controller.setQuery('');
            _controller.setFilter(ProjectFilter.active);
          },
        ),
      ),
    );
  }
}

class _ProjectStat extends StatelessWidget {
  const _ProjectStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
