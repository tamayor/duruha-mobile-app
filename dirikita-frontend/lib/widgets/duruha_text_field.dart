import 'package:flutter/material.dart';
import 'package:duruha/theme/duruha_styles.dart'; // Make sure this import matches your file structure

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
  final Function(String)? onChanged; // Callback for text changes

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
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword,
        maxLines: maxLines,
        onChanged: onChanged,

        // --- KEY FEATURE: INSTANT VALIDATION FIX ---
        // This ensures the error message vanishes immediately when the user types
        autovalidateMode: AutovalidateMode.onUserInteraction,

        // Apply your custom Design System
        decoration: DuruhaStyles.fieldDecoration(
          context,
          label: label,
          icon: icon,
          suffix: suffix, // Pass to decoration
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
