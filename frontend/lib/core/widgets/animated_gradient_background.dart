import 'package:flutter/material.dart';

import '../design_system/ds_tokens.dart';

/// Flat enterprise page canvas.
///
/// The old animated gradient was decorative and worked against the calm,
/// professional SaaS look. The public constructor is kept for compatibility
/// with existing call sites, but the widget now renders one neutral surface.
class AnimatedGradientBackground extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ColoredBox(color: Ds.bgPage, child: child);
  }
}
