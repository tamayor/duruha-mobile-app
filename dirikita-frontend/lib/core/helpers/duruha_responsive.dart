import 'package:flutter/material.dart';

// Define your breakpoints
class DuruhaBreakpoints {
  static const double mobileMax = 600;
  static const double tabletMax = 1024;
}

extension ResponsiveContext on BuildContext {
  // Returns the physical width of the screen
  double get screenWidth => MediaQuery.of(this).size.width;

  // Booleans for quick checks
  bool get isMobile => screenWidth < DuruhaBreakpoints.mobileMax;
  bool get isTablet =>
      screenWidth >= DuruhaBreakpoints.mobileMax &&
      screenWidth < DuruhaBreakpoints.tabletMax;
  bool get isDesktop => screenWidth >= DuruhaBreakpoints.tabletMax;

  // Returns a descriptive string if you prefer that logic
  String get deviceSize {
    if (isMobile) return "small";
    if (isTablet) return "medium";
    return "large";
  }
}
