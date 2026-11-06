import 'package:flutter/material.dart';

/// A layout wrapper that provides consistent responsive behavior across pages.
/// Handles max-width constraints, padding, and empty state routing.
class ResponsivePageLayout extends StatelessWidget {
  const ResponsivePageLayout({
    super.key,
    required this.child,
    this.showAppBar = true,
    this.appBar,
    this.bottomNavigationBar,
    this.backgroundColor,
  });

  final Widget child;
  final bool showAppBar;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: backgroundColor ?? scheme.surface,
      appBar: showAppBar ? _buildAppBar(context) : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppBar(
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      elevation: 0,
      title: const Text('Auxilia'),
    );
  }
}

/// Responsive grid that adapts column count based on available width.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 240,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = (constraints.maxWidth / minItemWidth).floor().clamp(
          1,
          6,
        );
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: <Widget>[
            for (final child in children)
              SizedBox(
                width:
                    (constraints.maxWidth - spacing * (columns - 1)) / columns,
                child: child,
              ),
          ],
        );
      },
    );
  }
}
