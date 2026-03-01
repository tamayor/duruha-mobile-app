import 'package:intl/intl.dart';

class DuruhaFormatter {
  /// Formats a double to a currency string (e.g., ₱1,234.56 or ₱1 234.56)
  static String formatCurrency(
    double amount, {
    String symbol = '₱',
    int decimalDigits = 2,
    String separator = ',',
  }) {
    try {
      // Handle edge cases
      if (amount.isNaN || amount.isInfinite) {
        return '$symbol${amount.toString()}';
      }

      final formatter = NumberFormat.currency(
        locale: 'en_PH',
        symbol: symbol,
        decimalDigits: decimalDigits,
      );
      String formatted = formatter.format(amount);
      if (separator != ',') {
        formatted = formatted.replaceAll(',', separator);
      }
      return formatted;
    } catch (e) {
      // If formatting fails, return basic format
      return '$symbol${amount.toStringAsFixed(decimalDigits)}';
    }
  }

  /// Formats a number with separators but no symbol (e.g., 1,234)
  static String formatNumber(num value, {String separator = ','}) {
    try {
      // Handle edge cases
      if (value.isNaN || value.isInfinite) {
        return value.toString();
      }

      String formatted = NumberFormat('#,###.##').format(value);
      if (separator != ',') {
        formatted = formatted.replaceAll(',', separator);
      }
      return formatted;
    } catch (e) {
      // If formatting fails, return the raw value as string
      return value.toString();
    }
  }

  /// Formats a date to a readable string (e.g., Feb 3, 2026)
  static String formatDate(DateTime date) {
    try {
      return DateFormat('MMM d, y').format(date);
    } catch (e) {
      return date.toIso8601String().split('T')[0];
    }
  }

  /// Formats a date to a readable string (e.g., February 3, 2026)
  static String formatDateTime(DateTime date) {
    try {
      return DateFormat('MMM d, y hh:mm a').format(date);
    } catch (e) {
      return date.toIso8601String().split('T')[0];
    }
  }

  /// Formats a number with compact notation (e.g. 1.2k, 1M)
  static String formatCompactNumber(num value) {
    try {
      if (value.isNaN || value.isInfinite) {
        return value.toString();
      }
      return NumberFormat.compact(locale: 'en_PH').format(value);
    } catch (e) {
      return value.toString();
    }
  }
}
