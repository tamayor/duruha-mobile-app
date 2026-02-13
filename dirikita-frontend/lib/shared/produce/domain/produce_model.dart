import 'produce_variety.dart';
import 'produce_dialect.dart';

class ProducePricingEconomics {
  final double duruhaConsumerPrice;
  final double duruhaFarmerPayout;
  final double marketBenchmarkRetail;
  final double marketBenchmarkFarmgate;
  final String priceTrendSignal;

  ProducePricingEconomics({
    required this.duruhaConsumerPrice,
    required this.duruhaFarmerPayout,
    required this.marketBenchmarkRetail,
    required this.marketBenchmarkFarmgate,
    this.priceTrendSignal = 'Stable',
  });
}

// Alias for legacy code
typedef PricingEconomics = ProducePricingEconomics;

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

class Produce {
  final String id;
  final String englishName;
  final String? scientificName;
  final DateTime? createdAt;
  final String baseUnit;
  final String? imageUrl;
  final String category;
  final DateTime? updatedAt;
  final String? crossContaminationRisk;
  final int crushWeightTolerance;
  final String respirationRate;
  final String storageGroup;
  final bool isEthyleneProducer;
  final bool isEthyleneSensitive;
  final double basePrice;
  final List<ProduceVariety> varieties;
  final List<ProduceDialect> dialects;

  // Compatibility Getters
  String get nameEnglish => englishName;
  String? get nameScientific => scientificName;
  String get unitOfMeasure => baseUnit;
  List<ProduceVariety> get availableVarieties => varieties;
  double get currentFairMarketGuideline => basePrice;

  // Legacy aliases for recommendations (mostly mocks, but used in UI)
  double get priceMinHistorical => basePrice * 0.9;
  double get priceMaxHistorical => basePrice * 1.1;
  int get growingCycleDays => 90;
  String get seasonalityStart => 'Dec';
  String get seasonalityEnd => 'Feb';
  int get shelfLifeDays => 7;
  int get perishabilityIndex => 3;

  String get imageHeroUrl {
    if (imageUrl != null && imageUrl!.isNotEmpty) return imageUrl!;
    return varieties.isNotEmpty ? (varieties.first.imageUrl ?? '') : '';
  }

  String get imageThumbnailUrl => imageHeroUrl;

  Map<String, String> get namesByDialect {
    return {for (var d in dialects) d.dialectName.toLowerCase(): d.localName};
  }

  ProducePricingEconomics get pricingEconomics => ProducePricingEconomics(
    duruhaConsumerPrice: basePrice,
    duruhaFarmerPayout: basePrice * 0.7,
    marketBenchmarkRetail: basePrice * 1.25,
    marketBenchmarkFarmgate: basePrice * 0.45,
  );

  Produce({
    required this.id,
    required this.englishName,
    this.scientificName,
    this.createdAt,
    required this.baseUnit,
    this.imageUrl,
    required this.category,
    this.updatedAt,
    this.crossContaminationRisk,
    this.crushWeightTolerance = 5,
    this.respirationRate = 'Low',
    this.storageGroup = 'Ambient',
    this.isEthyleneProducer = false,
    this.isEthyleneSensitive = false,
    required this.basePrice,
    this.varieties = const [],
    this.dialects = const [],
  });

  factory Produce.fromJson(Map<String, dynamic> json) {
    final double bPrice = (json['base_price'] ?? 0.0).toDouble();
    return Produce(
      id: json['id']?.toString() ?? '',
      englishName: json['english_name']?.toString() ?? '',
      scientificName: json['scientific_name']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      baseUnit: json['base_unit']?.toString() ?? 'kg',
      imageUrl: json['image_url']?.toString(),
      category: json['category']?.toString() ?? 'Uncategorized',
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      crossContaminationRisk: json['cross_contamination_risk']?.toString(),
      crushWeightTolerance: (json['crush_weight_tolerance'] ?? 5) is int
          ? json['crush_weight_tolerance']
          : int.tryParse(json['crush_weight_tolerance'].toString()) ?? 5,
      respirationRate: json['respiration_rate']?.toString() ?? 'Low',
      storageGroup: json['storage_group']?.toString() ?? 'Ambient',
      isEthyleneProducer: json['is_ethylene_producer'] == true,
      isEthyleneSensitive: json['is_ethylene_sensitive'] == true,
      basePrice: bPrice,
      varieties: (json['varieties'] as List? ?? [])
          .map((v) => ProduceVariety.fromJson(v, bPrice))
          .toList(),
      dialects: (json['dialects'] as List? ?? [])
          .map((d) => ProduceDialect.fromJson(d))
          .toList(),
    );
  }

  /// Helper to find a name in a specific dialect
  String getLocalName(String targetDialect) {
    return dialects
        .firstWhere(
          (d) => d.dialectName.toLowerCase() == targetDialect.toLowerCase(),
          orElse: () => ProduceDialect(dialectName: '', localName: englishName),
        )
        .localName;
  }
}
