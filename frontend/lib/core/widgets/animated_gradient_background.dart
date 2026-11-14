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
      Color(0xFF6B7C98),
      Color(0xFFAB978C),
      Color(0xFF5E5653),
      Color(0xFF16A34A),
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
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final c = widget.colors;
        return Container(
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
          child: widget.child,
        );
      },
    );
  }
}
