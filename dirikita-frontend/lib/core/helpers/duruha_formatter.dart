import 'package:intl/intl.dart';

class DuruhaFormatter {
  /// Formats a double to a currency string (e.g., ₱1,234.56 or ₱1 234.56)
  static String formatCurrency(
    double amount, {
    String symbol = '₱',
    int decimalDigits = 2,
    String separator = ',',
  }) {
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
  }

  /// Formats a number with separators but no symbol (e.g., 1,234)
  static String formatNumber(num value, {String separator = ','}) {
    String formatted = NumberFormat('#,###.##').format(value);
    if (separator != ',') {
      formatted = formatted.replaceAll(',', separator);
    }
    return formatted;
  }
}
