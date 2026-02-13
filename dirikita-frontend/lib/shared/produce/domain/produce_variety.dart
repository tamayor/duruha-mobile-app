class ProduceVariety {
  final String id;
  final String name;
  final String? imageUrl;
  final double multiplier;
  final double basePriceAtMapping;
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

  // Compatibility Getters
  double get calculatedPrice => basePriceAtMapping * multiplier;
  double get priceModifier => calculatedPrice - basePriceAtMapping;

  ProduceVariety({
    required this.id,
    required this.name,
    this.imageUrl,
    this.multiplier = 1.0,
    this.basePriceAtMapping = 0.0,
    this.isNative = false,
    this.breedingType,
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
  });

  factory ProduceVariety.fromJson(Map<String, dynamic> json, double basePrice) {
    return ProduceVariety(
      id: json['variety_id']?.toString() ?? '',
      name: json['variety_name']?.toString() ?? '',
      multiplier: (json['variety_multiplier'] ?? 1.0).toDouble(),
      imageUrl: json['image_url']?.toString(),
      basePriceAtMapping: basePrice,
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
    );
  }
}
