import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../models/calendar_skin.dart';

/// Opens the per-day mark picker. Returns the chosen mark, or `null` when the
/// sheet was dismissed without a change.
Future<CalendarMark?> showDayMarkPicker({
  required BuildContext context,
  required DateTime date,
  required CalendarMark current,
  required CalendarSkin skin,
}) async {
  return showModalBottomSheet<CalendarMark>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        DayMarkPickerSheet(date: date, current: current, skin: skin),
  );
}

/// Bottom sheet with the five day marks and a clear action.
class DayMarkPickerSheet extends StatelessWidget {
  const DayMarkPickerSheet({
    super.key,
    required this.date,
    required this.current,
    required this.skin,
  });

  final DateTime date;
  final CalendarMark current;
  final CalendarSkin skin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Mark this day',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${date.day}/${date.month}/${date.year} · '
              'Marks are private to this workspace.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final mark in CalendarMark.values) ...<Widget>[
              ListTile(
                leading: _MarkIcon(mark: mark, skin: skin, scheme: scheme),
                title: Text(mark.label),
                trailing: current == mark
                    ? Icon(Icons.check_rounded, color: scheme.primary)
                    : null,
                selected: current == mark,
                onTap: () => Navigator.of(context).pop(mark),
              ),
              if (mark != CalendarMark.personal)
                Divider(height: 1, color: scheme.outlineVariant),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarkIcon extends StatelessWidget {
  const _MarkIcon({
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
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: mark.isMarked ? 0.16 : 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Icon(mark.icon, size: 18, color: color),
    );
  }
}
