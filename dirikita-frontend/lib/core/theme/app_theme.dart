import 'package:flutter/material.dart';

class DuruhaTheme {
  // 1. PRIMITIVES (Tailwind-style 50-950)
  // Parchment (Beiges)
  static const Color parchment50 = Color.fromARGB(
    255,
    252,
    251,
    246,
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

        // ========================
        // PRIMARY — Goblin
        // ========================
        primary: goblin50,
        onPrimary: goblin600,
        primaryContainer: goblin200,
        onPrimaryContainer: goblin900,

        // ========================
        // SECONDARY — Neutral Gray
        // ========================
        secondary: parchment100,
        onSecondary: Color(0xFF6B7280),
        secondaryContainer: Color(0xFFE5E7EB),
        onSecondaryContainer: Color(0xFF1F2937),
        // ========================
        // TERTIARY — Parchment Accent
        // ========================
        tertiary: parchment200,
        onTertiary: parchment900,
        tertiaryContainer: parchment400,
        onTertiaryContainer: parchment950,

        // ========================
        // SURFACES — Soft Warm Gray
        // ========================
        surface: Color(0xFFF6F6F4), // Very light warm gray
        onSurface: goblin950,
        onSurfaceVariant: Color(0xFF5F5F5A),

        surfaceContainerLow: Color(0xFFFAFAF9),
        surfaceContainer: Color(0xFFF1F1EE),
        surfaceContainerHigh: Color(0xFFE5E5E2),
        surfaceContainerHighest: Color(0xFFDCDCD8),

        // ========================
        // OUTLINES
        // ========================
        outline: Color(0xFFB8B8B2),
        outlineVariant: Color(0xFFDADAD6),

        // ========================
        // ERROR
        // ========================
        error: Colors.white,
        onError: Color(0xFFBA1A1A),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),

        // ========================
        // INVERSE
        // ========================
        inverseSurface: goblin900,
        onInverseSurface: Colors.white,
        inversePrimary: goblin200,

        shadow: Colors.black,
        scrim: Colors.black,
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: parchment50,
        headerBackgroundColor: parchment200, // Top part of the calendar
        headerForegroundColor: goblin950, // Color of the date text in header
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return goblin950.withAlpha(80);
          }
          if (states.contains(WidgetState.selected)) {
            return parchment950;
          }
          return goblin950;
        }),
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

        // ========================
        // PRIMARY — Parchment
        // ========================
        primary: parchment950,
        onPrimary: parchment100,
        primaryContainer: parchment800,
        onPrimaryContainer: parchment300,

        // ========================
        // SECONDARY — Neutral Accent (Gray)
        // ========================
        secondary: Color(0xFF1A1A1A), // Soft neutral accent
        onSecondary: Color(0xFFB8B8B2),
        secondaryContainer: Color(0xFF2A2A2A),
        onSecondaryContainer: Color(0xFFE8E8E5),

        // ========================
        // TERTIARY — Goblin Accent
        // ========================
        tertiary: goblin800,
        onTertiary: goblin100,
        tertiaryContainer: goblin700,
        onTertiaryContainer: goblin200,

        // ========================
        // SURFACES — Neutral Dark Foundation
        // ========================
        surface: Color(0xFF121212),
        onSurface: parchment100,

        onSurfaceVariant: Color(0xFFB5B5B0),

        surfaceContainerLow: Color(0xFF151515),
        surfaceContainer: Color(0xFF1A1A1A),
        surfaceContainerHigh: Color(0xFF202020),
        surfaceContainerHighest: Color(0xFF2A2A2A),

        // ========================
        // OUTLINES
        // ========================
        outline: Color(0xFF3A3A36),
        outlineVariant: Color(0xFF2A2A28),

        // ========================
        // ERROR
        // ========================
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFDAD6),

        // ========================
        // INVERSE (for bottom sheets, etc.)
        // ========================
        inverseSurface: parchment100,
        onInverseSurface: parchment900,
        inversePrimary: parchment600,

        shadow: Colors.black,
        scrim: Colors.black,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: goblin950,
        headerBackgroundColor: goblin600, // Top part of the calendar
        headerForegroundColor: goblin100, // Color of the date text in header
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return goblin100.withAlpha(80);
          }
          if (states.contains(WidgetState.selected)) {
            return goblin950;
          }
          return goblin100;
        }),
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
