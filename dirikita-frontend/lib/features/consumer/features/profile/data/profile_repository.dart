import 'package:duruha/features/consumer/features/profile/domain/profile_model.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/shared/user/domain/user_models.dart';

class ConsumerProfileRepositoryImpl implements ConsumerProfileRepository {
  @override
  Future<ConsumerProfile> getConsumerProfile(String consumerId) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Return mock data
    return ConsumerProfile(
      id: 'consumer-001',
      name: 'Elly Consumer',
      phone: '09177654321',
      joinedAt: DateTime.now().toString(),
      barangay: 'Poblacion',
      city: 'Valencia City',
      province: 'Valencia City',
      postalCode: 'Valencia City',
      landmark: 'Behind City Hall',
      dialect: 'Cebuano',

      // Consumer Details
      consumerSegment: 'Restaurant',
      segmentSize: 50, // e.g. capacity
      cookingFrequency: 'Daily',
      qualityPreferences: ['Class A (Premium)', 'Class B (Standard)'],
      // Demand Crops
      demandCrops: (await ProduceRepository().getAllProduce())
          .take(3)
          .map((p) => p.toProduceItem())
          .toList(),
    );
  }
}

extension on Produce {
  ProduceItem toProduceItem() {
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
    );
  }
}
