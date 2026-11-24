import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../data/calendar_preferences_store.dart';
import '../models/calendar_skin.dart';

/// Opens the calendar appearance editor. Returns true when changes were saved.
Future<bool> showCalendarAppearanceDialog(
  BuildContext context,
  CalendarPreferencesStore store,
) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => CalendarAppearanceDialog(store: store),
  );
  return saved ?? false;
}

/// Skin, day-square and day-mark preferences with a live palette preview.
class CalendarAppearanceDialog extends StatefulWidget {
  const CalendarAppearanceDialog({super.key, required this.store});

  final CalendarPreferencesStore store;

  @override
  State<CalendarAppearanceDialog> createState() =>
      _CalendarAppearanceDialogState();
}

class _CalendarAppearanceDialogState extends State<CalendarAppearanceDialog> {
  late CalendarPreferences _draft = widget.store.preferences;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.store.save(_draft);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _clearMarks() async {
    final count = _draft.marks.length;
    if (count == 0) return;
    await widget.store.clearMarks();
    if (!mounted) return;
    setState(() => _draft = _draft.copyWith(marks: const <String, String>{}));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cleared $count ${count == 1 ? 'mark' : 'marks'}.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      icon: const Icon(Icons.palette_outlined, size: 28),
      title: const Text('Calendar appearance'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _sectionLabel(context, 'SKIN'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final skin in CalendarSkin.values)
                    _SkinOption(
                      skin: skin,
                      scheme: scheme,
                      selected: _draft.skin == skin,
                      onTap: () =>
                          setState(() => _draft = _draft.copyWith(skin: skin)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _sectionLabel(context, 'DAY SQUARES'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final style in CalendarSquareStyle.values)
                    ChoiceChip(
                      label: Text(style.label),
                      selected: _draft.squareStyle == style,
                      showCheckmark: false,
                      onSelected: (_) => setState(
                        () => _draft = _draft.copyWith(squareStyle: style),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  for (final style in CalendarSquareStyle.values) ...<Widget>[
                    if (style != CalendarSquareStyle.values.first)
                      const SizedBox(width: AppSpacing.sm),
                    _SquarePreview(
                      style: style,
                      color: _draft.skin.colorScheme?.primary ?? scheme.primary,
                      selected: _draft.squareStyle == style,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _sectionLabel(context, 'DAY MARKS'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final mark in CalendarMark.values.where(
                    (value) => value.isMarked,
                  ))
                    _MarkLegend(mark: mark, skin: _draft.skin, scheme: scheme),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Long-press a day square or tap its flag to choose a mark.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (_draft.marks.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _clearMarks,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: Text(
                      'Clear all ${_draft.marks.length} '
                      '${_draft.marks.length == 1 ? 'mark' : 'marks'}',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: 'Save appearance',
          isLoading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: scheme.onSurfaceVariant,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SkinOption extends StatelessWidget {
  const _SkinOption({
    required this.skin,
    required this.scheme,
    required this.selected,
    required this.onTap,
  });

  final CalendarSkin skin;
  final ColorScheme scheme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = skin.colorScheme ?? scheme;
    return Semantics(
      button: true,
      selected: selected,
      label: skin.label,
      child: Tooltip(
        message: skin.description,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            width: 116,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: selected
                  ? palette.primary.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected ? palette.primary : scheme.outlineVariant,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SkinPreview(skin: skin, scheme: palette),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        skin.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: selected ? palette.primary : null,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: palette.primary,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkinPreview extends StatelessWidget {
  const _SkinPreview({required this.skin, required this.scheme});

  final CalendarSkin skin;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color:
            skin.colorScheme?.surface ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < 7; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: 3),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: index == 3
                      ? scheme.primary
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: index == 3 ? scheme.primary : scheme.outlineVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SquarePreview extends StatelessWidget {
  const _SquarePreview({
    required this.style,
    required this.color,
    required this.selected,
  });

  final CalendarSquareStyle style;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 1 : 0.18),
            borderRadius: BorderRadius.circular(style.radius),
            border: Border.all(color: color),
          ),
          child: Icon(
            Icons.check_rounded,
            size: 16,
            color: selected ? Colors.white : color,
          ),
        ),
        const SizedBox(height: 4),
        Text(style.label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _MarkLegend extends StatelessWidget {
  const _MarkLegend({
    required this.mark,
    required this.skin,
    required this.scheme,
  });

  final CalendarMark mark;
  final CalendarSkin skin;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final color = skin.markColor(mark, scheme);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(mark.icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(mark.label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
