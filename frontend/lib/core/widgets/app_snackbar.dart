import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AppSnackType { info, success, warning, error }

/// Consistent transient feedback.
abstract final class AppSnackBar {
  static void show(
    BuildContext context,
    String message, {
    AppSnackType type = AppSnackType.info,
    SnackBarAction? action,
    Duration? duration,
  }) {
    final Color background = switch (type) {
      AppSnackType.info => AppColors.deepNavy,
      AppSnackType.success => AppColors.teal,
      AppSnackType.warning => AppColors.warningAmber,
      AppSnackType.error => AppColors.errorRed,
    };

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        backgroundColor: background,
        duration:
            duration ??
            (action == null
                ? const Duration(seconds: 4)
                : const Duration(seconds: 6)),
      ),
    );
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
