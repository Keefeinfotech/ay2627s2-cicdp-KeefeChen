import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A single animated tab pill that pulses, slides and scales when selected.
///
/// Each tab carries its own [accentColor] so the dashboard reads like a spread
/// of weather patterns rather than one flat surface. When active the tab
/// expands slightly, its border brightens, and a subtle glow radiates outward
/// — like a cafe window catching the light.
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
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _glow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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

    return ScaleTransition(
      scale: _scale,
      child: AnimatedBuilder(
        animation: _glow,
        builder: (context, child) {
          final glow = widget.isSelected ? _glow.value : 0.0;
          return GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? widget.accentColor.withValues(alpha: 0.18)
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: widget.isSelected
                      ? widget.accentColor.withValues(alpha: 0.9 + glow * 0.1)
                      : scheme.outlineVariant,
                  width: 1.5,
                ),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: widget.accentColor.withValues(
                            alpha: 0.12 + glow * 0.08,
                          ),
                          blurRadius: 8 + glow * 6,
                          spreadRadius: 2 + glow * 2,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    widget.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: widget.isSelected
                          ? widget.accentColor
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
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? widget.accentColor
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
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Weather-inspired accent colours for each dashboard tab.
abstract class TabWeather {
  static const Color all = AppColors.pacific;        // teal — ocean
  static const Color pending = AppColors.moss;        // earthy green — forest
  static const Color overdue = AppColors.persimmon;   // warm orange-red — sunset
  static const Color completed = AppColors.malachite; // vivid green — new growth
}
