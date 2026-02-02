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
}
