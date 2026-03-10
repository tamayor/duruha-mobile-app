class ConsumerPlanSubscription {
  final String cpsId;
  final String consumerId;
  final String cpcId;
  final String tier;
  final String billingInterval;
  final String planName;
  final double fee;
  final double? monthlyEquivalent;
  final double? monthlyCreditLimit;
  final double? maxOrderValue;
  final double? minOrderValue;
  final String? qualityLevel;
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime? trialEndsAt;
  final double remainingCredits;
  final int renewCount;
  final DateTime? lastRenewedAt;
  final int? scheduleWindowDays;

  ConsumerPlanSubscription({
    required this.cpsId,
    required this.consumerId,
    required this.cpcId,
    required this.tier,
    required this.billingInterval,
    required this.planName,
    required this.fee,
    this.monthlyEquivalent,
    this.monthlyCreditLimit,
    this.maxOrderValue,
    this.minOrderValue,
    this.qualityLevel,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    this.trialEndsAt,
    required this.remainingCredits,
    required this.renewCount,
    this.lastRenewedAt,
    this.scheduleWindowDays,
  });

  factory ConsumerPlanSubscription.fromJson(Map<String, dynamic> json) {
    return ConsumerPlanSubscription(
      cpsId: json['cps_id'] as String,
      consumerId: json['consumer_id'] as String? ?? '',
      cpcId: json['cpc_id'] as String,
      tier: json['tier'] as String? ?? '',
      billingInterval: json['billing_interval'] as String? ?? 'monthly',
      planName: json['plan_name'] as String? ?? '',
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
      monthlyEquivalent: (json['monthly_equivalent'] as num?)?.toDouble(),
      monthlyCreditLimit: (json['monthly_credit_limit'] as num?)?.toDouble(),
      maxOrderValue: (json['max_order_value'] as num?)?.toDouble(),
      minOrderValue: (json['min_order_value'] as num?)?.toDouble(),
      qualityLevel: json['quality_level'] as String?,
      status: json['status'] as String? ?? 'active',
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      trialEndsAt: json['trial_ends_at'] != null
          ? DateTime.parse(json['trial_ends_at'] as String)
          : null,
      remainingCredits: (json['remaining_credits'] as num?)?.toDouble() ?? 0.0,
      renewCount: (json['renew_count'] as num?)?.toInt() ?? 0,
      lastRenewedAt: json['last_renewed_at'] != null
          ? DateTime.parse(json['last_renewed_at'] as String)
          : null,
      scheduleWindowDays: (json['schedule_window_days'] as num?)?.toInt(),
    );
  }

  bool get isActive =>
      status.toLowerCase() == 'active' &&
      endsAt.toUtc().isAfter(DateTime.now().toUtc());

  bool get hasCreditLimit =>
      monthlyCreditLimit != null && monthlyCreditLimit! > 0;

  bool get hasOrderValueLimits =>
      (maxOrderValue != null && maxOrderValue! > 0) ||
      (minOrderValue != null && minOrderValue! > 0);
}
