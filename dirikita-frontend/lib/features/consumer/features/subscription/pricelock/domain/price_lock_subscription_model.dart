class PriceLockSubscription {
  final String cplsId;
  final String planName;
  final String status;
  final int monthlyCreditLimit;
  final int remainingCredits;
  final int usedCredits;
  final DateTime startsAt;
  final DateTime endsAt;

  PriceLockSubscription({
    required this.cplsId,
    required this.planName,
    required this.status,
    required this.monthlyCreditLimit,
    required this.remainingCredits,
    required this.usedCredits,
    required this.startsAt,
    required this.endsAt,
  });

  factory PriceLockSubscription.fromJson(Map<String, dynamic> json) {
    return PriceLockSubscription(
      cplsId: json['cpls_id'] as String,
      planName: json['plan_name'] as String,
      status: json['status'] as String,
      monthlyCreditLimit: (json['monthly_credit_limit'] as num).toInt(),
      remainingCredits: (json['remaining_credits'] as num).toInt(),
      usedCredits: (json['used_credits'] as num).toInt(),
      startsAt: DateTime.parse(json['starts_at']),
      endsAt: DateTime.parse(json['ends_at']),
    );
  }
}

class PriceLockUsageResponse {
  final String cplsId;
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime? lastResetDate;
  final String planName;
  final int monthlyCreditLimit;
  final String billingInterval;
  final double fee;
  final int remainingCredits;
  final int usedCredits;
  final List<PriceLockUsageItem> usage;

  PriceLockUsageResponse({
    required this.cplsId,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    this.lastResetDate,
    required this.planName,
    required this.monthlyCreditLimit,
    required this.billingInterval,
    required this.fee,
    required this.remainingCredits,
    required this.usedCredits,
    required this.usage,
  });

  factory PriceLockUsageResponse.fromJson(Map<String, dynamic> json) {
    return PriceLockUsageResponse(
      cplsId: json['cpls_id'] as String,
      status: json['status'] as String,
      startsAt: DateTime.parse(json['starts_at']),
      endsAt: DateTime.parse(json['ends_at']),
      lastResetDate: json['last_reset_date'] != null
          ? DateTime.parse(json['last_reset_date'])
          : null,
      planName: json['plan_name'] as String,
      monthlyCreditLimit: (json['monthly_credit_limit'] as num).toInt(),
      billingInterval: json['billing_interval'] as String,
      fee: (json['fee'] as num).toDouble(),
      remainingCredits: (json['remaining_credits'] as num).toInt(),
      usedCredits: (json['used_credits'] as num).toInt(),
      usage: (json['usage'] as List? ?? [])
          .map((item) => PriceLockUsageItem.fromJson(item))
          .toList(),
    );
  }
}

class PriceLockUsageItem {
  final String covgId;
  final DateTime? dateNeeded;
  final String form;
  final int quantity;
  final bool isAny;
  final int groupCreditsUsed;
  final List<PriceLockSelectedVariety> selectedVarieties;

  PriceLockUsageItem({
    required this.covgId,
    this.dateNeeded,
    required this.form,
    required this.quantity,
    required this.isAny,
    required this.groupCreditsUsed,
    required this.selectedVarieties,
  });

  factory PriceLockUsageItem.fromJson(Map<String, dynamic> json) {
    return PriceLockUsageItem(
      covgId: json['covg_id'] as String,
      dateNeeded: json['date_needed'] != null
          ? DateTime.parse(json['date_needed'])
          : null,
      form: json['form'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      isAny: json['is_any'] as bool? ?? false,
      groupCreditsUsed: (json['group_credits_used'] as num?)?.toInt() ?? 0,
      selectedVarieties: (json['selected_varieties'] as List? ?? [])
          .map((item) => PriceLockSelectedVariety.fromJson(item))
          .toList(),
    );
  }
}

class PriceLockSelectedVariety {
  final String covId;
  final String orderId;
  final String varietyId;
  final String varietyName;
  final String produceId;
  final String produceName;
  final String baseUnit;
  final String? listingId;
  final double? priceLock;
  final double? variableConsumerPrice;
  final double? finalPrice;
  final bool hasPaid;
  final String? paymentMethod;
  final String? foaId;
  final int allocatedQuantity;
  final int creditsUsed;

  PriceLockSelectedVariety({
    required this.covId,
    required this.orderId,
    required this.varietyId,
    required this.varietyName,
    required this.produceId,
    required this.produceName,
    required this.baseUnit,
    this.listingId,
    this.priceLock,
    this.variableConsumerPrice,
    this.finalPrice,
    required this.hasPaid,
    this.paymentMethod,
    this.foaId,
    required this.allocatedQuantity,
    required this.creditsUsed,
  });

  factory PriceLockSelectedVariety.fromJson(Map<String, dynamic> json) {
    return PriceLockSelectedVariety(
      covId: json['cov_id'] as String,
      orderId: json['order_id'] as String,
      varietyId: json['variety_id'] as String,
      varietyName: json['variety_name'] as String,
      produceId: json['produce_id'] as String,
      produceName: json['produce_name'] as String,
      baseUnit: json['base_unit'] as String,
      listingId: json['listing_id'] as String?,
      priceLock: (json['price_lock'] as num?)?.toDouble(),
      variableConsumerPrice: (json['variable_consumer_price'] as num?)
          ?.toDouble(),
      finalPrice: (json['final_price'] as num?)?.toDouble(),
      hasPaid: json['has_paid'] as bool? ?? false,
      paymentMethod: json['payment_method'] as String?,
      foaId: json['foa_id'] as String?,
      allocatedQuantity: (json['allocated_quantity'] as num?)?.toInt() ?? 0,
      creditsUsed: (json['credits_used'] as num?)?.toInt() ?? 0,
    );
  }
}
