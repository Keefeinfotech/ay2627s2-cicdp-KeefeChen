import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum AppCardVariant { surface, navy, soft, accent }

/// Standard Auxilia surface.
///
/// Cards use a light border and zero elevation instead of heavy shadows. The
/// navy variant is reserved for genuinely important content.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.onTap,
    this.variant = AppCardVariant.surface,
    this.borderRadius,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final AppCardVariant variant;
  final double? borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = borderRadius ?? AppRadius.lg;

    final (Color background, Color border) = switch (variant) {
      AppCardVariant.surface => (scheme.surface, scheme.outlineVariant),
      AppCardVariant.navy => (AppColors.deepNavy, AppColors.deepNavy),
      AppCardVariant.soft => (
        scheme.surfaceContainerHighest,
        Colors.transparent,
      ),
      AppCardVariant.accent => (AppColors.navyTint, AppColors.navyTint),
    };

    final Widget content = Padding(padding: padding, child: child);

    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: variant == AppCardVariant.navy
                ? Colors.white.withValues(alpha: 0.12)
                : border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  splashColor: scheme.primary.withValues(alpha: 0.06),
                  highlightColor: scheme.primary.withValues(alpha: 0.04),
                  child: content,
                ),
              ),
      ),
    );
  }
}
