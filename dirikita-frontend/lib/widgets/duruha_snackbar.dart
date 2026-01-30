import 'package:flutter/material.dart';

enum DuruhaSnackBarType { success, error, warning, info, neutral }

class DuruhaSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    DuruhaSnackBarType type = DuruhaSnackBarType.neutral,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onActionPressed,
    String? actionLabel,
    IconData? customIcon,
    Color? customColor,
    bool floating = true,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Define colors and icons based on type
    Color backgroundColor;
    Color foregroundColor;
    IconData icon;

    switch (type) {
      case DuruhaSnackBarType.success:
        backgroundColor = Colors.green.shade600;
        foregroundColor = Colors.white;
        icon = Icons.check_circle_outline_rounded;
        break;
      case DuruhaSnackBarType.error:
        backgroundColor = colorScheme.error;
        foregroundColor = colorScheme.onError;
        icon = Icons.error_outline_rounded;
        break;
      case DuruhaSnackBarType.warning:
        backgroundColor = Colors.orange.shade800;
        foregroundColor = Colors.white;
        icon = Icons.warning_amber_rounded;
        break;
      case DuruhaSnackBarType.info:
        backgroundColor = colorScheme.secondary;
        foregroundColor = colorScheme.onSecondary;
        icon = Icons.info_outline_rounded;
        break;
      case DuruhaSnackBarType.neutral:
        backgroundColor = colorScheme.surfaceContainerHighest;
        foregroundColor = colorScheme.onSurfaceVariant;
        icon = Icons.notifications_none_rounded;
        break;
    }

    if (customColor != null) {
      backgroundColor = customColor;
      // Simple contrast check for custom color could go here,
      // but for now we trust the dev or default to white for safety on custom darks
      foregroundColor = Colors.white;
    }

    if (customIcon != null) {
      icon = customIcon;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            // Icon Area
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: foregroundColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: foregroundColor, size: 24),
            ),
            const SizedBox(width: 16),

            // Text Area
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: foregroundColor,
                      ),
                    ),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      color: foregroundColor.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Action Button
            if (actionLabel != null && onActionPressed != null)
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  onActionPressed();
                },
                style: TextButton.styleFrom(
                  foregroundColor: foregroundColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(60, 36),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: floating ? SnackBarBehavior.floating : SnackBarBehavior.fixed,
        elevation: floating ? 4 : 0,
        margin: floating ? const EdgeInsets.all(16) : null,
        shape: floating
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            : null,
        duration: duration,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // Quick Helpers for common types
  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: DuruhaSnackBarType.success,
    );
  }

  static void showError(BuildContext context, String message, {String? title}) {
    show(
      context,
      message: message,
      title: title,
      type: DuruhaSnackBarType.error,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: DuruhaSnackBarType.warning,
    );
  }

  static void showInfo(BuildContext context, String message, {String? title}) {
    show(
      context,
      message: message,
      title: title,
      type: DuruhaSnackBarType.info,
    );
  }
}
