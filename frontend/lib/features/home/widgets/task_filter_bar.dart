import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../data/task_store.dart';

/// Compact status and tag filters with a Trust Blue selected state.
class TaskFilterBar extends StatelessWidget {
  const TaskFilterBar({super.key, required this.store});

  final TaskStore store;

  @override
  Widget build(BuildContext context) {
    final tags = store.allTags;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _chip(context, TaskFilter.all, 'All (${store.tasks.length})'),
            _chip(context, TaskFilter.pending, 'To do (${store.pendingCount})'),
            if (store.overdueCount > 0)
              _chip(
                context,
                TaskFilter.overdue,
                'Overdue (${store.overdueCount})',
              ),
            _chip(
              context,
              TaskFilter.completed,
              'Done (${store.completedCount})',
            ),
          ],
        ),
        if (tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final tag in tags.take(8))
                FilterChip(
                  label: Text('#$tag'),
                  selected: store.tagFilter?.toLowerCase() == tag.toLowerCase(),
                  showCheckmark: false,
                  onSelected: (selected) =>
                      store.setTagFilter(selected ? tag : null),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _chip(BuildContext context, TaskFilter filter, String label) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bool selected = store.filter == filter;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => store.setFilter(filter),
      selectedColor: scheme.primary,
      backgroundColor: scheme.surface,
      side: BorderSide(color: selected ? scheme.primary : scheme.outline),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
    );
  }
}
