import 'package:flutter/material.dart';

class DuruhaStyles {
  static InputDecoration fieldDecoration(
    BuildContext context, {
    required String label,
    bool enabled = true,
    IconData? icon,
    String? suffix,
    String? hintText,
    String? errorText,
    String? helperText,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InputDecoration(
      enabled: enabled,
      labelText: label,
      // Idle Label Color
      labelStyle: TextStyle(
        color: enabled
            ? colorScheme.onSecondaryContainer
            : colorScheme.onSurface.withValues(alpha: 0.5),
        fontWeight: FontWeight.w500,
      ),
      // Focused Label Color
      floatingLabelStyle: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.8),
        fontWeight: FontWeight.bold,
      ),

      prefixIcon: icon != null ? Icon(icon, size: 18) : null,
      // Icon is 50% Primary Color
      prefixIconColor: enabled
          ? colorScheme.onSurfaceVariant
          : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      prefixStyle: TextStyle(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.bold,
        fontSize: 8,
      ),

      suffixText: suffix,
      suffixStyle: TextStyle(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.bold,
      ),
      hintText: hintText,
      errorText: errorText,
      errorStyle: TextStyle(color: colorScheme.error),
      helperText: helperText,
      helperStyle: TextStyle(color: colorScheme.onSurfaceVariant),

      filled: true,
      // Background is 30% Surface Container
      fillColor: enabled
          ? colorScheme.surface
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),

      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),

      // 1. ENABLED BORDER (Idle) -> 30% Outline Color
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),

      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),

      // 2. FOCUSED BORDER (Active) -> onSecondary Color (Accent)
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline, width: 2.0),
      ),

      // 3. ERROR BORDER (If validation fails)
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error, width: 1.0),
      ),

      // 4. FOCUSED ERROR BORDER
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error, width: 2.0),
      ),
    );
  }

  static InputDecoration inputDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
  }) {
    return fieldDecoration(context, label: label, icon: icon);
  }
}
