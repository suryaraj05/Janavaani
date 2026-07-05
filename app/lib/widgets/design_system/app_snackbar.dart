import 'package:flutter/material.dart';
import '../../config/app_design_system.dart';

/// Custom snackbar widget with modern styling
class AppSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    AppSnackbarType type = AppSnackbarType.info,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            icon ?? _getDefaultIcon(type),
            color: _getTextColor(type),
            size: 20,
          ),
          const SizedBox(width: AppDesignSystem.spacingM),
          Expanded(
            child: Text(
              message,
              style: AppDesignSystem.bodyMedium.copyWith(
                color: _getTextColor(type),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                onAction();
              },
              child: Text(
                actionLabel,
                style: AppDesignSystem.labelMedium.copyWith(
                  color: _getTextColor(type),
                ),
              ),
            ),
        ],
      ),
      backgroundColor: _getBackgroundColor(type),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
      ),
      margin: const EdgeInsets.all(AppDesignSystem.spacingM),
      duration: duration,
      elevation: 4,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: AppSnackbarType.success,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: AppSnackbarType.error,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void warning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: AppSnackbarType.warning,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void info(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: AppSnackbarType.info,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static IconData _getDefaultIcon(AppSnackbarType type) {
    switch (type) {
      case AppSnackbarType.success:
        return Icons.check_circle_outline;
      case AppSnackbarType.error:
        return Icons.error_outline;
      case AppSnackbarType.warning:
        return Icons.warning_amber_rounded;
      case AppSnackbarType.info:
        return Icons.info_outline;
    }
  }

  static Color _getBackgroundColor(AppSnackbarType type) {
    switch (type) {
      case AppSnackbarType.success:
        return AppDesignSystem.successColor;
      case AppSnackbarType.error:
        return AppDesignSystem.errorColor;
      case AppSnackbarType.warning:
        return AppDesignSystem.warningColor;
      case AppSnackbarType.info:
        return AppDesignSystem.infoColor;
    }
  }

  static Color _getTextColor(AppSnackbarType type) {
    return Colors.white;
  }
}

enum AppSnackbarType { success, error, warning, info }

