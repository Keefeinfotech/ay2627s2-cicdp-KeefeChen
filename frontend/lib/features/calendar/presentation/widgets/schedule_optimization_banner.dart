import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/usecases/analyze_schedule.dart';

/// Prominent, calm prompt that turns schedule analysis into an actionable
/// workload re-balancing plan.
class ScheduleOptimizationBanner extends StatelessWidget {
  const ScheduleOptimizationBanner({
    super.key,
    required this.analysis,
    required this.onReview,
  });

  final ScheduleAnalysis analysis;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bool hasWork = analysis.overloadedDayCount > 0;
    final String summary = hasWork
        ? '${analysis.overloadedDayCount} '
              '${analysis.overloadedDayCount == 1 ? 'day needs' : 'days need'} '
              're-balancing · ${analysis.overlaps.length} '
              '${analysis.overlaps.length == 1 ? 'overlap' : 'overlaps'} found'
        : 'Your workload is balanced across this view.';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Widget text = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.auto_awesome_outlined,
                  color: scheme.primary,
                  size: AppSizes.iconMd,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'AI Schedule Optimization',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      summary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer.withValues(
                          alpha: 0.85,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final Widget action = AppButton(
            label: hasWork ? 'Review plan' : 'View insights',
            icon: Icons.balance_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: onReview,
          );

          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                text,
                const SizedBox(height: AppSpacing.md),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }

          return Row(
            children: <Widget>[
              Expanded(child: text),
              const SizedBox(width: AppSpacing.lg),
              action,
            ],
          );
        },
      ),
    );
  }
}

/// Bottom sheet that explains each recommended workload adjustment.
class ScheduleOptimizationSheet extends StatelessWidget {
  const ScheduleOptimizationSheet({
    super.key,
    required this.analysis,
    required this.onApply,
  });

  final ScheduleAnalysis analysis;
  final ValueChanged<ScheduleSuggestion> onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final suggestions = analysis.suggestions;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
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
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Schedule optimization',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close schedule plan',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  suggestions.isEmpty
                      ? 'No changes are needed in this range. Keep focus blocks '
                            'between meetings and protect time for deep work.'
                      : 'A few small moves can reduce context switching and '
                            'spread your workload more evenly.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (suggestions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: AppColors.successGreen,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'This range is already balanced. Your busiest day '
                            'is within the five-hour focus threshold.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final suggestion in suggestions) ...[
                    Container(
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
                              Icon(
                                Icons.swap_horiz_rounded,
                                color: scheme.primary,
                                size: AppSizes.iconMd,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  suggestion.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            suggestion.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Align(
                            alignment: Alignment.centerRight,
                            child: AppButton(
                              label: 'Apply suggestion',
                              variant: AppButtonVariant.outline,
                              icon: Icons.check_rounded,
                              onPressed: () {
                                Navigator.of(context).pop(suggestion);
                                onApply(suggestion);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Changes are previewed on this device so you can review the '
                  'plan before committing it.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
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
