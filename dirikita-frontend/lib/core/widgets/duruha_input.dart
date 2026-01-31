import 'package:duruha/core/theme/duruha_styles.dart';
import 'package:flutter/material.dart';

class DuruhaInput extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController? controller;
  final bool isPassword;
  final TextInputType? keyboardType;
  final String? hintText;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const DuruhaInput({
    super.key,
    required this.label,
    required this.icon,
    this.controller,
    this.isPassword = false,
    this.keyboardType,
    this.hintText,
    this.errorText,
    this.onChanged,
  });

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
        decoration: DuruhaStyles.fieldDecoration(
          context,
          label: label,
          icon: icon,
          hintText: hintText,
          errorText: errorText,
        ),
      ),
    );
  }
}
