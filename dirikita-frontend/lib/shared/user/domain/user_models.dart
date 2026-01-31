import 'package:duruha/shared/produce/domain/produce_model.dart';

enum UserRole { farmer, consumer }

class UserProfile {
  final String id;
  final String joinedAt;
  final String name;
  final String phone;
  final String barangay;
  final String city;
  final String landmark;
  final UserRole role;
  final String dialect;
  // Farmer Specific
  final String? farmAlias;
  final double? landArea;
  final String? accessibilityType;
  final List<String>? waterSources;
  final List<ProduceItem>? pledgedCrops;

  // Consumer Specific
  final String? consumerSegment; // Household, Restaurant, etc.
  final int? segmentSize;
  final String? cookingFrequency;
  final List<String>? qualityPreferences;
  final List<ProduceItem>? demandCrops;

  UserProfile({
    required this.id,
    required this.joinedAt,
    required this.name,
    required this.phone,
    required this.barangay,
    required this.city,
    required this.landmark,
    required this.role,
    required this.dialect,
    this.farmAlias,
    this.landArea,
    this.accessibilityType,
    this.waterSources,
    this.pledgedCrops,
    this.consumerSegment,
    this.segmentSize,
    this.cookingFrequency,
    this.qualityPreferences,
    this.demandCrops,
  });

  bool get isFarmer => role == UserRole.farmer;
}

class ProduceItem {
  // 1. Core Identity
  final String id;
  final String nameEnglish;
  final String nameScientific;
  final ProduceCategory category;
  final Map<String, String> namesByDialect;

  // 2. The Varieties
  final List<String> availableVarieties;

  // 3. Visual Metadata
  final String imageHeroUrl;
  final String imageThumbnailUrl;
  final String iconUrl;
  final String gradeGuideUrl;

  // 4. Pricing & Economics
  final String unitOfMeasure;
  final double priceMinHistorical;
  final double priceMaxHistorical;
  final double currentFairMarketGuideline;

  // 5. Logistics Data
  final int perishabilityIndex; // 1-5
  final int shelfLifeDays;
  final bool requiresColdChain;
  final double avgWeightPerUnitKg;

  // 6. Agricultural Metadata
  final int growingCycleDays;
  final String seasonalityStart;
  final String seasonalityEnd;
  final bool isNativeToRegion;

  // 7. User Context (Transactional)
  final DateTime? harvestDate;
  final double? pledgedAmount;
  final double? demandAmount;
  final String? preferredQuality;
  final String? selectedVariety;

  const ProduceItem({
    required this.id,
    required this.nameEnglish,
    required this.nameScientific,
    required this.category,
    required this.namesByDialect,
    required this.availableVarieties,
    required this.imageHeroUrl,
    required this.imageThumbnailUrl,
    required this.iconUrl,
    required this.gradeGuideUrl,
    required this.unitOfMeasure,
    required this.priceMinHistorical,
    required this.priceMaxHistorical,
    required this.currentFairMarketGuideline,
    required this.perishabilityIndex,
    required this.shelfLifeDays,
    required this.requiresColdChain,
    required this.avgWeightPerUnitKg,
    required this.growingCycleDays,
    required this.seasonalityStart,
    required this.seasonalityEnd,
    required this.isNativeToRegion,
    this.harvestDate,
    this.pledgedAmount,
    this.demandAmount,
    this.preferredQuality,
    this.selectedVariety,
  });

  // Helper to clone with modifications
  ProduceItem copyWith({
    DateTime? harvestDate,
    double? pledgedAmount,
    double? demandAmount,
    String? preferredQuality,
    String? selectedVariety,
  }) {
    return ProduceItem(
      id: id,
      nameEnglish: nameEnglish,
      nameScientific: nameScientific,
      category: category,
      namesByDialect: namesByDialect,
      availableVarieties: availableVarieties,
      imageHeroUrl: imageHeroUrl,
      imageThumbnailUrl: imageThumbnailUrl,
      iconUrl: iconUrl,
      gradeGuideUrl: gradeGuideUrl,
      unitOfMeasure: unitOfMeasure,
      priceMinHistorical: priceMinHistorical,
      priceMaxHistorical: priceMaxHistorical,
      currentFairMarketGuideline: currentFairMarketGuideline,
      perishabilityIndex: perishabilityIndex,
      shelfLifeDays: shelfLifeDays,
      requiresColdChain: requiresColdChain,
      avgWeightPerUnitKg: avgWeightPerUnitKg,
      growingCycleDays: growingCycleDays,
      seasonalityStart: seasonalityStart,
      seasonalityEnd: seasonalityEnd,
      isNativeToRegion: isNativeToRegion,
      harvestDate: harvestDate ?? this.harvestDate,
      pledgedAmount: pledgedAmount ?? this.pledgedAmount,
      demandAmount: demandAmount ?? this.demandAmount,
      preferredQuality: preferredQuality ?? this.preferredQuality,
      selectedVariety: selectedVariety ?? this.selectedVariety,
    );
  }
}
