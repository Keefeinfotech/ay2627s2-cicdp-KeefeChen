import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, danger, success }

enum AppButtonSize { medium, large }

/// The single button component used across Auxilia.
///
/// It standardises height, radius, padding, disabled/loading states and keeps
/// destructive actions visually distinct from primary actions.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.expand = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final bool expand;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool isLarge = size == AppButtonSize.large;
    final double height = isLarge
        ? AppSizes.largeButtonHeight
        : AppSizes.buttonHeight;

    final Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _foreground(scheme),
            ),
          )
        else if (icon != null)
          Icon(icon, size: AppSizes.iconMd),
        if (isLoading || icon != null) const SizedBox(width: AppSpacing.sm),
        if (expand)
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          )
        else
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
      ],
    );

    final ButtonStyle baseStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll<Size>(Size(0, height)),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(
          horizontal: isLarge ? AppSpacing.xl : AppSpacing.lg,
        ),
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );

    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: baseStyle,
        child: content,
      ),
      AppButtonVariant.secondary => FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: baseStyle.copyWith(
          backgroundColor: WidgetStatePropertyAll<Color>(
            scheme.primaryContainer,
          ),
          foregroundColor: WidgetStatePropertyAll<Color>(
            scheme.onPrimaryContainer,
          ),
          overlayColor: WidgetStatePropertyAll<Color>(
            scheme.primary.withValues(alpha: 0.08),
          ),
        ),
        child: content,
      ),
      AppButtonVariant.outline => OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: baseStyle.copyWith(
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: scheme.outline),
          ),
        ),
        child: content,
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: isLoading ? null : onPressed,
        style: baseStyle,
        child: content,
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: baseStyle.copyWith(
          backgroundColor: WidgetStatePropertyAll<Color>(scheme.error),
          foregroundColor: WidgetStatePropertyAll<Color>(scheme.onError),
        ),
        child: content,
      ),
      AppButtonVariant.success => FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: baseStyle.copyWith(
          backgroundColor: const WidgetStatePropertyAll<Color>(AppColors.teal),
          foregroundColor: const WidgetStatePropertyAll<Color>(AppColors.white),
        ),
        child: content,
      ),
    };

    final Widget sized = expand
        ? ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: double.infinity,
              minHeight: height,
            ),
            child: button,
          )
        : ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: button,
          );

    return Semantics(
      button: true,
      enabled: onPressed != null && !isLoading,
      label: isLoading ? '$label, loading' : label,
      child: tooltip == null ? sized : Tooltip(message: tooltip!, child: sized),
    );
  }

  Color _foreground(ColorScheme scheme) {
    return switch (variant) {
      AppButtonVariant.primary ||
      AppButtonVariant.danger ||
      AppButtonVariant.success => scheme.onPrimary,
      AppButtonVariant.secondary => scheme.onPrimaryContainer,
      AppButtonVariant.outline || AppButtonVariant.ghost => scheme.primary,
    };
  }
}
