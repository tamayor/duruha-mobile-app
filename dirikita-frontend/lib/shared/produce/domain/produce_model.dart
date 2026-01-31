import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/user/domain/user_models.dart';

class Produce {
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

  Produce({
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
