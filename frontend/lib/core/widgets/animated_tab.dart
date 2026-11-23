import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A compact filter tab used across list screens.
///
/// The active tab is marked by a coloured border and subtle background tint,
/// using the semantic [accentColor] semantics shared with the rest of the app.
class AnimatedTab extends StatefulWidget {
  const AnimatedTab({
    super.key,
    required this.label,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
    this.count,
  });

  final String label;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;
  final int? count;

  @override
  State<AnimatedTab> createState() => _AnimatedTabState();
}

class _AnimatedTabState extends State<AnimatedTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    if (widget.isSelected) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AnimatedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayAccent = TabWeather.display(widget.accentColor, scheme);

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.accentColor.withValues(alpha: 0.12)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: widget.isSelected
                  ? displayAccent.withValues(alpha: 0.9)
                  : scheme.outlineVariant,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: widget.isSelected
                      ? displayAccent
                      : scheme.onSurfaceVariant,
                  fontWeight: widget.isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
              if (widget.count != null && widget.count! > 0) ...[
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? displayAccent
                        : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${widget.count}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: widget.isSelected
                          ? scheme.onPrimary
                          : scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
