import 'package:flutter/material.dart';

class DuruhaStyles {
  static InputDecoration fieldDecoration(
    BuildContext context, {
    required String label,
    IconData? icon,
    String? suffix,
    String? hintText,
    String? errorText,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InputDecoration(
      labelText: label,
      // Idle Label Color
      labelStyle: TextStyle(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      // Focused Label Color
      floatingLabelStyle: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.8),
        fontWeight: FontWeight.bold,
      ),

      prefixIcon: icon != null ? Icon(icon) : null,
      // Icon is 50% Primary Color
      prefixIconColor: colorScheme.onSurfaceVariant,

      suffixText: suffix,
      suffixStyle: TextStyle(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.bold,
      ),
      hintText: hintText,
      errorText: errorText,
      errorStyle: TextStyle(color: colorScheme.onError),

      filled: true,
      // Background is 30% Surface Container
      fillColor: colorScheme.primaryContainer.withOpacity(0.3),

      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),

      // 1. ENABLED BORDER (Idle) -> 30% Outline Color
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.3),
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

  static InputDecoration? inputDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
  }) {
    return null;
  }
}
