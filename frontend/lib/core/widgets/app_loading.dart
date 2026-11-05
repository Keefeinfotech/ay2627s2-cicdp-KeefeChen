import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Standard loading state used while a screen or list is being prepared.
class AppLoading extends StatelessWidget {
  const AppLoading({
    super.key,
    this.label = 'Loading...',
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      label: label,
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: compact ? 20 : 28,
              height: compact ? 20 : 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// A one-shot, accessible shimmer placeholder.
///
/// The animation settles rather than repeating forever. That keeps automated
/// widget tests deterministic and avoids motion for users who ask their system
/// to reduce animation.
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = AppRadius.sm,
    this.compact = false,
  });

  final double height;
  final double? width;
  final double borderRadius;
  final bool compact;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.35, end: 0.85),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Skeleton used while the dashboard or a task list is loading.
class TaskListSkeleton extends StatelessWidget {
  const TaskListSkeleton({super.key, this.itemCount = 4, this.compact = false});

  final int itemCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      label: 'Loading content',
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: scheme.outlineVariant),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: <Widget>[
            for (var index = 0; index < itemCount; index++) ...<Widget>[
              if (index > 0) const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const LoadingSkeleton(
                    width: 20,
                    height: 20,
                    borderRadius: AppRadius.xs,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        LoadingSkeleton(
                          height: compact ? 12 : 14,
                          width: index.isEven ? 220 : 180,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const LoadingSkeleton(height: 10, width: 140),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton for dashboard summary cards.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
          const Row(
            children: <Widget>[
              LoadingSkeleton(
                width: 34,
                height: 34,
                borderRadius: AppRadius.sm,
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    LoadingSkeleton(height: 12, width: 120),
                    SizedBox(height: AppSpacing.xs),
                    LoadingSkeleton(height: 10, width: 80),
                  ],
                ),
              ),
              LoadingSkeleton(
                width: 36,
                height: 36,
                borderRadius: AppRadius.pill,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const LoadingSkeleton(height: 24, width: 220),
          const SizedBox(height: AppSpacing.md),
          const LoadingSkeleton(height: 8, width: double.infinity),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.lg,
            children: <Widget>[
              for (var index = 0; index < 3; index++)
                const SizedBox(
                  width: 92,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      LoadingSkeleton(height: 18, width: 32),
                      SizedBox(height: AppSpacing.xs),
                      LoadingSkeleton(height: 10, width: 70),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
