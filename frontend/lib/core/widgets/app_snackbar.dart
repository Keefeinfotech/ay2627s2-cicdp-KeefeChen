import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum AppSnackType { info, success, warning, error }

/// Consistent transient feedback.
///
/// Messages appear as a compact, centred card at the **top** of the screen.
/// They never stretch to the full page width and are colour-coded by severity,
/// so the outcome is obvious without the user looking at the bottom of the
/// page. A single toast is shown at a time: a new message replaces the old one.
abstract final class AppSnackBar {
  static OverlayEntry? _entry;

  static void show(
    BuildContext context,
    String message, {
    AppSnackType type = AppSnackType.info,
    SnackBarAction? action,
    Duration? duration,
  }) {
    final overlay = Overlay.of(context);
    dismiss();

    late final OverlayEntry entry;
    void remove() {
      if (identical(_entry, entry)) _entry = null;
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (_) => _AppToast(
        message: message,
        type: type,
        actionLabel: action?.label,
        onAction: action?.onPressed,
        duration:
            duration ??
            (action == null
                ? const Duration(seconds: 4)
                : const Duration(seconds: 6)),
        onDismiss: remove,
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  /// Hide the current toast, if any. Useful for tests and route changes.
  static void dismiss() {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    entry.remove();
  }

  static void info(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    show(context, message, action: action);
  }

  static void success(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    show(context, message, type: AppSnackType.success, action: action);
  }

  static void error(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    show(context, message, type: AppSnackType.error, action: action);
  }

  static void warning(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    show(context, message, type: AppSnackType.warning, action: action);
  }
}

class _AppToast extends StatefulWidget {
  const _AppToast({
    required this.message,
    required this.type,
    required this.duration,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  final String message;
  final AppSnackType type;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  State<_AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<_AppToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slide;
  late final Animation<double> _fade;
  Timer? _dismissTimer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Never start above y=0: an action must be tappable on the very first
    // frame, including in widget tests that do not pump the animation.
    _slide = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ).drive(Tween<double>(begin: -AppSpacing.lg, end: 0));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_dismissing) return;
    _dismissing = true;
    _dismissTimer?.cancel();
    _controller.reverse().whenComplete(() {
      if (mounted) widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = switch (widget.type) {
      AppSnackType.info => AppColors.deepNavy,
      AppSnackType.success => AppColors.teal,
      AppSnackType.warning => AppColors.warningAmber,
      AppSnackType.error => AppColors.errorRed,
    };
    final icon = switch (widget.type) {
      AppSnackType.info => Icons.info_rounded,
      AppSnackType.success => Icons.check_circle_rounded,
      AppSnackType.warning => Icons.warning_rounded,
      AppSnackType.error => Icons.error_rounded,
    };

    return Positioned(
      top: AppSpacing.lg + _slide.value,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Semantics(
              liveRegion: true,
              label: widget.message,
              child: Container(
                key: const Key('app-toast'),
                constraints: const BoxConstraints(maxWidth: 560),
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(icon, color: Colors.white, size: AppSizes.iconMd),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.actionLabel != null) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      TextButton(
                        onPressed: () {
                          widget.onAction?.call();
                          _dismiss();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(widget.actionLabel!),
                      ),
                    ],
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
