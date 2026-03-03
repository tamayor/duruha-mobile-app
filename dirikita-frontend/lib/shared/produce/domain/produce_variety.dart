import 'market_listing_model.dart';

class ProduceVariety {
  final String id;
  final String name;
  final String? imageUrl;
  final bool isNative;
  final String? breedingType;
  final int? daysToMaturityMin;
  final int? daysToMaturityMax;
  final List<String> peakMonths;
  final String? philippineSeason;
  final int? floodTolerance;
  final int? handlingFragility;
  final int shelfLifeDays;
  final double? optimalStorageTempC;
  final String? packagingRequirement;
  final String? appearanceDesc;
  final double total30DaysQuantity;
  final List<MarketListing> listings;

  // Legacy compatibility getters mapping to the first listing's prices.
  double get price =>
      listings.isNotEmpty ? listings.first.duruhaToConsumerPrice : 0.0;
  double get traderPrice =>
      listings.isNotEmpty ? listings.first.farmerToTraderPrice : 0.0;
  double get farmerPrice =>
      listings.isNotEmpty ? listings.first.farmerToDuruhaPrice : 0.0;
  double get marketPrice =>
      listings.isNotEmpty ? listings.first.marketToConsumerPrice : 0.0;

  ProduceVariety({
    required this.id,
    required this.name,
    this.imageUrl,
    this.isNative = false,
    this.breedingType,
    double price = 0.0,
    this.daysToMaturityMin,
    this.daysToMaturityMax,
    this.peakMonths = const [],
    this.philippineSeason,
    this.floodTolerance,
    this.handlingFragility,
    this.shelfLifeDays = 7,
    this.optimalStorageTempC,
    this.packagingRequirement,
    this.appearanceDesc,
    double traderPrice = 0.0,
    double farmerPrice = 0.0,
    double marketPrice = 0.0,
    this.total30DaysQuantity = 0.0,
    this.listings = const [],
  });

  factory ProduceVariety.fromJson(Map<String, dynamic> json, double basePrice) {
    return ProduceVariety(
      id: json['variety_id']?.toString() ?? '',
      name: json['variety_name']?.toString() ?? '',

      imageUrl: json['image_url']?.toString(),
      isNative: json['is_native'] == true,
      breedingType: json['breeding_type']?.toString(),
      daysToMaturityMin: json['days_to_maturity_min'] as int?,
      daysToMaturityMax: json['days_to_maturity_max'] as int?,

      peakMonths:
          (json['peak_months'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      philippineSeason: json['philippine_season']?.toString(),
      floodTolerance: json['flood_tolerance'] as int?,
      handlingFragility: json['handling_fragility'] as int?,
      shelfLifeDays: json['shelf_life_days'] as int? ?? 7,
      optimalStorageTempC: (json['optimal_storage_temp_c'] ?? 0.0).toDouble(),
      packagingRequirement: json['packaging_requirement']?.toString(),
      appearanceDesc: json['appearance_desc']?.toString(),
      total30DaysQuantity: (json['30_days_qty'] ?? 0.0).toDouble(),
      listings:
          (json['listings'] as List?)
              ?.map((l) => MarketListing.fromJson(l))
              .toList() ??
          [],
    );
  }

  ProduceVariety copyWith({
    String? id,
    String? name,
    String? imageUrl,
    bool? isNative,
    String? breedingType,
    int? daysToMaturityMin,
    int? daysToMaturityMax,
    List<String>? peakMonths,
    String? philippineSeason,
    int? floodTolerance,
    int? handlingFragility,
    int? shelfLifeDays,
    double? optimalStorageTempC,
    String? packagingRequirement,
    String? appearanceDesc,
    double? total30DaysQuantity,
    List<MarketListing>? listings,
  }) {
    return ProduceVariety(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      isNative: isNative ?? this.isNative,
      breedingType: breedingType ?? this.breedingType,
      daysToMaturityMin: daysToMaturityMin ?? this.daysToMaturityMin,
      daysToMaturityMax: daysToMaturityMax ?? this.daysToMaturityMax,
      peakMonths: peakMonths ?? this.peakMonths,
      philippineSeason: philippineSeason ?? this.philippineSeason,
      floodTolerance: floodTolerance ?? this.floodTolerance,
      handlingFragility: handlingFragility ?? this.handlingFragility,
      shelfLifeDays: shelfLifeDays ?? this.shelfLifeDays,
      optimalStorageTempC: optimalStorageTempC ?? this.optimalStorageTempC,
      packagingRequirement: packagingRequirement ?? this.packagingRequirement,
      appearanceDesc: appearanceDesc ?? this.appearanceDesc,
      total30DaysQuantity: total30DaysQuantity ?? this.total30DaysQuantity,
      listings: listings ?? this.listings,
    );
  }
}
