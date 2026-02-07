class ProduceVariety {
  final String id;
  final String name;
  final bool isLocallyGrown;
  final List<String> sourcingProvinces;
  final String pricingModel;
  final double priceModifier;

  ProduceVariety({
    required this.id,
    required this.name,
    required this.isLocallyGrown,
    required this.sourcingProvinces,
    required this.pricingModel,
    required this.priceModifier,
  });
}

class Produce {
  // 1. Core Identity
  final String id;
  final String nameEnglish;
  final String nameScientific;
  final ProduceCategory category;
  final Map<String, String> namesByDialect;
  final List<String> tags;

  // 2. The Varieties
  final List<ProduceVariety> availableVarieties;

  // 3. Visual Metadata
  final String imageHeroUrl;
  final String imageThumbnailUrl;
  final String iconUrl;
  final String gradeGuideUrl;

  // 4. Pricing & Economics
  final String unitOfMeasure;
  final PricingEconomics pricingEconomics;

  // 5. Logistics Data
  final int perishabilityIndex; // 1-5
  final int shelfLifeDays;
  final bool requiresColdChain;
  final String standardPackType;

  // 6. Agricultural Metadata
  final int growingCycleDays;
  final Seasonality seasonality;
  final double yieldPerSqm;

  // 7. Quality Standards
  final Map<String, String> gradingStandards;
  final Map<String, double> gradeMultiplier;

  // 8. Backward Compatibility & Helpers
  final double priceMinHistorical;
  final double priceMaxHistorical;
  double get currentFairMarketGuideline => pricingEconomics.duruhaConsumerPrice;
  String get seasonalityStart =>
      seasonality.peakMonths.isNotEmpty ? seasonality.peakMonths.first : 'N/A';
  String get seasonalityEnd =>
      seasonality.peakMonths.isNotEmpty ? seasonality.peakMonths.last : 'N/A';

  Produce({
    required this.id,
    required this.nameEnglish,
    required this.nameScientific,
    required this.category,
    required this.namesByDialect,
    this.tags = const [],
    required this.availableVarieties,
    required this.imageHeroUrl,
    required this.imageThumbnailUrl,
    required this.iconUrl,
    required this.gradeGuideUrl,
    required this.unitOfMeasure,
    required this.pricingEconomics,
    required this.perishabilityIndex,
    required this.shelfLifeDays,
    required this.requiresColdChain,
    required this.standardPackType,
    required this.growingCycleDays,
    required this.seasonality,
    required this.yieldPerSqm,
    this.gradingStandards = const {},
    this.gradeMultiplier = const {},
    this.priceMinHistorical = 0,
    this.priceMaxHistorical = 0,
  });
}

class PricingEconomics {
  final double duruhaConsumerPrice;
  final double duruhaFarmerPayout;
  final double marketBenchmarkRetail;
  final double marketBenchmarkFarmgate;
  final String priceTrendSignal;

  PricingEconomics({
    required this.duruhaConsumerPrice,
    required this.duruhaFarmerPayout,
    required this.marketBenchmarkRetail,
    required this.marketBenchmarkFarmgate,
    required this.priceTrendSignal,
  });

  double get farmerSharePercentage =>
      (duruhaFarmerPayout / duruhaConsumerPrice) * 100;
}

class Seasonality {
  final List<String> peakMonths;
  final List<String> leanMonths;
  final List<String> offSeason;

  Seasonality({
    required this.peakMonths,
    required this.leanMonths,
    required this.offSeason,
  });
}

enum ProduceCategory {
  leafy,
  fruitVeg, // Fruit Veg (e.g., Eggplant, Tomato)
  root,
  spice,
  fruit,
  legume,
}
