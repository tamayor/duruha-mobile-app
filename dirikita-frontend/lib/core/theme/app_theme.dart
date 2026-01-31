import 'package:flutter/material.dart';

class DuruhaTheme {
  // 1. PRIMITIVES (Tailwind-style 50-950)
  // Parchment (Beiges)
  static const Color parchment50 = Color.fromARGB(
    255,
    251,
    251,
    234,
  ); // Was 'parchment'
  static const Color parchment100 = Color.fromARGB(255, 250, 238, 203);
  static const Color parchment200 = Color.fromARGB(255, 244, 232, 194);
  static const Color parchment300 = Color.fromARGB(255, 234, 218, 182);
  static const Color parchment400 = Color.fromARGB(255, 220, 194, 156);
  static const Color parchment500 = Color.fromARGB(255, 206, 166, 140);
  static const Color parchment600 = Color.fromARGB(
    255,
    170,
    140,
    110,
  ); // Interpolated
  static const Color parchment700 = Color.fromARGB(255, 125, 103, 45);
  static const Color parchment800 = Color.fromARGB(
    255,
    110,
    85,
    40,
  ); // Interpolated
  static const Color parchment900 = Color.fromARGB(255, 92, 74, 30);
  static const Color parchment950 = Color.fromARGB(
    255,
    60,
    45,
    20,
  ); // Interpolated

  // Goblin (Greens)
  static const Color goblin50 = Color.fromARGB(255, 230, 247, 237);
  static const Color goblin100 = Color.fromARGB(
    255,
    200,
    235,
    215,
  ); // Interpolated
  static const Color goblin200 = Color.fromARGB(
    255,
    150,
    210,
    180,
  ); // Interpolated
  static const Color goblin300 = Color.fromARGB(255, 74, 158, 114);
  static const Color goblin400 = Color.fromARGB(
    255,
    60,
    140,
    100,
  ); // Interpolated
  static const Color goblin500 = Color.fromARGB(255, 45, 122, 84);
  static const Color goblin600 = Color.fromARGB(255, 21, 74, 47);
  static const Color goblin700 = Color.fromARGB(
    255,
    18,
    65,
    40,
  ); // Interpolated
  static const Color goblin800 = Color.fromARGB(255, 15, 54, 34);
  static const Color goblin900 = Color.fromARGB(255, 5, 26, 16);
  static const Color goblin950 = Color.fromARGB(255, 2, 13, 8);

  // 2. LIGHT THEME
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: parchment50,
      primaryColor: goblin600,

      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        // Primary: Brand Identity
        primary: parchment50,
        onPrimary: goblin600, // Text on primary
        primaryContainer: parchment200,
        onPrimaryContainer: goblin900,

        // Secondary: Accents
        secondary: parchment400,
        onSecondary: goblin950,
        secondaryContainer: parchment200,
        onSecondaryContainer: goblin900,

        // Surface: Paper background
        surface: parchment50,
        onSurface: goblin950, // Primary text color
        // Surface Container: Layering (Search bars, cards)
        surfaceContainer: parchment100,
        surfaceContainerHigh: parchment200,
        surfaceContainerHighest: parchment300,
        onSurfaceVariant: parchment700, // Secondary text/icons

        outline: parchment400,
        outlineVariant: parchment300,

        error: Colors.white,
        onError: Color(0xFFBA1A1A),
      ),
    );
  }

  // 3. DARK THEME
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: goblin950,
      primaryColor: goblin300,

      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        // Primary: Brand Identity (Lighter for dark mode)
        primary: goblin950,
        onPrimary: parchment100, // Dark text on light primary
        primaryContainer: goblin800,
        onPrimaryContainer: goblin100,

        // Secondary: Accents
        secondary: goblin600,
        onSecondary: goblin50,
        secondaryContainer: goblin800,
        onSecondaryContainer: parchment100,

        // Surface: Paper background
        surface: goblin950,
        onSurface: parchment50, // Primary text color
        // Surface Container: Layering
        surfaceContainer: goblin900,
        surfaceContainerHigh: goblin800,
        surfaceContainerHighest: goblin700,
        onSurfaceVariant: goblin200, // Secondary text/icons

        outline: goblin600,
        outlineVariant: goblin700,

        error: Color(0xFF690005),
        onError: Color(0xFFFFB4AB),
      ),
    );
  }
}
