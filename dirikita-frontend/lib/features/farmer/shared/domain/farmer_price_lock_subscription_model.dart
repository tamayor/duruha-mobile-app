class FarmerPriceLockSubscription {
  final String fplsId;
  final String fplId;
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final double remainingCredits;
  final String farmerId;
  final String planName;
  final double monthlyCreditLimit;
  final double fee;

  FarmerPriceLockSubscription({
    required this.fplsId,
    required this.fplId,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.remainingCredits,
    required this.farmerId,
    required this.planName,
    required this.monthlyCreditLimit,
    required this.fee,
  });

  factory FarmerPriceLockSubscription.fromJson(Map<String, dynamic> json) {
    return FarmerPriceLockSubscription(
      fplsId: json['fpls_id'],
      fplId: json['fpl_id'],
      status: json['status'],
      startsAt: DateTime.parse(json['starts_at']),
      endsAt: DateTime.parse(json['ends_at']),
      remainingCredits: (json['remaining_credits'] as num).toDouble(),
      farmerId: json['farmer_id'],
      planName:
          json['farmer_price_lock_configs']?['plan_name'] ?? 'Unknown Plan',
      monthlyCreditLimit:
          (json['farmer_price_lock_configs']?['monthly_credit_limit'] as num?)
              ?.toDouble() ??
          0.0,
      fee:
          (json['farmer_price_lock_configs']?['fee'] as num?)?.toDouble() ??
          0.0,
    );
  }
}
