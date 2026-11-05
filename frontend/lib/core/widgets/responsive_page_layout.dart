import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Width thresholds shared by every responsive surface.
abstract final class AppBreakpoints {
  static const double smallMobile = 360;
  static const double mobile = 600;
  static const double tablet = 600;
  static const double desktop = 1024;
}

/// Standard page frame: safe areas, a readable maximum width, and consistent
/// horizontal padding that expands on larger screens.
class ResponsivePageLayout extends StatelessWidget {
  const ResponsivePageLayout({
    super.key,
    required this.child,
    this.appBar,
    this.floatingActionButton,
    this.background,
    this.bottomNavigationBar,
    this.maxWidth = AppSizes.maxContentWidth,
    this.padding,
    this.safeArea = true,
    this.scrollable = false,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Color? background;
  final Widget? bottomNavigationBar;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool safeArea;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final EdgeInsetsGeometry effectivePadding =
        padding ??
        const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
        ).add(const EdgeInsets.only(bottom: AppSpacing.xxl));

    Widget content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: effectivePadding, child: child),
      ),
    );

    if (scrollable) {
      content = SingleChildScrollView(child: content);
    }

    if (safeArea) {
      content = SafeArea(bottom: false, child: content);
    }

    return Scaffold(
      backgroundColor: background ?? theme.scaffoldBackgroundColor,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: content,
    );
  }
}

/// Responsive grid used by project, report and dashboard cards.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 260,
    this.spacing = AppSpacing.lg,
    this.runSpacing = AppSpacing.lg,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double available = constraints.maxWidth;
        final int columns = ((available + spacing) / (minItemWidth + spacing))
            .floor()
            .clamp(1, 4);
        final double width = (available - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}

/// Compact horizontally scrolling chip row with accessible touch targets.
class ResponsiveChipRow extends StatelessWidget {
  const ResponsiveChipRow({
    super.key,
    required this.children,
    this.spacing = AppSpacing.sm,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < children.length; index++) ...<Widget>[
            if (index > 0) SizedBox(width: spacing),
            children[index],
          ],
        ],
      ),
    );
  }
}
