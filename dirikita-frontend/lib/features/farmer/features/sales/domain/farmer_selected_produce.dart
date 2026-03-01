class FarmerSelectedProduce {
  final String id;
  final String nameEnglish;
  final String nameDialect;
  final String? imageUrl;
  final String? pledgeCountLabel;
  final int? rank;
  final double total30DaysDemand;
  final int varietyCount;

  FarmerSelectedProduce({
    required this.id,
    required this.nameEnglish,
    required this.nameDialect,
    this.imageUrl,
    this.pledgeCountLabel,
    this.rank,
    this.total30DaysDemand = 0.0,
    this.varietyCount = 0,
  });

  factory FarmerSelectedProduce.fromJson(Map<String, dynamic> json) {
    return FarmerSelectedProduce(
      id: json['id']?.toString() ?? '',
      nameEnglish: json['english_name']?.toString() ?? '',
      nameDialect: json['local_name']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      pledgeCountLabel: json['pledge_count_label']?.toString(),
      rank: json['rank'] is int
          ? json['rank'] as int?
          : int.tryParse(json['rank']?.toString() ?? ''),
      total30DaysDemand: (json['total_30_days_demand'] ?? 0.0).toDouble(),
      varietyCount: json['variety_count'] as int? ?? 0,
    );
  }
}
