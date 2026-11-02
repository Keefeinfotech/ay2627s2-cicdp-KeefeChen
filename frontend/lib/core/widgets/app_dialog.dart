import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Standard confirmation dialog used for destructive and irreversible actions.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        icon: icon == null
            ? null
            : Icon(
                icon,
                color: destructive ? scheme.error : scheme.primary,
                size: 28,
              ),
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );

  return result ?? false;
}

/// Shared dialog chrome for informational dialogs.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions = const <Widget>[],
    this.icon,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: icon == null ? null : Icon(icon, size: 28),
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: child,
      ),
      actions: actions,
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
    );
  }
}
