import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_button.dart';

class DuruhaConfirmationModal {
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    IconData icon = Icons.warning_amber_rounded,
    Color? iconColor,
    bool isDanger = false,
  }) {
    final theme = Theme.of(context);

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      (iconColor ??
                              (isDanger
                                  ? Colors.red
                                  : theme.colorScheme.primary))
                          .withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 48,
                  color:
                      iconColor ??
                      (isDanger ? Colors.red : theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: DuruhaButton(
                      text: cancelText,
                      isOutline: true,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: isDanger
                            ? const LinearGradient(
                                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                              )
                            : null,
                      ),
                      child: DuruhaButton(
                        text: confirmText,
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
