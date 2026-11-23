import 'package:flutter/material.dart';

/// A circular progress ring used on dashboards, project cards and summary
/// panels.
///
/// Mobbin-style: a thin ring with an optional centre label, for example a
/// project's completion percentage or a KPI value.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.diameter = 96,
    this.strokeWidth = 12,
    this.color,
    this.trackColor,
    this.center,
  });

  final double value;
  final double diameter;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = value.clamp(0.0, 1.0);

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CircularProgressIndicator(
            value: progress,
            strokeWidth: strokeWidth,
            backgroundColor: trackColor ?? scheme.outlineVariant,
            color: color ?? scheme.primary,
          ),
          ?center,
        ],
      ),
    );
  }
}
