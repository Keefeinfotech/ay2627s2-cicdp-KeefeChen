import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/animated_tab.dart';
import '../data/task_store.dart';

/// Animated filter tabs where each tab carries its own weather-inspired colour
/// and pulse animation. Selecting a tab makes it glow and expand slightly.
class TaskFilterBar extends StatelessWidget {
  const TaskFilterBar({super.key, required this.store});

  final TaskStore store;

  @override
  Widget build(BuildContext context) {
    final tags = store.allTags;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Primary status tabs — each with its own colour and animation
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            AnimatedTab(
              label: 'All (${store.tasks.length})',
              accentColor: TabWeather.all,
              isSelected: store.filter == TaskFilter.all,
              count: store.tasks.length,
              onTap: () => store.setFilter(TaskFilter.all),
            ),
            AnimatedTab(
              label: 'To do (${store.pendingCount})',
              accentColor: TabWeather.pending,
              isSelected: store.filter == TaskFilter.pending,
              count: store.pendingCount,
              onTap: () => store.setFilter(TaskFilter.pending),
            ),
            if (store.overdueCount > 0)
              AnimatedTab(
                label: 'Overdue (${store.overdueCount})',
                accentColor: TabWeather.overdue,
                isSelected: store.filter == TaskFilter.overdue,
                count: store.overdueCount,
                onTap: () => store.setFilter(TaskFilter.overdue),
              ),
            AnimatedTab(
              label: 'Done (${store.completedCount})',
              accentColor: TabWeather.completed,
              isSelected: store.filter == TaskFilter.completed,
              count: store.completedCount,
              onTap: () => store.setFilter(TaskFilter.completed),
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
                  selectedColor: TabWeather.pending,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  side: BorderSide(
                    color: store.tagFilter?.toLowerCase() == tag.toLowerCase()
                        ? TabWeather.pending
                        : Theme.of(context).colorScheme.outline,
                  ),
                  labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: store.tagFilter?.toLowerCase() == tag.toLowerCase()
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: store.tagFilter?.toLowerCase() ==
                            tag.toLowerCase()
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
