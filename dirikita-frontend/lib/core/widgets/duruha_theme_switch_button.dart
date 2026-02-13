import 'package:flutter/material.dart';
import '../../main.dart'; // Import main to access DuruhaApp.themeNotifier

class DuruhaThemeToggleButton extends StatelessWidget {
  const DuruhaThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return IconButton(
      onPressed: () {
        DuruhaApp.themeNotifier.value = isDark
            ? ThemeMode.light
            : ThemeMode.dark;
      },
      icon: Icon(
        isDark ? Icons.light_mode : Icons.dark_mode,
        color: theme.colorScheme.primary,
      ),
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}
