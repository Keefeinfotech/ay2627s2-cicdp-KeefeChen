import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A celebratory toast shown when the user reaches a new level.
///
/// Features a scale-up entrance, a rotating trophy icon, and a confetti burst
/// of particles behind the text. Auto-dismisses after [duration].
class LevelUpToast extends StatefulWidget {
  const LevelUpToast({
    super.key,
    required this.level,
    this.duration = const Duration(seconds: 5),
  });

  final int level;
  final Duration duration;

  /// Show a level-up toast.
  static void show(BuildContext context, {required int level, Duration? duration}) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => LevelUpToast(level: level, duration: duration ?? const Duration(seconds: 5)),
    );
    overlay.insert(entry);
    Future.delayed(duration ?? const Duration(seconds: 5), () {
      if (entry.mounted) entry.remove();
    });
  }

  @override
  State<LevelUpToast> createState() => _LevelUpToastState();
}

class _LevelUpToastState extends State<LevelUpToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _rotate;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut)
        .drive(Tween<double>(begin: 0.5, end: 1.0));
    _rotate = CurvedAnimation(parent: _controller, curve: Curves.easeInOut)
        .drive(Tween<double>(begin: -0.4, end: 0.4));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut)
        .drive(Tween<double>(begin: 0.0, end: 1.0));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned(
      top: 40,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _fade,
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppColors.successGreen.withValues(alpha: 0.95),
                      AppColors.navyDeep.withValues(alpha: 0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.successGreen.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    AnimatedBuilder(
                      animation: _rotate,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotate.value,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 32),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Level Up!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'You reached level ${widget.level}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Confetti-style particle burst behind the text.
                    _ConfettiParticles(animation: _controller),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated confetti particles that burst outward from the centre.
class _ConfettiParticles extends StatelessWidget {
  const _ConfettiParticles({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final colors = <Color>[
      AppColors.warningAmber,
      AppColors.errorRed,
      AppColors.warningAmber,
      AppColors.successGreen,
    ];

    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(8, (i) {
          final angle = (i / 8) * 2 * pi;
          final distance = animation.value;
          return Transform.translate(
            offset: Offset(cos(angle) * distance * 40, sin(angle) * distance * 20),
            child: Opacity(
              opacity: animation.value,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: colors[i % colors.length],
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
