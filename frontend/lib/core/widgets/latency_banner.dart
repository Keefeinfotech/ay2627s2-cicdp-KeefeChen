import 'package:flutter/material.dart';

import '../network/latency_monitor.dart';
import '../theme/app_spacing.dart';

/// Slim, dismissible warning shown when recent API traffic is slow or the
/// transport keeps failing (AUX-178). Renders nothing while healthy.
class LatencyBanner extends StatelessWidget {
  const LatencyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LatencyMonitor.instance,
      builder: (context, _) {
        final monitor = LatencyMonitor.instance;
        if (!monitor.shouldShowBanner) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final slow = monitor.quality == NetworkQuality.slow;
        final message = slow
            ? 'Connection is very slow - requests may time out.'
            : 'Slow network - responses are taking longer than usual.';

        return Material(
          color: slow ? scheme.errorContainer : scheme.tertiaryContainer,
          child: Semantics(
            liveRegion: true,
            label: message,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.speed_rounded,
                    size: AppSizes.iconSm,
                    color: slow
                        ? scheme.onErrorContainer
                        : scheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: slow
                            ? scheme.onErrorContainer
                            : scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Dismiss',
                    visualDensity: VisualDensity.compact,
                    onPressed: monitor.dismiss,
                    icon: Icon(
                      Icons.close_rounded,
                      size: AppSizes.iconSm,
                      color: slow
                          ? scheme.onErrorContainer
                          : scheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
