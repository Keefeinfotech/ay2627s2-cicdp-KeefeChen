import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../home/models/task.dart';
import '../../data/models/report_snapshot.dart';

/// Accessible bar chart of completed and created tasks per period bucket.
class ReportActivityChart extends StatelessWidget {
  const ReportActivityChart({
    super.key,
    required this.points,
    required this.maxValue,
    this.height = 168,
  });

  final List<ReportSeriesPoint> points;
  final int maxValue;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    final int maximum = math.max(1, maxValue);
    final bool dense = points.length > 10;

    final Widget chart = LayoutBuilder(
      builder: (context, constraints) {
        final double available = constraints.maxWidth;
        final double barWidth = dense ? 16 : 26;
        final double gap = dense ? 10 : 18;
        final double needed =
            points.length * (barWidth * 2 + 4) + (points.length - 1) * gap;

        Widget buildBars(double width) {
          return SizedBox(
            width: width,
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (var index = 0; index < points.length; index++) ...<Widget>[
                  if (index > 0) SizedBox(width: gap),
                  Expanded(
                    child: _BarPair(
                      point: points[index],
                      maximum: maximum,
                      barWidth: barWidth,
                      showLabel: !dense || index % 5 == 0,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        if (dense && needed > available) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: buildBars(needed),
            ),
          );
        }
        return buildBars(available);
      },
    );

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            _LegendDot(color: scheme.primary, label: 'Completed'),
            const SizedBox(width: AppSpacing.lg),
            _LegendDot(
              color: scheme.primary.withValues(alpha: 0.28),
              label: 'Created',
            ),
            const Spacer(),
            Text(
              'Busiest: $maxValue',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        chart,
      ],
    );
  }
}

class _BarPair extends StatelessWidget {
  const _BarPair({
    required this.point,
    required this.maximum,
    required this.barWidth,
    required this.showLabel,
  });

  final ReportSeriesPoint point;
  final int maximum;
  final double barWidth;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const double chartHeight = 118;

    Widget bar(int value, Color color, String semanticLabel) {
      final double ratio = value / maximum;
      final double barHeight = value == 0
          ? 0
          : math.max(4, ratio * chartHeight);
      return Tooltip(
        message: '$semanticLabel: $value',
        child: Semantics(
          label: semanticLabel,
          value: '$value',
          child: Container(
            width: barWidth,
            height: barHeight,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xs),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        SizedBox(
          height: chartHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              bar(
                point.created,
                scheme.primary.withValues(alpha: 0.28),
                'Tasks created on ${point.label}',
              ),
              const SizedBox(width: 3),
              bar(
                point.completed,
                scheme.primary,
                'Tasks completed on ${point.label}',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 16,
          child: Text(
            showLabel ? point.label : '',
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Donut chart showing how work is distributed across task priorities.
class ReportPriorityDonut extends StatelessWidget {
  const ReportPriorityDonut({super.key, required this.slices, this.size = 160});

  final List<ReportPrioritySlice> slices;
  final double size;

  Color _colorFor(TaskPriority priority, ColorScheme scheme) {
    return switch (priority) {
      TaskPriority.high => scheme.error,
      TaskPriority.medium => AppColors.warningAmber,
      TaskPriority.low => scheme.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final int total = slices.fold(0, (sum, slice) => sum + slice.total);
    final Color ringColor = total == 0 ? scheme.outlineVariant : scheme.primary;

    final String description = slices.isEmpty
        ? 'No tasks in this period'
        : slices
              .map(
                (slice) =>
                    '${slice.priority.label}: ${slice.total} '
                    '${slice.total == 1 ? 'task' : 'tasks'}',
              )
              .join(', ');

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool horizontal = constraints.maxWidth >= 330;
        final Widget ring = SizedBox(
          width: size,
          height: size,
          child: Semantics(
            label: 'Priority distribution. $description',
            child: CustomPaint(
              painter: _DonutPainter(
                slices: slices,
                total: total,
                trackColor: scheme.outlineVariant,
                colorFor: (priority) => _colorFor(priority, scheme),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '$total',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ringColor,
                      ),
                    ),
                    Text(
                      total == 1 ? 'task' : 'tasks',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final Widget legend = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final slice in slices) ...<Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: _colorFor(slice.priority, scheme),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${slice.priority.label} priority',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    '${slice.completed}/${slice.total}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: slice.rate,
                  minHeight: 5,
                  backgroundColor: scheme.outlineVariant,
                  color: _colorFor(slice.priority, scheme),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (slices.isEmpty)
              Text(
                'Priority breakdown appears once tasks exist.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        );

        if (!horizontal) {
          return Column(
            children: <Widget>[
              ring,
              const SizedBox(height: AppSpacing.lg),
              legend,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            ring,
            const SizedBox(width: AppSpacing.xl),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.slices,
    required this.total,
    required this.trackColor,
    required this.colorFor,
  });

  final List<ReportPrioritySlice> slices;
  final int total;
  final Color trackColor;
  final Color Function(TaskPriority priority) colorFor;

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = math.min(18, size.width * 0.12);
    final Rect rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - strokeWidth) / 2,
    );
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    paint.color = trackColor;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint);

    if (total == 0) return;

    var startAngle = -math.pi / 2;
    const double gap = 0.025;
    for (final slice in slices) {
      if (slice.total == 0) continue;
      final double sweep = (slice.total / total) * math.pi * 2;
      if (sweep <= gap * 2) continue;
      paint.color = colorFor(slice.priority);
      canvas.drawArc(rect, startAngle + gap, sweep - gap * 2, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) {
    return oldDelegate.total != total ||
        oldDelegate.slices != slices ||
        oldDelegate.trackColor != trackColor;
  }
}
