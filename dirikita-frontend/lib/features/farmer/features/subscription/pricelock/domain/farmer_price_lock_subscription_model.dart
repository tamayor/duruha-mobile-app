class FarmerPriceLockSubscription {
  final String fplsId;
  final String planName;
  final String status;
  final num monthlyCreditLimit;
  final num remainingCredits;
  final num usedCredits;
  final DateTime startsAt;
  final DateTime endsAt;

  const FarmerPriceLockSubscription({
    required this.fplsId,
    required this.planName,
    required this.status,
    required this.monthlyCreditLimit,
    required this.remainingCredits,
    required this.usedCredits,
    required this.startsAt,
    required this.endsAt,
  });

  factory FarmerPriceLockSubscription.fromJson(Map<String, dynamic> json) {
    return FarmerPriceLockSubscription(
      fplsId: json['fpls_id'] as String? ?? '',
      planName: json['plan_name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      monthlyCreditLimit: json['monthly_credit_limit'] as num? ?? 0,
      remainingCredits: json['remaining_credits'] as num? ?? 0,
      usedCredits: json['used_credits'] as num? ?? 0,
      startsAt: json['starts_at'] != null
          ? DateTime.parse(json['starts_at']).toLocal()
          : DateTime.now(),
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at']).toLocal()
          : DateTime.now(),
    );
  }
}
