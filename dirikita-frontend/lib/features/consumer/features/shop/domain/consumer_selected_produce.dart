class ConsumerSelectedProduce {
  final String id;
  final String nameEnglish;
  final String nameDialect;
  final String? imageUrl;
  final double total30DaysOffer;
  final String category;
  final String baseUnit;
  final String? scientificName;
  final double minPrice;
  final double maxPrice;
  final int varietyCountWithOffers;
  final int totalVarietyCount;

  ConsumerSelectedProduce({
    required this.id,
    required this.nameEnglish,
    required this.nameDialect,
    this.imageUrl,
    this.total30DaysOffer = 0.0,
    this.category = '',
    this.baseUnit = '',
    this.scientificName,
    this.minPrice = 0.0,
    this.maxPrice = 0.0,
    this.varietyCountWithOffers = 0,
    this.totalVarietyCount = 0,
  });

  factory ConsumerSelectedProduce.fromJson(Map<String, dynamic> json) {
    return ConsumerSelectedProduce(
      id: json['id']?.toString() ?? '',
      nameEnglish:
          (json['english_name'] ?? json['nameEnglish'])?.toString() ?? '',
      nameDialect:
          (json['dialect_name'] ?? json['local_name'] ?? json['nameDialect'])
              ?.toString() ??
          '',
      imageUrl:
          (json['image_url'] ?? json['imageUrl'] ?? json['produce_img_url'])
              ?.toString(),
      // get_user_produce consumer mode field names
      total30DaysOffer: (json['30d_offer_qty'] ?? 0).toDouble(),
      varietyCountWithOffers:
          (json['variety_count_available'] ??
                  json['variety_count_with_offers'] ??
                  0)
              as int,
      totalVarietyCount:
          (json['variety_count'] ?? json['total_variety_count'] ?? 0) as int,
      category: json['category']?.toString() ?? '',
      baseUnit: json['base_unit']?.toString() ?? '',
      scientificName: json['scientific_name']?.toString(),
      // prices not returned by get_user_produce — kept for API compatibility
      minPrice: (json['min_price'] ?? 0.0).toDouble(),
      maxPrice: (json['max_price'] ?? 0.0).toDouble(),
    );
  }
}
