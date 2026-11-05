import 'package:flutter/material.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_app_bar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/responsive_page_layout.dart';
import '../../../authentication/models/session.dart';
import '../../../home/data/task_store.dart';
import '../../data/groups_repository.dart';
import '../../models/group.dart';
import '../widgets/group_dialogs.dart';

/// Group workspace: create and manage study groups, invite members and assign
/// shared tasks.
///
/// Group management requires a signed-in account because the backend scopes
/// groups to authenticated memberships. Guests see a sign-in gate rather than a
/// dead page.
class GroupsPage extends StatefulWidget {
  const GroupsPage({
    super.key,
    required this.store,
    this.session,
    this.repository,
  });

  final TaskStore store;
  final Session? session;

  /// Injectable for tests; production builds derive it from [session].
  final GroupsRepository? repository;

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  late final GroupsRepository? _repository =
      widget.repository ??
      (widget.session == null
          ? null
          : GroupsRepository(token: widget.session!.token));

  List<StudyGroup> _groups = const <StudyGroup>[];
  bool _loading = true;
  String? _error;
  String? _busyGroupId;

  @override
  void initState() {
    super.initState();
    if (_repository == null) {
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final repository = _repository;
    if (repository == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await repository.list();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createGroup() async {
    final repository = _repository;
    if (repository == null) return;

    final result = await showGroupFormDialog(context);
    if (result == null || !mounted) return;

    setState(() => _busyGroupId = 'create');
    try {
      await repository.create(
        name: result.name,
        description: result.description,
        isPublic: result.isPublic,
      );
      if (!mounted) return;
      AppSnackBar.success(context, 'Group created.');
      await _load();
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _busyGroupId = null);
    }
  }

  Future<void> _editGroup(StudyGroup group) async {
    final repository = _repository;
    if (repository == null) return;

    final result = await showGroupFormDialog(context, initial: group);
    if (result == null || !mounted) return;

    setState(() => _busyGroupId = group.id);
    try {
      await repository.update(
        group.id,
        name: result.name,
        description: result.description,
        isPublic: result.isPublic,
      );
      if (!mounted) return;
      AppSnackBar.success(context, 'Group updated.');
      await _load();
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _busyGroupId = null);
    }
  }

  Future<void> _archiveGroup(StudyGroup group) async {
    final repository = _repository;
    if (repository == null) return;

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Archive ${group.name}?',
      message:
          'The group will be removed from your list. Members keep their local '
          'tasks, but shared work will no longer be visible here.',
      confirmLabel: 'Archive group',
      destructive: true,
      icon: Icons.archive_outlined,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyGroupId = group.id);
    try {
      await repository.archive(group.id);
      if (!mounted) return;
      AppSnackBar.success(context, 'Group archived.');
      await _load();
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _busyGroupId = null);
    }
  }

  Future<void> _invite(StudyGroup group) async {
    final repository = _repository;
    if (repository == null) return;

    final request = await showInviteMemberDialog(context, group: group);
    if (request == null || !mounted) return;

    setState(() => _busyGroupId = group.id);
    try {
      final invitation = await repository.invite(
        groupId: group.id,
        email: request.email,
        role: request.role,
      );
      if (!mounted) return;
      // Stop the progress animation before opening a dialog that waits for the
      // user; otherwise the page would animate behind the dialog forever.
      setState(() => _busyGroupId = null);
      await showInvitationTokenDialog(context, invitation);
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _busyGroupId = null);
    }
  }

  Future<void> _joinGroup() async {
    final repository = _repository;
    if (repository == null) return;

    final token = await showJoinGroupDialog(context);
    if (token == null || !mounted) return;

    setState(() => _busyGroupId = 'join');
    try {
      await repository.accept(token);
      if (!mounted) return;
      AppSnackBar.success(context, 'You joined the group.');
      await _load();
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _busyGroupId = null);
    }
  }

  Future<void> _showMembers(StudyGroup group) async {
    final repository = _repository;
    if (repository == null) return;
    await showGroupMembersDialog(
      context,
      group: group,
      loadMembers: () => repository.members(group.id),
    );
  }

  Future<void> _assignTask(StudyGroup group) async {
    final repository = _repository;
    if (repository == null) return;

    setState(() => _busyGroupId = group.id);
    try {
      final members = await repository.members(group.id);
      if (!mounted) return;
      if (members.isEmpty) {
        AppSnackBar.warning(context, 'Invite a member before assigning work.');
        return;
      }

      final openTasks = widget.store.tasks
          .where((task) => !task.isCompleted)
          .toList(growable: false);
      setState(() => _busyGroupId = null);
      final request = await showAssignTaskDialog(
        context,
        group: group,
        members: members,
        tasks: openTasks,
      );
      if (request == null || !mounted) return;

      setState(() => _busyGroupId = group.id);
      final assigned = await widget.store.assignTask(
        request.taskId,
        groupId: group.id,
        assigneeId: request.member.userId,
        assigneeName: request.member.displayName,
      );
      if (!mounted) return;
      AppSnackBar.show(
        context,
        assigned
            ? 'Task assigned to ${request.member.displayName}.'
            : widget.store.error ?? 'The task could not be assigned.',
        type: assigned ? AppSnackType.success : AppSnackType.error,
      );
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _busyGroupId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePageLayout(
      appBar: const AuxiliaAppBar(
        title: 'Groups',
        subtitle: 'Study teams, members and shared work',
      ),
      child: _repository == null ? _signInGate(context) : _content(context),
    );
  }

  Widget _signInGate(BuildContext context) {
    return Center(
      child: AppEmptyState(
        icon: Icons.groups_outlined,
        title: 'Sign in to use groups',
        message:
            'Groups, invitations and shared assignments are tied to your '
            'account so teammates can find each other.',
        action: AppButton(
          label: 'Sign in',
          icon: Icons.login_rounded,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          _header(context),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppErrorBanner(message: _error!, onRetry: _load),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (_loading && _groups.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: AppLoading(label: 'Loading your groups...'),
            )
          else if (_groups.isEmpty)
            AppEmptyState(
              icon: Icons.group_work_outlined,
              title: 'No groups yet',
              message:
                  'Create a group for a course or project, then invite '
                  'teammates and assign tasks to them.',
              action: AppButton(
                label: 'Create your first group',
                icon: Icons.group_add_outlined,
                onPressed: _createGroup,
              ),
            )
          else
            ResponsiveGrid(
              minItemWidth: 320,
              children: <Widget>[
                for (final group in _groups) _groupCard(context, group),
              ],
            ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busy = _busyGroupId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Collaborate without losing your own plan',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Groups add shared members and assignments on top of your private '
          'task list. Personal tasks stay private.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            AppButton(
              label: 'Create group',
              icon: Icons.group_add_outlined,
              isLoading: _busyGroupId == 'create',
              onPressed: busy ? null : _createGroup,
            ),
            AppButton(
              label: 'Join with code',
              icon: Icons.vpn_key_outlined,
              variant: AppButtonVariant.secondary,
              isLoading: _busyGroupId == 'join',
              onPressed: busy ? null : _joinGroup,
            ),
            AppButton(
              label: 'Refresh',
              icon: Icons.refresh_rounded,
              variant: AppButtonVariant.ghost,
              onPressed: busy ? null : _load,
            ),
          ],
        ),
      ],
    );
  }

  Widget _groupCard(BuildContext context, StudyGroup group) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busy = _busyGroupId == group.id;
    final groupTasks = widget.store.tasks
        .where((task) => task.groupId == group.id)
        .toList(growable: false);
    final assigned = groupTasks.where((task) => task.isAssigned).length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  group.isPublic ? Icons.public_rounded : Icons.lock_outline,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      group.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (group.description.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        group.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (group.isOwner || group.canManage)
                PopupMenuButton<String>(
                  tooltip: 'Manage ${group.name}',
                  enabled: !busy,
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editGroup(group);
                      case 'archive':
                        _archiveGroup(group);
                    }
                  },
                  itemBuilder: (_) => <PopupMenuEntry<String>>[
                    if (group.isOwner)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit group'),
                      ),
                    if (group.isOwner)
                      const PopupMenuItem(
                        value: 'archive',
                        child: Text('Archive group'),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              StatusBadge(
                label: group.isPublic ? 'Public' : 'Private',
                color: group.isPublic
                    ? AppColors.successGreen
                    : scheme.onSurfaceVariant,
                icon: group.isPublic
                    ? Icons.public_rounded
                    : Icons.lock_outline,
              ),
              if (group.role != null)
                StatusBadge(
                  label: _roleLabel(group.role!),
                  color: scheme.primary,
                  icon: Icons.badge_outlined,
                ),
              StatusBadge(
                label: '${groupTasks.length} tasks',
                color: scheme.onSurfaceVariant,
                icon: Icons.checklist_rounded,
              ),
              if (assigned > 0)
                StatusBadge(
                  label: '$assigned assigned',
                  color: scheme.tertiary,
                  icon: Icons.assignment_ind_outlined,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              TextButton.icon(
                onPressed: busy ? null : () => _showMembers(group),
                icon: const Icon(Icons.people_alt_outlined, size: 18),
                label: const Text('Members'),
              ),
              TextButton.icon(
                onPressed: busy ? null : () => _assignTask(group),
                icon: const Icon(Icons.assignment_ind_outlined, size: 18),
                label: const Text('Assign task'),
              ),
              if (group.canManage)
                TextButton.icon(
                  onPressed: busy ? null : () => _invite(group),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text('Invite'),
                ),
            ],
          ),
          if (busy) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    return switch (role.toUpperCase()) {
      'OWNER' => 'Owner',
      'ADMIN' => 'Admin',
      _ => 'Member',
    };
  }
}
