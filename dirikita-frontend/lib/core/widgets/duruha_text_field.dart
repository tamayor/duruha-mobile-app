import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:duruha/core/theme/duruha_styles.dart'; // Make sure this import matches your file structure

class DuruhaTextField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;

  // Optional Configurations
  final TextInputType? keyboardType;
  final bool isPassword;
  final int maxLines;

  final String? suffix;

  // Validation Controls
  final bool isRequired; // If true, automatically checks for empty text
  final String? Function(String?)?
  validator; // Custom validation logic (e.g., email check)
  final bool enabled;
  final String? helperText;
  final Function(String)? onChanged; // Callback for text changes
  final FocusNode? focusNode;
  final EdgeInsetsGeometry? padding;

  const DuruhaTextField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    this.keyboardType,
    this.isPassword = false,
    this.maxLines = 1,
    this.suffix, // Add to constructor
    this.isRequired = true, // Defaults to required!
    this.enabled = true,
    this.validator,
    this.helperText,
    this.onChanged,
    this.focusNode,
    this.padding,
  });

  bool get _isNumericInput =>
      keyboardType == TextInputType.number ||
      keyboardType == const TextInputType.numberWithOptions(decimal: true);

  /// Helper method to get clean numeric value from controller
  /// Use this when you need to submit/process the actual number
  /// Example: DuruhaTextField.getCleanValue(myController) returns "1234" instead of "1,234"
  static String getCleanValue(TextEditingController controller) {
    return controller.text.replaceAll(',', '');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        enabled: enabled,
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: isPassword,
        maxLines: maxLines,
        onChanged: onChanged,
        inputFormatters: _isNumericInput ? [_DecimalInputFormatter()] : null,

        // --- KEY FEATURE: INSTANT VALIDATION FIX ---
        // This ensures the error message vanishes immediately when the user types
        autovalidateMode: AutovalidateMode.onUserInteraction,

        // Apply your custom Design System
        decoration: DuruhaStyles.fieldDecoration(
          context,
          label: label,
          enabled: enabled,
          icon: icon,
          suffix: suffix, // Pass to decoration
          helperText: helperText,
        ),

        // Comprehensive Validation Logic
        validator: (value) {
          // 1. Automatic "Required" Check
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return '$label is required';
          }

          // 2. Custom Validator (if you passed one, like for Email or Phone)
          if (validator != null) {
            return validator!(value);
          }

          return null; // Input is valid
        },
      ),
    );
  }
}

/// Formatter that allows decimal numbers with only one decimal point
class _DecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow empty
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Check if the new text is valid
    final text = newValue.text;

    // Only allow digits, one decimal point, and optional leading sign
    if (!RegExp(r'^[+-]?[0-9]*\.?[0-9]*$').hasMatch(text)) {
      return oldValue;
    }

    // Ensure only one decimal point
    if (text.split('.').length > 2) {
      return oldValue;
    }

    return newValue;
  }
}
