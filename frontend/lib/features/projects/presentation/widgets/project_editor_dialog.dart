import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/project.dart';

/// Dialog for creating or editing the metadata attached to a project.
Future<ProjectDraft?> showProjectEditorDialog(
  BuildContext context, {
  Project? initial,
}) {
  return showDialog<ProjectDraft>(
    context: context,
    builder: (_) => _ProjectEditorDialog(initial: initial),
  );
}

class _ProjectEditorDialog extends StatefulWidget {
  const _ProjectEditorDialog({this.initial});

  final Project? initial;

  @override
  State<_ProjectEditorDialog> createState() => _ProjectEditorDialogState();
}

class _ProjectEditorDialogState extends State<_ProjectEditorDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late DateTime? _deadline = widget.initial?.deadline;
  String? _error;

  bool get _isEditing => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 14)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (date != null && mounted) setState(() => _deadline = date);
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the project a name.');
      return;
    }
    Navigator.of(context).pop(
      ProjectDraft(
        name: name,
        description: _description.text.trim(),
        deadline: _deadline,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: <Widget>[
          Icon(
            _isEditing ? Icons.edit_outlined : Icons.add_box_outlined,
            color: scheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _isEditing ? 'Edit project' : 'New project',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppTextField(
                controller: _name,
                labelText: 'Project name',
                hintText: 'e.g. COMP 2101 coursework',
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _description,
                labelText: 'Description (optional)',
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.event_outlined,
                      size: AppSizes.iconMd,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _deadline == null
                            ? 'No project deadline'
                            : 'Deadline ${formatDateOnly(_deadline!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _pickDeadline,
                      child: Text(_deadline == null ? 'Set date' : 'Change'),
                    ),
                    if (_deadline != null)
                      IconButton(
                        tooltip: 'Clear project deadline',
                        onPressed: () => setState(() => _deadline = null),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: AppSizes.iconSm,
                        ),
                      ),
                  ],
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
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save changes' : 'Create project'),
        ),
      ],
    );
  }
}
