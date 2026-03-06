class QualitySubscription {
  final String cqsId;
  final String cqId;
  final String tierName;
  final double monthlyFee;
  final String? description;
  final String status;
  final DateTime startsAt;
  final DateTime? endsAt;

  QualitySubscription({
    required this.cqsId,
    required this.cqId,
    required this.tierName,
    required this.monthlyFee,
    this.description,
    required this.status,
    required this.startsAt,
    this.endsAt,
  });

  factory QualitySubscription.fromJson(Map<String, dynamic> json) {
    return QualitySubscription(
      cqsId: json['cqs_id'] as String,
      cqId: json['cq_id'] as String,
      tierName: json['tier_name'] as String,
      monthlyFee: (json['monthly_fee'] as num).toDouble(),
      description: json['description'] as String?,
      status: json['status'] as String,
      startsAt: DateTime.parse(json['starts_at']),
      endsAt: json['ends_at'] != null ? DateTime.parse(json['ends_at']) : null,
    );
  }
}
