import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/task_validation.dart';
import '../models/task.dart';

/// Bottom-sheet form for creating and editing tasks.
///
/// The primary action lives in a sticky footer so it stays reachable on short
/// screens and when the software keyboard is open, while the fields scroll
/// independently. The layout is grouped into Basics, Organise, Priority and
/// Schedule sections with a single filled primary action in the footer.
class TaskEditor extends StatefulWidget {
  const TaskEditor({
    super.key,
    this.initial,
    this.initialCourse,
    this.existingTags = const <String>[],
    this.existingCourses = const <String>[],
  });

  final Task? initial;

  /// Pre-fills the course/subject field when creating a task from a project
  /// workspace. Ignored when [initial] is supplied.
  final String? initialCourse;

  /// Tags already used elsewhere in the workspace, offered as quick chips.
  final List<String> existingTags;

  /// Courses already used elsewhere in the workspace, offered as quick chips.
  final List<String> existingCourses;

  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.initial?.title ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.initial?.notes ?? '',
  );
  late final TextEditingController _course = TextEditingController(
    text: widget.initial?.course ?? widget.initialCourse ?? '',
  );
  late final TextEditingController _tag = TextEditingController();
  late List<String> _tags = Task.normalizeTags(
    widget.initial?.tags ?? const <String>[],
  );
  late TaskPriority _priority = widget.initial?.priority ?? TaskPriority.medium;
  late DateTime? _dueDate = widget.initial?.dueDate;
  late DateTime? _reminderAt = widget.initial?.reminderAt;
  String? _scheduleError;
  String? _tagError;

  bool get _isEditing => widget.initial != null;

  /// True when the form differs from the initial snapshot; used to guard
  /// against losing typed input on close.
  bool get _isDirty {
    final initial = widget.initial;
    final initialTitle = initial?.title ?? '';
    final initialNotes = initial?.notes ?? '';
    final initialCourse = initial?.course ?? widget.initialCourse ?? '';
    final initialTags = Task.normalizeTags(initial?.tags ?? const <String>[]);

    if (_title.text != initialTitle) return true;
    if (_notes.text != initialNotes) return true;
    if (_course.text != initialCourse) return true;
    if (_tags.length != initialTags.length ||
        !_tags.every((tag) => initialTags.contains(tag))) {
      return true;
    }
    if (_priority != (initial?.priority ?? TaskPriority.medium)) return true;
    if (_dueDate != initial?.dueDate) return true;
    if (_reminderAt != initial?.reminderAt) return true;
    return false;
  }

  /// Professional priority colour from the active scheme. Light mode uses the
  /// semantic Trust Blue / amber / red tokens; dark mode uses their legible
  /// light counterparts.
  Color _priorityColor(ColorScheme scheme) {
    final bool dark = scheme.brightness == Brightness.dark;
    return switch (_priority) {
      TaskPriority.low => scheme.primary,
      TaskPriority.medium =>
        dark ? AppColors.darkWarning : AppColors.warningAmber,
      TaskPriority.high => dark ? AppColors.darkOverdue : AppColors.errorRed,
    };
  }

  /// Small uppercase-style section label with a hairline rule. Keeps the
  /// sheet scannable without adding nested card borders around every field.
  Widget _sectionHeader(BuildContext context, String label) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Divider(height: 1, color: scheme.outlineVariant)),
        ],
      ),
    );
  }

  /// Equal-width schedule controls. They stack on phone widths so long labels
  /// are ellipsised instead of wrapping or overflowing.
  Widget _scheduleControls(BuildContext context) {
    final bool narrow = MediaQuery.sizeOf(context).width < 440;

    final Widget due = AppButton(
      label: _dueDate == null
          ? 'Set due date'
          : 'Due ${formatTaskDate(_dueDate!)}',
      icon: Icons.event_outlined,
      onPressed: _setDueDate,
      variant: AppButtonVariant.outline,
      expand: true,
    );
    final Widget reminder = AppButton(
      label: _reminderAt == null
          ? 'Set reminder'
          : 'Remind ${formatTaskDate(_reminderAt!)}',
      icon: Icons.notifications_outlined,
      onPressed: _setReminder,
      variant: AppButtonVariant.outline,
      expand: true,
    );

    if (narrow) {
      return Column(
        children: <Widget>[
          due,
          const SizedBox(height: AppSpacing.sm),
          reminder,
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(child: due),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: reminder),
      ],
    );
  }

  /// Closes the editor, asking for confirmation first when there are
  /// unsaved changes.
  Future<void> _requestClose() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }

    final discard = await showAppConfirmDialog(
      context,
      title: 'Discard changes?',
      message: 'Your edits have not been saved yet. Discard them?',
      confirmLabel: 'Discard',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );

    if (discard && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _course.dispose();
    _tag.dispose();
    super.dispose();
  }

  void _addTag([String? value]) {
    final raw = (value ?? _tag.text).trim();
    if (raw.isEmpty) return;

    final candidate = raw.replaceFirst(RegExp(r'^#+'), '').trim();
    if (candidate.length > maxTagLength) {
      setState(() {
        _tagError = 'Keep each tag under $maxTagLength characters';
      });
      return;
    }
    if (_tags.length >= maxTags) {
      setState(() => _tagError = 'Use up to $maxTags tags');
      return;
    }
    if (_tags.any((tag) => tag.toLowerCase() == candidate.toLowerCase())) {
      _tag.clear();
      setState(() => _tagError = null);
      return;
    }

    setState(() {
      _tags = <String>[..._tags, candidate];
      _tag.clear();
      _tagError = null;
    });
  }

  void _removeTag(String tag) {
    setState(() {
      _tags = _tags.where((item) => item != tag).toList(growable: false);
      _tagError = null;
    });
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final firstDate = DateTime(2000);
    final lastDate = DateTime(2100);
    var safeInitial = initial;
    if (safeInitial.isBefore(firstDate)) safeInitial = firstDate;
    if (safeInitial.isAfter(lastDate)) safeInitial = lastDate;

    final date = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(safeInitial),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _setDueDate() async {
    final picked = await _pickDateTime(
      _dueDate ?? DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      _dueDate = picked;
      _scheduleError = null;
    });
  }

  Future<void> _setReminder() async {
    final picked = await _pickDateTime(
      _reminderAt ?? _dueDate ?? DateTime.now().add(const Duration(hours: 1)),
    );
    if (picked == null) return;
    setState(() {
      _reminderAt = picked;
      _scheduleError = null;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final scheduleError = validateSchedule(
      dueDate: _dueDate,
      reminderAt: _reminderAt,
    );
    if (scheduleError != null) {
      setState(() => _scheduleError = scheduleError);
      return;
    }

    Navigator.of(context).pop(
      TaskDraft(
        title: _title.text.trim(),
        notes: _notes.text.trim(),
        course: _course.text.trim(),
        tags: _tags,
        priority: _priority,
        dueDate: _dueDate,
        reminderAt: _reminderAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 640, maxHeight: maxHeight),
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
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                _isEditing ? 'Edit task' : 'New task',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: _requestClose,
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        if (_isEditing)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.xs,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                PriorityBadge.task(
                                  label: '${_priority.label} priority',
                                  color: _priorityColor(scheme),
                                ),
                                if (_dueDate != null)
                                  StatusBadge(
                                    label: 'Due ${formatTaskDate(_dueDate!)}',
                                    color: scheme.onSurfaceVariant,
                                    icon: Icons.event_outlined,
                                  ),
                              ],
                            ),
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
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _sectionHeader(context, 'Basics'),
                            AppTextField(
                              controller: _title,
                              autofocus: !_isEditing,
                              maxLength: maxTitleLength,
                              counterText: '',
                              textInputAction: TextInputAction.next,
                              labelText: 'Title',
                              hintText: 'What needs to be done?',
                              textCapitalization: TextCapitalization.sentences,
                              validator: validateTitle,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            AppTextField(
                              controller: _course,
                              maxLength: maxCourseLength,
                              counterText: '',
                              textInputAction: TextInputAction.next,
                              labelText: 'Course or subject (optional)',
                              hintText: 'e.g. COMP 2101',
                              prefixIcon: Icons.school_outlined,
                              textCapitalization: TextCapitalization.characters,
                              validator: validateCourse,
                            ),
                            if (widget.existingCourses.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.xs,
                                ),
                                child: Wrap(
                                  spacing: AppSpacing.xs,
                                  runSpacing: AppSpacing.xs,
                                  children: <Widget>[
                                    for (final course
                                        in widget.existingCourses.take(8))
                                      ActionChip(
                                        avatar: const Icon(
                                          Icons.school_outlined,
                                          size: 16,
                                        ),
                                        label: Text(course),
                                        tooltip: 'Use subject $course',
                                        onPressed: () => setState(() {
                                          _course.text = course;
                                        }),
                                      ),
                                  ],
                                ),
                              ),
                            _sectionHeader(context, 'Organise'),
                            Text(
                              'Tags (optional)',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            if (_tags.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: Wrap(
                                  spacing: AppSpacing.xs,
                                  runSpacing: AppSpacing.xs,
                                  children: <Widget>[
                                    for (final tag in _tags)
                                      InputChip(
                                        label: Text(tag),
                                        onDeleted: () => _removeTag(tag),
                                        deleteButtonTooltipMessage:
                                            'Remove tag $tag',
                                      ),
                                  ],
                                ),
                              ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: AppTextField(
                                    controller: _tag,
                                    useFormField: false,
                                    hintText: 'Add a tag, then press Enter',
                                    prefixIcon: Icons.sell_outlined,
                                    textInputAction: TextInputAction.done,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    maxLength: maxTagLength,
                                    counterText: '',
                                    onFieldSubmitted: _addTag,
                                    errorText: _tagError,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                IconButton.filledTonal(
                                  tooltip: 'Add tag',
                                  onPressed: _addTag,
                                  icon: const Icon(Icons.add_rounded),
                                ),
                              ],
                            ),
                            if (widget.existingTags.any(
                              (tag) => !_tags.any(
                                (selected) =>
                                    selected.toLowerCase() == tag.toLowerCase(),
                              ),
                            ))
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.xs,
                                ),
                                child: Wrap(
                                  spacing: AppSpacing.xs,
                                  runSpacing: AppSpacing.xs,
                                  children: <Widget>[
                                    for (final tag
                                        in widget.existingTags
                                            .where(
                                              (tag) => !_tags.any(
                                                (selected) =>
                                                    selected.toLowerCase() ==
                                                    tag.toLowerCase(),
                                              ),
                                            )
                                            .take(6))
                                      ActionChip(
                                        label: Text('#$tag'),
                                        onPressed: () => _addTag(tag),
                                      ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: AppSpacing.sm),
                            AppTextField(
                              controller: _notes,
                              maxLength: maxNotesLength,
                              counterText: '',
                              maxLines: 3,
                              minLines: 2,
                              labelText: 'Notes (optional)',
                              hintText: 'Add context, links or a quick plan',
                              textCapitalization: TextCapitalization.sentences,
                              validator: validateNotes,
                            ),
                            _sectionHeader(context, 'Priority'),
                            SegmentedButton<TaskPriority>(
                              segments: TaskPriority.values
                                  .map(
                                    (priority) => ButtonSegment<TaskPriority>(
                                      value: priority,
                                      label: Text(priority.label),
                                    ),
                                  )
                                  .toList(growable: false),
                              selected: <TaskPriority>{_priority},
                              onSelectionChanged: (selection) {
                                setState(() => _priority = selection.first);
                              },
                            ),
                            _sectionHeader(context, 'Schedule'),
                            _scheduleControls(context),
                            if (_dueDate != null)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => setState(() {
                                    _dueDate = null;
                                    _scheduleError = null;
                                  }),
                                  icon: const Icon(
                                    Icons.event_busy_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Clear due date'),
                                ),
                              ),
                            if (_reminderAt != null)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => setState(() {
                                    _reminderAt = null;
                                    _scheduleError = null;
                                  }),
                                  icon: const Icon(
                                    Icons.notifications_off_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Clear reminder'),
                                ),
                              ),
                            if (_scheduleError != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 18,
                                    color: scheme.error,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      _scheduleError!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: scheme.error),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
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
                          onPressed: _requestClose,
                          child: const Text('Cancel'),
                        ),
                        AppButton(
                          label: _isEditing ? 'Save changes' : 'Create task',
                          onPressed: _save,
                          icon: _isEditing
                              ? Icons.check_rounded
                              : Icons.add_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
