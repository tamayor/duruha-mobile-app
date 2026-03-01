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

  static const Color oneLight = Color.fromARGB(255, 140, 86, 65);
  static const Color oneDark = Color.fromARGB(255, 231, 178, 158);

  static const Color twoLight = Color.fromARGB(255, 140, 104, 65);
  static const Color twoDark = Color.fromARGB(255, 229, 195, 156);

  static const Color threeLight = Color.fromARGB(255, 140, 124, 65);
  static const Color threeDark = Color.fromARGB(255, 230, 214, 157);

  static const Color fourLight = Color.fromARGB(255, 137, 140, 65);
  static const Color fourDark = Color.fromARGB(255, 217, 219, 149);

  static const Color fiveLight = Color.fromARGB(255, 116, 140, 65);
  static const Color fiveDark = Color.fromARGB(255, 202, 224, 153);

  static const Color sixLight = Color.fromARGB(255, 89, 140, 65);
  static const Color sixDark = Color.fromARGB(255, 182, 226, 161);

  static const Color sevenLight = Color.fromARGB(255, 65, 140, 71);
  static const Color sevenDark = Color.fromARGB(255, 156, 229, 162);

  static const Color eightLight = Color.fromARGB(255, 65, 140, 106);
  static const Color eightDark = Color.fromARGB(255, 155, 229, 196);

  static const Color nineLight = Color.fromARGB(255, 65, 140, 122);
  static const Color nineDark = Color.fromARGB(255, 146, 215, 199);

  static const Color zeroLight = Color.fromARGB(255, 65, 137, 140);
  static const Color zeroDark = Color.fromARGB(255, 150, 212, 214);

  static const Color neutralLight = Color(0xFF707070);
  static const Color neutralDark = Color.fromARGB(255, 186, 186, 186);

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
      case '6':
        return isDark ? sixDark : sixLight;
      case '7':
        return isDark ? sevenDark : sevenLight;
      case '8':
        return isDark ? eightDark : eightLight;
      case '9':
        return isDark ? nineDark : nineLight;
      case '0':
        return isDark ? zeroDark : zeroLight;
      case 'neutral':
        return isDark ? neutralDark : neutralLight;
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
