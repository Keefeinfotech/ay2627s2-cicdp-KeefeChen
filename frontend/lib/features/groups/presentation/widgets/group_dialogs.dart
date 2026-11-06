import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../home/models/task.dart';
import '../../models/group.dart';

/// Values captured by the create/edit group form.
class GroupFormResult {
  const GroupFormResult({
    required this.name,
    required this.description,
    required this.isPublic,
  });

  final String name;
  final String description;
  final bool isPublic;
}

Future<GroupFormResult?> showGroupFormDialog(
  BuildContext context, {
  StudyGroup? initial,
}) {
  return showDialog<GroupFormResult>(
    context: context,
    builder: (_) => _GroupFormDialog(initial: initial),
  );
}

class _GroupFormDialog extends StatefulWidget {
  const _GroupFormDialog({this.initial});

  final StudyGroup? initial;

  @override
  State<_GroupFormDialog> createState() => _GroupFormDialogState();
}

class _GroupFormDialogState extends State<_GroupFormDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late bool _isPublic = widget.initial?.isPublic ?? false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Enter a group name (at least 2 characters).');
      return;
    }
    if (name.length > 80) {
      setState(() => _error = 'Keep the name under 80 characters.');
      return;
    }
    if (_description.text.trim().length > 500) {
      setState(() => _error = 'Keep the description under 500 characters.');
      return;
    }

    Navigator.of(context).pop(
      GroupFormResult(
        name: name,
        description: _description.text.trim(),
        isPublic: _isPublic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bool editing = widget.initial != null;

    return AlertDialog(
      icon: Icon(
        editing ? Icons.edit_outlined : Icons.group_add_outlined,
        size: 28,
      ),
      title: Text(editing ? 'Edit group' : 'Create a group'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppTextField(
                controller: _name,
                labelText: 'Group name',
                hintText: 'e.g. COMP 2101 Study Team',
                maxLength: 80,
                counterText: '',
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _description,
                labelText: 'Description (optional)',
                hintText: 'What is this group working on?',
                maxLines: 3,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isPublic,
                onChanged: (value) => setState(() => _isPublic = value),
                title: const Text('Public group'),
                subtitle: Text(
                  _isPublic
                      ? 'Anyone with the group link can view it.'
                      : 'Only invited members can view this group.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: editing ? 'Save changes' : 'Create group',
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// Invitation values captured before calling the API.
class InviteRequest {
  const InviteRequest({required this.email, required this.role});

  final String email;
  final String role;
}

Future<InviteRequest?> showInviteMemberDialog(
  BuildContext context, {
  required StudyGroup group,
}) {
  return showDialog<InviteRequest>(
    context: context,
    builder: (_) => _InviteMemberDialog(group: group),
  );
}

class _InviteMemberDialog extends StatefulWidget {
  const _InviteMemberDialog({required this.group});

  final StudyGroup group;

  @override
  State<_InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<_InviteMemberDialog> {
  final TextEditingController _email = TextEditingController();
  String _role = 'MEMBER';
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _email.text.trim();
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!valid) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    Navigator.of(context).pop(InviteRequest(email: email, role: _role));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      icon: const Icon(Icons.person_add_alt_1_outlined, size: 28),
      title: Text('Invite to ${widget.group.name}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTextField(
              controller: _email,
              labelText: 'Email address',
              hintText: 'teammate@example.com',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const <String>[AutofillHints.email],
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'MEMBER', child: Text('Member')),
                DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
              ],
              onChanged: (value) => setState(() => _role = value ?? 'MEMBER'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'The invitation link is shown once after creation. Share it '
              'with the recipient until email delivery is enabled.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(label: 'Create invitation', onPressed: _submit),
      ],
    );
  }
}

/// Shows the delivery result for a newly created invitation.
Future<void> showInvitationTokenDialog(
  BuildContext context,
  GroupInvitation invitation,
) async {
  final delivered = invitation.wasDeliveredByEmail;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(
        delivered ? Icons.mark_email_read_outlined : Icons.key_outlined,
        size: 28,
      ),
      title: Text(delivered ? 'Invitation sent' : 'Invitation created'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              delivered
                  ? 'We emailed an invitation to ${invitation.email}.'
                  : 'Send this code to ${invitation.email}:',
            ),
            if (!delivered) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(
                    dialogContext,
                  ).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: SelectableText(
                  invitation.token ?? '',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Expires ${_formatDate(invitation.expiresAt)}. The recipient '
              'accepts it from Groups → Join with code using this email.',
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        if (!delivered)
          TextButton.icon(
            onPressed: () async {
              final token = invitation.token;
              if (token == null) return;
              await Clipboard.setData(ClipboardData(text: token));
              if (dialogContext.mounted) {
                AppSnackBar.success(dialogContext, 'Invitation code copied.');
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy code'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

Future<String?> showJoinGroupDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _JoinGroupDialog(),
  );
}

class _JoinGroupDialog extends StatefulWidget {
  const _JoinGroupDialog();

  @override
  State<_JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends State<_JoinGroupDialog> {
  final TextEditingController _token = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  void _submit() {
    final token = _token.text.trim();
    if (token.length < 32) {
      setState(() => _error = 'Paste the full invitation code.');
      return;
    }
    Navigator.of(context).pop(token);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.group_outlined, size: 28),
      title: const Text('Join a group'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTextField(
              controller: _token,
              labelText: 'Invitation code',
              hintText: 'Paste the code you received',
              maxLines: 2,
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'The signed-in email must match the address the invitation was '
              'sent to.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(label: 'Join group', onPressed: _submit),
      ],
    );
  }
}

/// Shows the active roster of a group.
Future<void> showGroupMembersDialog(
  BuildContext context, {
  required StudyGroup group,
  required Future<List<GroupMember>> Function() loadMembers,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _GroupMembersDialog(group: group, loadMembers: loadMembers),
  );
}

class _GroupMembersDialog extends StatefulWidget {
  const _GroupMembersDialog({required this.group, required this.loadMembers});

  final StudyGroup group;
  final Future<List<GroupMember>> Function() loadMembers;

  @override
  State<_GroupMembersDialog> createState() => _GroupMembersDialogState();
}

class _GroupMembersDialogState extends State<_GroupMembersDialog> {
  late Future<List<GroupMember>> _members = widget.loadMembers();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      icon: const Icon(Icons.people_alt_outlined, size: 28),
      title: Text('${widget.group.name} members'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: FutureBuilder<List<GroupMember>>(
          future: _members,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text(
                'Members could not be loaded.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.error,
                ),
              );
            }
            final members = snapshot.data ?? const <GroupMember>[];
            if (members.isEmpty) {
              return Text(
                'No active members yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              );
            }
            return SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: members.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final member = members[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text(member.initials)),
                    title: Text(member.displayName),
                    subtitle: Text(
                      member.email ?? member.userId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      member.role,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: () => setState(() => _members = widget.loadMembers()),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// A task/member pair chosen in the assignment dialog.
class AssignTaskRequest {
  const AssignTaskRequest({required this.taskId, required this.member});

  final String taskId;
  final GroupMember member;
}

Future<AssignTaskRequest?> showAssignTaskDialog(
  BuildContext context, {
  required StudyGroup group,
  required List<GroupMember> members,
  required List<Task> tasks,
}) {
  return showDialog<AssignTaskRequest>(
    context: context,
    builder: (_) =>
        _AssignTaskDialog(group: group, members: members, tasks: tasks),
  );
}

class _AssignTaskDialog extends StatefulWidget {
  const _AssignTaskDialog({
    required this.group,
    required this.members,
    required this.tasks,
  });

  final StudyGroup group;
  final List<GroupMember> members;
  final List<Task> tasks;

  @override
  State<_AssignTaskDialog> createState() => _AssignTaskDialogState();
}

class _AssignTaskDialogState extends State<_AssignTaskDialog> {
  String? _taskId;
  String? _memberId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      icon: const Icon(Icons.assignment_ind_outlined, size: 28),
      title: Text('Assign work in ${widget.group.name}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.tasks.isEmpty)
              Text(
                'You have no open tasks to assign. Create a task first.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else ...<Widget>[
              DropdownButtonFormField<String>(
                initialValue: _taskId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Task'),
                items: <DropdownMenuItem<String>>[
                  for (final task in widget.tasks)
                    DropdownMenuItem(
                      value: task.id,
                      child: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _taskId = value),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _memberId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Assign to'),
                items: <DropdownMenuItem<String>>[
                  for (final member in widget.members)
                    DropdownMenuItem(
                      value: member.userId,
                      child: Text(
                        '${member.displayName} · ${member.role}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _memberId = value),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'The assignee sees the task in their shared group workspace.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: 'Assign task',
          onPressed:
              widget.tasks.isEmpty || _taskId == null || _memberId == null
              ? null
              : () {
                  final member = widget.members.firstWhere(
                    (item) => item.userId == _memberId,
                  );
                  Navigator.of(
                    context,
                  ).pop(AssignTaskRequest(taskId: _taskId!, member: member));
                },
        ),
      ],
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}
