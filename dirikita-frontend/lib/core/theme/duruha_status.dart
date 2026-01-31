import 'package:flutter/material.dart';

/// Centralized status definitions and colors for the Duruha Design System.
class DuruhaStatus {
  // Status Strings (Constants)
  static const String pending = 'Pending';
  static const String confirmed = 'Confirmed';
  static const String processing = 'Processing';
  static const String dispatched = 'Dispatched';
  static const String completed = 'Completed';
  static const String cancelled = 'Cancelled';
  static const String refunded = 'Refunded';

  // Status Colors
  static const Color colorPending = Colors.orange;
  static const Color colorConfirmed = Colors.blue;
  static const Color colorProcessing = Colors.indigo;
  static const Color colorDispatched = Colors.purple;
  static const Color colorCompleted = Colors.green;
  static const Color colorCancelled = Colors.red;
  static const Color colorRefunded = Colors.grey;

  /// Helper to get color by string status (case-insensitive check safe)
  static Color getColor(String status) {
    switch (status) {
      case pending:
        return colorPending;
      case confirmed:
        return colorConfirmed;
      case processing:
        return colorProcessing;
      case dispatched:
        return colorDispatched;
      case completed:
        return colorCompleted;
      case cancelled:
        return colorCancelled;
      case refunded:
        return colorRefunded;
      default:
        return Colors.grey; // Fallback
    }
  }
}
