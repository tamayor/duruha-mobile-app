import 'package:flutter/material.dart';

class DuruhaColorHelper {
  // --- Descriptive Scale: Low to High ---
  static const Color lowLight = Color(0xFFB45309); // Deep Amber
  static const Color lowDark = Color(0xFFFBBF24); // Bright Yellow

  static const Color mediumLight = Color(0xFF3F6212); // Deep Olive
  static const Color mediumDark = Color(0xFFA3E635); // Electric Lime

  static const Color highLight = Color(0xFF14532D); // Dark Forest
  static const Color highDark = Color(0xFF4ADE80); // Bright Mint Green

  // --- Numeric Scale: 1 to 10 ---

  static const Color oneLight = Color(0xFF92280A);
  static const Color oneDark = Color(0xFFFB7E5E);

  static const Color twoLight = Color(0xFF8B3B09);
  static const Color twoDark = Color(0xFFFCA261);

  static const Color threeLight = Color(0xFF854D0E);
  static const Color threeDark = Color(0xFFFBBF24);

  static const Color fourLight = Color(0xFF713F12);
  static const Color fourDark = Color(0xFFFCD34D);

  static const Color fiveLight = Color(0xFF3F6212);
  static const Color fiveDark = Color(0xFFA3E635);

  static const Color sixLight = Color(0xFF166534);
  static const Color sixDark = Color(0xFF4ADE80);

  static const Color sevenLight = Color(0xFF065F46);
  static const Color sevenDark = Color(0xFF34D399);

  static const Color eightLight = Color(0xFF0F766E);
  static const Color eightDark = Color(0xFF2DD4BF);

  static const Color nineLight = Color(0xFF155E75);
  static const Color nineDark = Color(0xFF22D3EE);

  static const Color zeroLight = Color(0xFF1E3A8A);
  static const Color zeroDark = Color(0xFF60A5FA);

  // --- Type / Variety ---

  static const Color hybridLight = Color(0xFF4C1D95); // Deep Royal Purple
  static const Color hybridDark = Color(0xFFC4B5FD); // Bright Lavender

  static const Color nativeLight = Color(0xFF064E3B); // Deep Emerald
  static const Color nativeDark = Color(0xFF34D399); // Bright Teal

  // --- Neutral ---

  static const Color neutralLight = Color(0xFF374151);
  static const Color neutralDark = Color(0xFFD1D5DB);

  // --- Common Status Colors ---

  static const Color completedLight = Color(0xFF15803D); // Rich Green
  static const Color completedDark = Color(0xFF4ADE80); // Neon Mint

  static const Color pendingLight = Color(0xFF92400E); // Deep Burnt Amber
  static const Color pendingDark = Color(0xFFFBBF24); // Bright Amber

  static const Color cancelledLight = Color(0xFF991B1B); // Deep Red
  static const Color cancelledDark = Color(0xFFFCA5A5); // Bright Coral

  static Color getColor(BuildContext context, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (value.toLowerCase()) {
      // Descriptive scale
      case 'low':
        return isDark ? lowDark : lowLight;
      case 'medium':
        return isDark ? mediumDark : mediumLight;
      case 'high':
        return isDark ? highDark : highLight;

      // Numeric scale
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

      // Type / variety
      case 'hybrid':
        return isDark ? hybridDark : hybridLight;
      case 'native':
        return isDark ? nativeDark : nativeLight;

      // Neutral
      case 'neutral':
        return isDark ? neutralDark : neutralLight;

      // Common statuses
      case 'completed':
        return isDark ? completedDark : completedLight;
      case 'pending':
        return isDark ? pendingDark : pendingLight;
      case 'cancelled':
        return isDark ? cancelledDark : cancelledLight;

      // Subscription statuses
      case 'active':
        return isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
      case 'inactive':
        return isDark ? const Color(0xFFA3A3A3) : const Color(0xFF525252);
      case 'expired':
        return isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E);
      case 'paused':
        return isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);

      // Market type
      case 'national':
        return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
      case 'local':
        return isDark ? const Color(0xFFA3E635) : const Color(0xFF4D7C0F);

      default:
        return isDark ? neutralDark : neutralLight;
    }
  }
}
