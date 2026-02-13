import 'package:flutter/material.dart';

class DuruhaColorHelper {
  // --- Descriptive Scale: Low to High ---
  // Light: Deep Earth Tones | Dark: Vibrant Neons
  static const Color lowLight = Color(0xFFB45309); // Deep Amber
  static const Color lowDark = Color(0xFFFDE68A); // Pale Gold

  static const Color mediumLight = Color(0xFF4D7C0F); // Deep Lime/Olive
  static const Color mediumDark = Color(0xFFBEF264); // Electric Lime

  static const Color highLight = Color(0xFF14532D); // Dark Forest
  static const Color highDark = Color(0xFF86EFAC); // Soft Mint Green

  // --- Numeric Scale: 1 to 5 ---
  // 1: Neutral/Minimal
  static const Color oneLight = Color(0xFF374151); // Dark Slate
  static const Color oneDark = Color(0xFFD1D5DB); // Light Grey

  // 2: Warning/Developing
  static const Color twoLight = Color(0xFFC2410C); // Burnt Orange
  static const Color twoDark = Color(0xFFFDBA74); // Peach

  // 3: Healthy/Standard
  static const Color threeLight = Color(0xFF047857); // Deep Emerald
  static const Color threeDark = Color(0xFF6EE7B7); // Seafoam

  // 4: Strong/Resilient
  static const Color fourLight = Color(0xFF1E40AF); // Deep Cobalt
  static const Color fourDark = Color(0xFF93C5FD); // Sky Blue

  // 5: Premium/Native Peak
  static const Color fiveLight = Color(0xFF4C1D95); // Deep Royal Purple
  static const Color fiveDark = Color(0xFFDDD6FE); // Lavender Gloss

  static const Color hybridLight = Color(0xFF4C1D95); // Deep Royal Purple
  static const Color hybridDark = Color(0xFFDDD6FE); // Lavender Gloss
  static const Color nativeLight = Color.fromARGB(
    255,
    7,
    109,
    94,
  ); // Deep Royal Purple
  static const Color nativeDark = Color.fromARGB(
    255,
    91,
    229,
    209,
  ); // Lavender Gloss

  static Color getColor(BuildContext context, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (value.toLowerCase()) {
      case 'low':
        return isDark ? lowDark : lowLight;
      case 'medium':
        return isDark ? mediumDark : mediumLight;
      case 'high':
        return isDark ? highDark : highLight;
      case '1':
        return isDark ? oneDark : oneLight;
      case '2':
        return isDark ? twoDark : twoLight;
      case '3':
        return isDark ? threeDark : threeLight;
      case '4':
        return isDark ? fourDark : fourLight;
      case '5':
        return isDark ? fiveDark : fiveLight;
      case 'hybrid':
        return isDark ? hybridDark : hybridLight;
      case 'native':
        return isDark ? nativeDark : nativeLight;
      default:
        // Default to a neutral that follows the same logic
        return isDark ? Colors.grey[300]! : Colors.grey[800]!;
    }
  }
}
