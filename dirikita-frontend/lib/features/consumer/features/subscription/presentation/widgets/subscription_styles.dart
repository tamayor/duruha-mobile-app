import 'package:flutter/material.dart';

class SubscriptionStyles {
  static LinearGradient getPlanGradient(String planName, ColorScheme cs) {
    final name = planName.toLowerCase();
    final isDark = cs.brightness == Brightness.dark;

    // Premium / Gold
    if (name.contains('business') || name.contains('enterprise')) {
      if (isDark) {
        return const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFF996515)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      } else {
        return const LinearGradient(
          colors: [
            Color(0xFFFFF8E1),
            Color(0xFFFFD54F),
          ], // Lighter Gold for Light Mode
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      }
    }

    // Pro / Silver / Elite / Business / Enterprise
    if (name.contains('pro') ||
        name.contains('starter') ||
        name.contains('elite') ||
        name.contains('enterprise')) {
      if (isDark) {
        return const LinearGradient(
          colors: [Color(0xFF434343), Color(0xFF000000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      } else {
        return const LinearGradient(
          colors: [
            Color(0xFFF5F5F5),
            Color(0xFFE0E0E0),
          ], // Lighter Silver for Light Mode
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      }
    }

    // Default Brand Gradient
    return LinearGradient(
      colors: [cs.primaryContainer, cs.secondaryContainer],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
