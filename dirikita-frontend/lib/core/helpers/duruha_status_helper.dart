import 'package:flutter/material.dart';

enum DuruhaOrderStatus {
  searching, // Looking for a farmer who can meet the quantity/date
  processing, // Farmer found, verifying the planting/harvest schedule
  matched, // Connection made! Farmer has accepted the request
  harvestSecured, // The produce is ready/picked and reserved for the user
  toSupply, // The produce is ready/picked and reserved for the user
  done,
  paused,
}

/// Centralized status definitions and colors for the Duruha Design System.
class DuruhaStatus {
  // Status Strings (Constants)
  static const String pending = 'Pending';
  static const String confirmed = 'Confirmed';
  static const String processing = 'Processing';
  static const String delivered = 'Delivered';
  static const String completed = 'Completed';
  static const String cancelled = 'Cancelled';
  static const String refunded = 'Refunded';

  // Status Colors (Light Mode Defaults)
  static const Color pendingLight = Colors.orange;
  static const Color confirmedLight = Color(0xFF2196F3); // Blue
  static const Color processingLight = Color(0xFF3F51B5); // Indigo
  static const Color deliveredLight = Color(0xFF9C27B0); // Purple
  static const Color completedLight = Color(0xFF4CAF50); // Green
  static const Color cancelledLight = Color(0xFFF44336); // Red
  static const Color refundedLight = Color(0xFF9E9E9E); // Grey

  // Status Colors (Dark Mode)
  static const Color pendingDark = Color(0xFFFFB74D); // Light Orange
  static const Color confirmedDark = Color(0xFF64B5F6); // Light Blue
  static const Color processingDark = Color(0xFF7986CB); // Light Indigo
  static const Color deliveredDark = Color(0xFFBA68C8); // Light Purple
  static const Color completedDark = Color(0xFF81C784); // Light Green
  static const Color cancelledDark = Color(0xFFE57373); // Light Red
  static const Color refundedDark = Color(0xFFBDBDBD); // Light Grey

  // Legacy Constants (kept for backward compatibility)
  static const Color colorPending = pendingLight;
  static const Color colorConfirmed = confirmedLight;
  static const Color colorProcessing = processingLight;
  static const Color colorDelivered = deliveredLight;
  static const Color colorCompleted = completedLight;
  static const Color colorCancelled = cancelledLight;
  static const Color colorRefunded = refundedLight;

  static const Color colorNational = Color(0xFF03A9F4); // Light Blue
  static const Color colorLocal = Color(0xFF8BC34A); // Light Green

  /// Get status color based on theme brightness
  static Color getColor(BuildContext context, String status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (status) {
      case pending:
        return isDark ? pendingDark : pendingLight;
      case confirmed:
        return isDark ? confirmedDark : confirmedLight;
      case processing:
        return isDark ? processingDark : processingLight;
      case delivered:
        return isDark ? deliveredDark : deliveredLight;
      case completed:
        return isDark ? completedDark : completedLight;
      case cancelled:
        return isDark ? cancelledDark : cancelledLight;
      case refunded:
        return isDark ? refundedDark : refundedLight;
      default:
        return isDark ? refundedDark : refundedLight;
    }
  }

  /// Get Market color based on theme brightness
  static Color getMarketColor(BuildContext context, String market) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (market.toLowerCase() == 'national') {
      return isDark ? const Color(0xFF4FC3F7) : const Color(0xFF0288D1);
    } else {
      return isDark ? const Color(0xFFAED581) : const Color(0xFF689F38);
    }
  }

  /// Convert status to a friendly display string (e.g., "Plant" -> "Planting")
  static String toFarmerStatusPresentTense(String status) {
    switch (status.toLowerCase()) {
      case 'set':
        return 'Set';
      case 'cultivate':
        return 'Cultivating';
      case 'plant':
        return 'Planting';
      case 'grow':
        return 'Growing';
      case 'harvest':
        return 'Harvesting';
      case 'process':
        return 'Processing';
      case 'ready to sell':
        return 'Marketing';
      case 'sold':
        return 'Sold';
      case 'done':
        return 'Done';
      default:
        return status;
    }
  }

  /// Converts a pledge status to its past tense (e.g., Plant -> Planted)
  static String toFarmerStatusPastTense(String status) {
    switch (status.toLowerCase()) {
      case 'set':
        return 'Planned';
      case 'cultivate':
        return 'Cultivated';
      case 'plant':
        return 'Planted';
      case 'grow':
        return 'Grown';
      case 'harvest':
        return 'Harvested';
      case 'process':
        return 'Processed';
      case 'ready to sell':
        return 'Marketed';
      case 'sold':
        return 'Sold';
      case 'done':
        return 'Finished';
      default:
        return status;
    }
  }

  static String getOrderStatusLabel(DuruhaOrderStatus status) {
    switch (status) {
      case DuruhaOrderStatus.searching:
        return 'Searching';
      case DuruhaOrderStatus.processing:
        return 'Processing';
      case DuruhaOrderStatus.matched:
        return 'Matched';
      case DuruhaOrderStatus.harvestSecured:
        return 'Harvest Secured';
      case DuruhaOrderStatus.toSupply:
        return 'To Supply';
      case DuruhaOrderStatus.done:
        return 'Done';
      case DuruhaOrderStatus.paused:
        return 'Paused';
    }
  }

  static Color getOrderStatusColor(
    BuildContext context,
    DuruhaOrderStatus status,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case DuruhaOrderStatus.searching:
        return isDark ? Colors.orangeAccent : Colors.orange;
      case DuruhaOrderStatus.processing:
        return isDark ? Colors.blueAccent : Colors.blue;
      case DuruhaOrderStatus.matched:
        return isDark ? Colors.tealAccent : Colors.teal;
      case DuruhaOrderStatus.harvestSecured:
        return isDark ? Colors.greenAccent : Colors.green;
      case DuruhaOrderStatus.toSupply:
        return isDark ? Colors.purpleAccent : Colors.purple;
      case DuruhaOrderStatus.done:
        return isDark ? Colors.grey[400]! : Colors.grey[600]!;
      case DuruhaOrderStatus.paused:
        return isDark ? Colors.redAccent : Colors.red;
    }
  }
}
