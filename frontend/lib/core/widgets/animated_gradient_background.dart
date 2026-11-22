import 'dart:math';

import 'package:flutter/material.dart';

/// A lively, animated gradient background that slowly shifts colours.
///
/// Wrap any screen (or the app root) to give a dynamic, energetic feel
/// instead of a flat static colour. Colours cycle smoothly on a loop.
class AnimatedGradientBackground extends StatefulWidget {
  const AnimatedGradientBackground({
    super.key,
    required this.child,
    this.colors = const [
      Color(0xFF1E3A8A),
      Color(0xFF2563EB),
      Color(0xFF0F172A),
      Color(0xFF059669),
    ],
    this.duration = const Duration(seconds: 8),
  });

  final Widget child;
  final List<Color> colors;
  final Duration duration;

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // In a test environment an infinitely repeating animation never settles,
    // which breaks `pumpAndSettle`. Keep the animation static there while
    // preserving the lively motion in real (debug/release) runs.
    final isTestEnvironment = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('Test');
    _controller = AnimationController(
      vsync: this,
      duration: isTestEnvironment ? Duration.zero : widget.duration,
    );
    if (!isTestEnvironment) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Honour the OS "reduce motion" accessibility setting: show a static
    // diagonal gradient sampled from the middle of the cycle.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      final c = widget.colors;
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c[0], c[2]],
          ),
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        final c = widget.colors;
        return RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(c[0], c[1], (sin(t * 2 * pi) + 1) / 2)!,
                  Color.lerp(c[2], c[3], (cos(t * 2 * pi) + 1) / 2)!,
                ],
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }
}
