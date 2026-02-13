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
      primaryColor: goblin500,

      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        // Primary: Brand Identity
        primary: parchment50,
        onPrimary: parchment800, // Text on primary
        primaryContainer: parchment200,
        onPrimaryContainer: parchment800,

        // Secondary: Accents
        secondary: goblin50,
        onSecondary: goblin950,
        secondaryContainer: goblin200,
        onSecondaryContainer: goblin800,

        // Surface: Paper background
        surface: parchment50,
        onSurface: goblin950, // Primary text color
        // Surface Container: Layering (Search bars, cards)
        surfaceContainer: parchment100,
        surfaceContainerHigh: parchment200,
        surfaceContainerHighest: parchment300,
        onSurfaceVariant: parchment700, // Secondary text/icons

        outline: parchment500,
        outlineVariant: goblin500,

        error: Color(0xFFBA1A1A),
        onError: Colors.white,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: parchment50,
        headerBackgroundColor: parchment200, // Top part of the calendar
        headerForegroundColor: goblin950, // Color of the date text in header
        dayForegroundColor: WidgetStateProperty.all(goblin950),
        todayBackgroundColor: WidgetStateProperty.all(parchment100),
        todayForegroundColor: WidgetStateProperty.all(parchment800),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: parchment950,
          backgroundColor: parchment300,
        ),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: parchment950,
          backgroundColor: parchment50,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return parchment300;
          }
          return null;
        }),
        dayOverlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return parchment100;
          }
          return null;
        }),
      ),
    );
  }

  // 3. DARK THEME
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: goblin950,
      primaryColor: parchment500,

      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        // Primary: Brand Identity (Lighter for dark mode)
        primary: goblin950,
        onPrimary: goblin50, // Dark text on light primary
        primaryContainer: goblin600,
        onPrimaryContainer: goblin200,

        // Secondary: Accents
        secondary: parchment900,
        onSecondary: parchment50,
        secondaryContainer: parchment600,
        onSecondaryContainer: parchment200,

        // Surface: Paper background
        surface: goblin950,
        onSurface: parchment50, // Primary text color
        // Surface Container: Layering
        surfaceContainer: goblin800,
        surfaceContainerHigh: goblin700,
        surfaceContainerHighest: goblin600,
        onSurfaceVariant: goblin400, // Secondary text/icons

        outline: goblin500,
        outlineVariant: parchment500,

        error: Color(0xFF690005),
        onError: Color(0xFFFFB4AB),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: goblin950,
        headerBackgroundColor: goblin600, // Top part of the calendar
        headerForegroundColor: goblin100, // Color of the date text in header
        dayForegroundColor: WidgetStateProperty.all(goblin100),
        todayBackgroundColor: WidgetStateProperty.all(goblin600),
        todayForegroundColor: WidgetStateProperty.all(goblin100),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: goblin100,
          backgroundColor: goblin600,
        ),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: goblin100,
          backgroundColor: goblin950,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return goblin600;
          }
          return null;
        }),
        dayOverlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return goblin100;
          }
          return null;
        }),
      ),
    );
  }
}
