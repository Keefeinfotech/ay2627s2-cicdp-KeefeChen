import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Small priority label used by task and project cards.
class PriorityBadge extends StatelessWidget {
  const PriorityBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.semanticLabel,
  });

  /// Convenience constructor for the task priority palette.
  const PriorityBadge.task({
    super.key,
    required this.label,
    required this.color,
  }) : icon = null,
       semanticLabel = null;

  final String label;
  final Color color;
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool lowContrast = color == AppColors.warningAmber;
    final Color foreground = lowContrast ? const Color(0xFF92400E) : color;
    final Color background = color.withValues(alpha: 0.1);

    return Semantics(
      label: semanticLabel ?? '$label priority',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...[
              Icon(icon, size: 12, color: foreground),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill used for task, event and project states.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final Color background = filled ? color : color.withValues(alpha: 0.1);
    final Color foreground = filled ? Colors.white : color;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: filled ? color : color.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline completion indicator used in lists and report rows.
class CompletionBar extends StatelessWidget {
  const CompletionBar({
    super.key,
    required this.value,
    this.color,
    this.height = 6,
    this.label,
  });

  final double value;
  final Color? color;
  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: height,
          backgroundColor: scheme.outlineVariant,
          color: color ?? scheme.primary,
        ),
      ),
    );
  }
}
