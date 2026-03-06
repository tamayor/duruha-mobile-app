import 'package:intl/intl.dart';

class ConsumerFuturePlanSubscription {
  final String cfpsId;
  final String cfpId;
  final DateTime startsAt;
  final DateTime expiresAt;
  final bool isActive;
  final int extensionCount;
  final int renewCount;
  final DateTime? lastRenewedAt;

  // From joined config
  final String? planName;
  final double? minTotalValue;
  final double? maxTotalValue;
  final double? fee;
  final String? billingInterval;

  // Nested usage data from RPC
  final List<FuturePlanOrder> orders;
  final int totalOrders;

  ConsumerFuturePlanSubscription({
    required this.cfpsId,
    required this.cfpId,
    required this.startsAt,
    required this.expiresAt,
    required this.isActive,
    required this.extensionCount,
    required this.renewCount,
    this.lastRenewedAt,
    this.planName,
    this.minTotalValue,
    this.maxTotalValue,
    this.fee,
    this.billingInterval,
    this.orders = const [],
    this.totalOrders = 0,
  });

  factory ConsumerFuturePlanSubscription.fromJson(Map<String, dynamic> json) {
    // Determine if the JSON is from a raw table query (nested config) or the new RPC (flat)
    final config =
        json['consumer_future_plan_configs'] as Map<String, dynamic>?;

    // Treat 0 as "not set" — only show non-zero plan values
    double? parseNonZero(dynamic v) {
      final val = (v as num?)?.toDouble();
      return (val != null && val > 0) ? val : null;
    }

    return ConsumerFuturePlanSubscription(
      cfpsId: json['cfps_id'] as String,
      cfpId: (json['cfp_id'] ?? '') as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      isActive: json['is_active'] as bool? ?? false,
      extensionCount: (json['extension_count'] as num?)?.toInt() ?? 0,
      renewCount: (json['renew_count'] as num?)?.toInt() ?? 0,
      lastRenewedAt: json['last_renewed_at'] != null
          ? DateTime.parse(json['last_renewed_at'] as String)
          : null,
      // Handle both nested and flat structures
      planName: (config?['plan_name'] ?? json['plan_name']) as String?,
      minTotalValue: parseNonZero(
        config?['min_total_value'] ?? json['min_total_value'],
      ),
      maxTotalValue: parseNonZero(
        config?['max_total_value'] ?? json['max_total_value'],
      ),
      fee: parseNonZero(config?['fee'] ?? json['fee']),
      billingInterval:
          (config?['billing_interval'] ?? json['billing_interval']) as String?,
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      orders: (json['orders'] as List<dynamic>? ?? [])
          .map((v) => FuturePlanOrder.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Formatted expiry date for display e.g. "Mar 5, 2027"
  String get formattedExpiry => DateFormat('MMM d, yyyy').format(expiresAt);

  /// Formatted min/max value range e.g. "₱1,000 – ₱5,000"
  /// Returns null when neither value has been configured (both zero/null).
  String? get formattedValueRange {
    if (minTotalValue == null && maxTotalValue == null) return null;
    final fmt = NumberFormat('#,##0.##');
    final min = minTotalValue != null ? '₱${fmt.format(minTotalValue)}' : null;
    final max = maxTotalValue != null ? '₱${fmt.format(maxTotalValue)}' : null;
    if (min != null && max != null) return '$min – $max';
    return min ?? max;
  }

  /// Formatted billing interval e.g. "Monthly"
  String get formattedBillingInterval {
    if (billingInterval == null) return 'Monthly';
    return billingInterval![0].toUpperCase() + billingInterval!.substring(1);
  }
}

class FuturePlanUsage {
  final List<FuturePlanOrder> orders;
  final int totalOrders;

  FuturePlanUsage({required this.orders, required this.totalOrders});

  factory FuturePlanUsage.fromJson(Map<String, dynamic> json) {
    return FuturePlanUsage(
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      orders: (json['orders'] as List<dynamic>? ?? [])
          .map((v) => FuturePlanOrder.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FuturePlanOrder {
  final String orderId;
  final String paymentMethod;
  final bool isActive;
  final DateTime createdAt;
  final int totalProduces;
  final List<FuturePlanProduce> produces;

  FuturePlanOrder({
    required this.orderId,
    required this.paymentMethod,
    required this.isActive,
    required this.createdAt,
    required this.totalProduces,
    required this.produces,
  });

  factory FuturePlanOrder.fromJson(Map<String, dynamic> json) {
    return FuturePlanOrder(
      orderId: json['order_id'] as String,
      paymentMethod: json['payment_method'] as String? ?? 'Cash',
      isActive: json['is_active'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      totalProduces: (json['total_produces'] as num?)?.toInt() ?? 0,
      produces: (json['produces'] as List<dynamic>? ?? [])
          .map((v) => FuturePlanProduce.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }

  String get formattedDate => DateFormat('MMM d, yyyy').format(createdAt);
  String get orderShortId => orderId.length > 8
      ? orderId.substring(0, 8).toUpperCase()
      : orderId.toUpperCase();
}

class FuturePlanProduce {
  final String copId;
  final String? produceId;
  final String produceName;
  final String? quality;
  final int recurrence;

  FuturePlanProduce({
    required this.copId,
    this.produceId,
    required this.produceName,
    this.quality,
    required this.recurrence,
  });

  factory FuturePlanProduce.fromJson(Map<String, dynamic> json) {
    return FuturePlanProduce(
      copId: json['cop_id'] as String,
      produceId: json['produce_id'] as String?,
      produceName: json['produce_name'] as String,
      quality: json['quality'] as String?,
      recurrence: (json['recurrence'] as num?)?.toInt() ?? 0,
    );
  }
}
