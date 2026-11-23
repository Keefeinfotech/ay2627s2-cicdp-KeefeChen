import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/ds_tokens.dart';
import '../theme/app_spacing.dart';

/// A compact success toast shown when the user reaches a new level.
///
/// It uses the same flat treatment as the rest of the design system: a solid
/// green surface, a single status icon and a short fade/slide transition.
/// Auto-dismisses after [duration].
class LevelUpToast extends StatefulWidget {
  const LevelUpToast({
    super.key,
    required this.level,
    this.duration = const Duration(seconds: 5),
    this.onDismiss,
  });

  final int level;
  final Duration duration;
  final VoidCallback? onDismiss;

  /// Show a level-up toast.
  static void show(
    BuildContext context, {
    required int level,
    Duration? duration,
  }) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    var removed = false;

    void remove() {
      if (removed) return;
      removed = true;
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (context) => LevelUpToast(
        level: level,
        duration: duration ?? const Duration(seconds: 5),
        onDismiss: remove,
      ),
    );
    overlay.insert(entry);
  }

  @override
  State<LevelUpToast> createState() => _LevelUpToastState();
}

class _LevelUpToastState extends State<LevelUpToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _dismissTimer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    // Own the dismissal timer so the overlay is removed predictably and no
    // pending timer survives disposal (important for widget tests).
    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_dismissing) return;
    _dismissing = true;
    _dismissTimer?.cancel();
    _controller.reverse().whenComplete(() {
      if (!mounted) return;
      widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned(
      top: AppSpacing.lg,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Semantics(
                liveRegion: true,
                label: 'Level up. You reached level ${widget.level}.',
                child: Container(
                  key: const Key('level-up-toast'),
                  constraints: const BoxConstraints(maxWidth: 480),
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: Ds.accentGreen,
                    borderRadius: BorderRadius.circular(Ds.rLg),
                    boxShadow: Ds.elevation2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Ds.onPrimary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(Ds.rMd),
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Ds.onPrimary,
                          size: AppSizes.iconLg,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'Level Up!',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Ds.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'You reached level ${widget.level}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Ds.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
