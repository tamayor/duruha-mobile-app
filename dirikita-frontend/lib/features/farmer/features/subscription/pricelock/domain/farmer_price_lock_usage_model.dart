
class FarmerOfferUsage {
  final String offerId;
  final String varietyId;
  final String varietyName;
  final String produceId;
  final String produceName;
  final String baseUnit;
  final String? listingId;
  final num quantity;
  final num remainingQuantity;
  final bool isActive;
  final bool isPriceLocked;
  final DateTime? availableFrom;
  final DateTime? availableTo;
  final num totalPriceLockCredit;
  final num remainingPriceLockCredit;
  final num creditsUsed;
  final int allocationsCount;

  const FarmerOfferUsage({
    required this.offerId,
    required this.varietyId,
    required this.varietyName,
    required this.produceId,
    required this.produceName,
    required this.baseUnit,
    this.listingId,
    required this.quantity,
    required this.remainingQuantity,
    required this.isActive,
    required this.isPriceLocked,
    this.availableFrom,
    this.availableTo,
    required this.totalPriceLockCredit,
    required this.remainingPriceLockCredit,
    required this.creditsUsed,
    required this.allocationsCount,
  });

  factory FarmerOfferUsage.fromJson(Map<String, dynamic> json) {
    return FarmerOfferUsage(
      offerId: json['offer_id'] as String? ?? '',
      varietyId: json['variety_id'] as String? ?? '',
      varietyName: json['variety_name'] as String? ?? '',
      produceId: json['produce_id'] as String? ?? '',
      produceName: json['produce_name'] as String? ?? '',
      baseUnit: json['base_unit'] as String? ?? '',
      listingId: json['listing_id'] as String?,
      quantity: json['quantity'] as num? ?? 0,
      remainingQuantity: json['remaining_quantity'] as num? ?? 0,
      isActive: json['is_active'] as bool? ?? false,
      isPriceLocked: json['is_price_locked'] as bool? ?? false,
      availableFrom: json['available_from'] != null
          ? DateTime.parse(json['available_from']).toLocal()
          : null,
      availableTo: json['available_to'] != null
          ? DateTime.parse(json['available_to']).toLocal()
          : null,
      totalPriceLockCredit: json['total_price_lock_credit'] as num? ?? 0,
      remainingPriceLockCredit: json['remaining_price_lock_credit'] as num? ?? 0,
      creditsUsed: json['credits_used'] as num? ?? 0,
      allocationsCount: json['allocations_count'] as int? ?? 0,
    );
  }
}

class FarmerPriceLockUsageDetail {
  final String fplsId;
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime? lastResetDate;
  final String planName;
  final num monthlyCreditLimit;
  final String billingInterval;
  final num fee;
  final num remainingCredits;
  final num usedCredits;
  final List<FarmerOfferUsage> usage;

  const FarmerPriceLockUsageDetail({
    required this.fplsId,
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

  factory FarmerPriceLockUsageDetail.fromJson(Map<String, dynamic> json) {
    return FarmerPriceLockUsageDetail(
      fplsId: json['fpls_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      startsAt: json['starts_at'] != null
          ? DateTime.parse(json['starts_at']).toLocal()
          : DateTime.now(),
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at']).toLocal()
          : DateTime.now(),
      lastResetDate: json['last_reset_date'] != null
          ? DateTime.parse(json['last_reset_date']).toLocal()
          : null,
      planName: json['plan_name'] as String? ?? '',
      monthlyCreditLimit: json['monthly_credit_limit'] as num? ?? 0,
      billingInterval: json['billing_interval'] as String? ?? '',
      fee: json['fee'] as num? ?? 0,
      remainingCredits: json['remaining_credits'] as num? ?? 0,
      usedCredits: json['used_credits'] as num? ?? 0,
      usage: (json['usage'] as List<dynamic>?)
              ?.map((e) => FarmerOfferUsage.fromJson(e))
              .toList() ??
          [],
    );
  }
}
