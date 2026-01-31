import 'package:duruha/features/farmer/features/profile/domain/profile_model.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/shared/user/domain/user_models.dart';

class FarmerProfileRepositoryImpl {
  Future<FarmerProfile> getFarmerProfile(String farmerId) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));
    // Return mock data for now
    // In a real app, we would use farmerId to fetch specific data

    return FarmerProfile(
      id: 'farmer-001',
      name: 'Elly Farmer',
      joinedAt: DateTime.now().toString(),
      phone: '09171234567',
      barangay: 'Barangay 1',
      city: 'Malaybalay City',
      landmark: 'Near Plaza',
      dialect: 'Cebuano',
      // Farmer Details
      farmAlias: 'Green Valley Farm',
      landArea: 2.5,
      accessibilityType: 'Truck',
      waterSources: ['Irrigation Canal', 'Rain Catchment'],
      pledgedCrops: List.generate(
        10,
        (i) => ProduceItem(
          id: 'prod_${i + 1}',
          nameEnglish: 'Crop ${i + 1}',
          nameScientific: 'Scientific Name',
          category: ProduceCategory.fruitVeg,
          namesByDialect: {},
          availableVarieties: [],
          imageHeroUrl: '',
          imageThumbnailUrl: '',
          iconUrl: '',
          gradeGuideUrl: '',
          unitOfMeasure: 'kg',
          priceMinHistorical: 0,
          priceMaxHistorical: 0,
          currentFairMarketGuideline: 0,
          perishabilityIndex: 1,
          shelfLifeDays: 7,
          requiresColdChain: false,
          avgWeightPerUnitKg: 1,
          growingCycleDays: 30,
          seasonalityStart: 'Jan',
          seasonalityEnd: 'Dec',
          isNativeToRegion: true,
        ),
      ),
      trustScore: 982,
      cropPoints: 14500,
      unlockedBadgeIds: [
        'legacy_lvl_3',
        'active_lvl_2',
        'titan_lvl_4',
        'spec_lvl_4',
        'trust_lvl_3',
      ],
    );
  }
}
