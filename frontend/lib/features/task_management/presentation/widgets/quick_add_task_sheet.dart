import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../home/models/task.dart';
import '../../data/models/quick_add_preview.dart';
import '../../domain/usecases/parse_quick_add.dart';

/// Quick-add sheet with a live natural-language preview.
class QuickAddTaskSheet extends StatefulWidget {
  const QuickAddTaskSheet({
    super.key,
    required this.onSubmit,
    this.projects = const <String>[],
    this.initialPriority = TaskPriority.medium,
    this.initialProject,
    this.initialTitle,
    this.parser = const ParseQuickAdd(),
  });

  final Future<bool> Function(TaskDraft draft) onSubmit;
  final List<String> projects;
  final TaskPriority initialPriority;
  final String? initialProject;
  final String? initialTitle;
  final ParseQuickAdd parser;

  @override
  State<QuickAddTaskSheet> createState() => _QuickAddTaskSheetState();
}

class _QuickAddTaskSheetState extends State<QuickAddTaskSheet> {
  late final TextEditingController _input = TextEditingController(
    text: widget.initialTitle ?? '',
  );
  late final TextEditingController _title = TextEditingController(
    text: widget.initialTitle ?? '',
  );
  late TaskPriority _priority = widget.initialPriority;
  late String? _project = widget.initialProject;
  DateTime? _dueDate;
  bool _saving = false;
  bool _manualEdit = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) {
      _applyPreview(
        widget.parser(widget.initialTitle!, projects: widget.projects),
      );
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _title.dispose();
    super.dispose();
  }

  void _applyPreview(QuickAddPreview preview) {
    _title.text = preview.title;
    _priority = preview.priority;
    _dueDate = preview.dueDate;
    _project = preview.project ?? _project;
    _manualEdit = false;
  }

  void _parse(String value) {
    if (_manualEdit) return;
    final preview = widget.parser(value, projects: widget.projects);
    setState(() {
      _applyPreview(preview);
      _error = null;
    });
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _dueDate ?? now.add(const Duration(hours: 17)),
      ),
    );
    if (!mounted) return;
    setState(() {
      _dueDate = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 17,
        time?.minute ?? 0,
      );
      _manualEdit = true;
    });
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a task title before creating it.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final saved = await widget.onSubmit(
      TaskDraft(
        title: title,
        priority: _priority,
        dueDate: _dueDate,
        course: _project ?? '',
      ),
    );

    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _saving = false;
      _error = 'The task could not be saved. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    final projects = <String>{
      ...widget.projects,
      if (_project != null && _project!.isNotEmpty) _project!,
    }.toList()..sort();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 680, maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: scheme.outlineVariant,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Quick add',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  'Type naturally, then check the parsed details.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close quick add',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      0,
                      AppSpacing.xl,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        AppTextField(
                          controller: _input,
                          autofocus: widget.initialTitle == null,
                          hintText:
                              'e.g. Submit lab report tomorrow high priority for COMP 2101',
                          labelText: 'Describe the task',
                          prefixIcon: Icons.auto_awesome_outlined,
                          maxLines: 3,
                          minLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: _parse,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(
                              alpha: 0.45,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: scheme.primary.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.visibility_outlined,
                                    size: AppSizes.iconMd,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      'Parsed preview',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: scheme.onPrimaryContainer,
                                          ),
                                    ),
                                  ),
                                  StatusBadge(
                                    label: 'Review',
                                    color: scheme.primary,
                                    icon: Icons.fact_check_outlined,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppTextField(
                                controller: _title,
                                labelText: 'Title',
                                textInputAction: TextInputAction.done,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                onChanged: (_) =>
                                    setState(() => _manualEdit = true),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Priority',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: TaskPriority.values
                                    .map(
                                      (priority) => ChoiceChip(
                                        label: Text(priority.label),
                                        selected: _priority == priority,
                                        showCheckmark: false,
                                        onSelected: (_) => setState(() {
                                          _priority = priority;
                                          _manualEdit = true;
                                        }),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final bool stack = constraints.maxWidth < 420;
                                  final Widget dateField = _FieldButton(
                                    icon: Icons.event_outlined,
                                    label: _dueDate == null
                                        ? 'No due date'
                                        : 'Due ${formatTaskDate(_dueDate!)}',
                                    onTap: _pickDueDate,
                                    trailingIcon: _dueDate == null
                                        ? Icons.add_rounded
                                        : Icons.edit_calendar_outlined,
                                  );
                                  final Widget projectField = _ProjectField(
                                    value: _project,
                                    projects: projects,
                                    onChanged: (value) => setState(() {
                                      _project = value;
                                      _manualEdit = true;
                                    }),
                                  );

                                  if (stack) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: <Widget>[
                                        dateField,
                                        const SizedBox(height: AppSpacing.sm),
                                        projectField,
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: <Widget>[
                                      Expanded(child: dateField),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(child: projectField),
                                    ],
                                  );
                                },
                              ),
                              if (_dueDate != null)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => setState(() {
                                      _dueDate = null;
                                      _manualEdit = true;
                                    }),
                                    icon: const Icon(
                                      Icons.event_busy_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Clear due date'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_error != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: AppSizes.iconMd,
                                  color: scheme.onErrorContainer,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.tips_and_updates_outlined,
                              size: AppSizes.iconSm,
                              color: AppColors.warningAmber,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                'Try "Plan revision next Monday" or '
                                '"Pay rent tomorrow low priority".',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border(
                      top: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      AppButton(
                        label: 'Create task',
                        icon: Icons.add_task_rounded,
                        onPressed: _saving ? null : _submit,
                        isLoading: _saving,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectField extends StatelessWidget {
  const _ProjectField({
    required this.value,
    required this.projects,
    required this.onChanged,
  });

  final String? value;
  final List<String> projects;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropdownButtonFormField<String?>(
      initialValue: value != null && projects.contains(value) ? value : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Project',
        prefixIcon: Icon(Icons.workspaces_outline, size: AppSizes.iconMd),
      ),
      hint: Text(
        'No project',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      items: <DropdownMenuItem<String?>>[
        const DropdownMenuItem<String?>(value: null, child: Text('No project')),
        for (final project in projects)
          DropdownMenuItem<String?>(
            value: project,
            child: Text(project, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.trailingIcon,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: scheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: AppSizes.iconMd, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                trailingIcon,
                size: AppSizes.iconSm,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
