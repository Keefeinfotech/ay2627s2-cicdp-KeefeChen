import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Severity of a toast notification.
enum ToastType { success, error }

/// A transient toast notification that slides in from the top of the screen.
///
/// Use [ToastBox.success] or [ToastBox.error] to show a toast from any
/// [BuildContext]. The toast auto-dismisses after [duration] and can also be
/// dismissed by tapping it.
class ToastBox extends StatefulWidget {
  const ToastBox({
    super.key,
    required this.message,
    required this.type,
    this.duration = const Duration(seconds: 4),
    this.onDismiss,
  });

  final String message;
  final ToastType type;
  final Duration duration;
  final VoidCallback? onDismiss;

  /// Show a success toast.
  static void success(
    BuildContext context, {
    required String message,
    Duration? duration,
  }) {
    _show(
      context,
      message: message,
      type: ToastType.success,
      duration: duration,
    );
  }

  /// Show an error toast.
  static void error(
    BuildContext context, {
    required String message,
    Duration? duration,
  }) {
    _show(context, message: message, type: ToastType.error, duration: duration);
  }

  static void _show(
    BuildContext context, {
    required String message,
    required ToastType type,
    Duration? duration,
  }) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => ToastBox(
        message: message,
        type: type,
        duration: duration ?? const Duration(seconds: 4),
        onDismiss: () {
          entry.remove();
        },
      ),
    );
    overlay.insert(entry);
    Future.delayed(duration ?? const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

  @override
  State<ToastBox> createState() => _ToastBoxState();
}

class _ToastBoxState extends State<ToastBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ).drive(Tween<double>(begin: -60, end: 0));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    widget.onDismiss?.call();
    _controller.reverse().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color background = widget.type == ToastType.success
        ? AppColors.successGreen
        : AppColors.errorRed;
    final IconData icon = widget.type == ToastType.success
        ? Icons.check_circle_rounded
        : Icons.error_rounded;

    return Positioned(
      top: 56 + _slide.value,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
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
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Icon(icon, color: Colors.white, size: 18),
                    ),
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
