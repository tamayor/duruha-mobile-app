import 'package:duruha/core/theme/duruha_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DuruhaInput extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController? controller;
  final bool isPassword;
  final TextInputType? keyboardType;
  final String? hintText;
  final String? errorText;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final String? suffixText;

  const DuruhaInput({
    super.key,
    required this.label,
    required this.icon,
    this.controller,
    this.isPassword = false,
    this.keyboardType,
    this.hintText,
    this.errorText,
    this.helperText,
    this.onChanged,
    this.suffixText,
  });

  bool get _isNumericInput =>
      keyboardType == TextInputType.number ||
      keyboardType == const TextInputType.numberWithOptions(decimal: true);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        onChanged: onChanged,
        cursorColor: theme.colorScheme.onSecondary,
        style: TextStyle(color: theme.colorScheme.onSecondary),
        inputFormatters: _isNumericInput ? [_DecimalInputFormatter()] : null,
        decoration: DuruhaStyles.fieldDecoration(
          context,
          label: label,
          icon: icon,
          hintText: hintText,
          errorText: errorText,
          helperText: helperText,
          suffix: suffixText,
        ),
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

    // Only allow digits and one decimal point
    if (!RegExp(r'^[0-9]*\.?[0-9]*$').hasMatch(text)) {
      return oldValue;
    }

    // Ensure only one decimal point
    if (text.split('.').length > 2) {
      return oldValue;
    }

    return newValue;
  }
}
