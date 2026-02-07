// lib/src/features/farm/domain/recommendation_model.dart

class CropRecommendation {
  final String id;
  final String nameDialect;
  final String nameEnglish;
  final int rank;
  final double demandLocal; // 0.0 - 1.0 (Percentage)
  final double demandNationwide; // 0.0 - 1.0 (Percentage)
  final double currentPledgeKg; // Current amount pledged by others
  final double targetPledgeKg; // Total amount the market needs
  final String imageUrl;
  final double priceMin;
  final double priceMax;

  CropRecommendation({
    required this.id,
    required this.nameDialect,
    required this.nameEnglish,
    required this.rank,
    required this.demandLocal,
    required this.demandNationwide,
    required this.currentPledgeKg,
    required this.targetPledgeKg,
    required this.imageUrl,
    required this.priceMin,
    required this.priceMax,
  });

  // Helper to calculate the % fulfilled for the progress bar
  double get fulfillmentRate =>
      (currentPledgeKg / targetPledgeKg).clamp(0.0, 1.0);
}
