import 'package:flutter/material.dart';
import '../../main.dart'; // Import main to access DuruhaApp.themeNotifier

class DuruhaThemeToggleButton extends StatelessWidget {
  const DuruhaThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    // Watch the value using ValueListenableBuilder if we want it to rebuild reactively
    // strictly within this widget, but since DuruhaApp.themeNotifier triggers a full app rebuild
    // via ValueListenableBuilder in main.dart, reading current state is fine.
    // However, to change the ICON, we need to know the current brightness.
    // The parent widget rebuilds when theme changes, so checking Theme.of(context) is sufficient.

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
        backgroundColor: theme.colorScheme.onSurface.withValues(
          alpha:
              0.5, // Adjusted alpha to match typical 'soft' background or user's preference
        ),
      ),
    );
  }
}
