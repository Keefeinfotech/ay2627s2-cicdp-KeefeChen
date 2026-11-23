import 'package:flutter/material.dart';

<<<<<<< HEAD
/// A lively, animated gradient background that slowly shifts colours.
///
/// Wrap any screen (or the app root) to give a dynamic, energetic feel
/// instead of a flat static colour. Colours cycle smoothly on a loop.
class AnimatedGradientBackground extends StatefulWidget {
=======
import '../design_system/ds_tokens.dart';

/// Flat enterprise page canvas.
///
/// The old animated gradient was decorative and worked against the calm,
/// professional SaaS look. The public constructor is kept for compatibility
/// with existing call sites, but the widget now renders one neutral surface.
class AnimatedGradientBackground extends StatelessWidget {
>>>>>>> 7ec4437e3b4dd82eca8212ed894210c12f68aae6
  const AnimatedGradientBackground({
    super.key,
    required this.child,
    this.colors = const <Color>[],
    this.duration = Duration.zero,
  });

  final Widget child;

  /// Kept for source compatibility; no longer used for rendering.
  final List<Color> colors;

  /// Kept for source compatibility; no longer used for rendering.
  final Duration duration;

  @override
<<<<<<< HEAD
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
=======
>>>>>>> 7ec4437e3b4dd82eca8212ed894210c12f68aae6
  Widget build(BuildContext context) {
    return ColoredBox(color: Ds.bgPage, child: child);
  }
}
