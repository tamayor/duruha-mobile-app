import 'package:duruha/models/user_models.dart';
import 'package:duruha/data/produce_data.dart';
// import 'package:duruha/models/produce_model.dart'; // No longer needed if we map manually or if produce_data exports it.

class MockData {
  // --- BASE PRODUCE LIST ---
  // Mapping the rich mockProduceList from produce_data.dart to our simpler ProduceItem model
  static final List<ProduceItem> allProduce = mockProduceList
      .map(
        (p) => ProduceItem(
          id: p.id,
          nameEnglish: p.nameEnglish,
          nameScientific: p.nameScientific,
          category: p.category,
          namesByDialect: p.namesByDialect,
          availableVarieties: p.availableVarieties,
          imageHeroUrl: p.imageHeroUrl,
          imageThumbnailUrl: p.imageThumbnailUrl,
          iconUrl: p.iconUrl,
          gradeGuideUrl: p.gradeGuideUrl,
          unitOfMeasure: p.unitOfMeasure,
          priceMinHistorical: p.priceMinHistorical,
          priceMaxHistorical: p.priceMaxHistorical,
          currentFairMarketGuideline: p.currentFairMarketGuideline,
          perishabilityIndex: p.perishabilityIndex,
          shelfLifeDays: p.shelfLifeDays,
          requiresColdChain: p.requiresColdChain,
          avgWeightPerUnitKg: p.avgWeightPerUnitKg,
          growingCycleDays: p.growingCycleDays,
          seasonalityStart: p.seasonalityStart,
          seasonalityEnd: p.seasonalityEnd,
          isNativeToRegion: p.isNativeToRegion,
        ),
      )
      .toList();

  // --- MOCK FARMER PROFILE ---
  static final UserProfile mockFarmer = UserProfile(
    id: 'farmer-001',
    name: 'Elly Farmer',
    joinedAt: DateTime.now().toString(),
    phone: '09171234567',
    barangay: 'Barangay 1',
    city: 'Malaybalay City',
    landmark: 'Near Plaza',
    dialect: 'Cebuano',
    role: UserRole.farmer,

    // Farmer Details
    farmAlias: 'Green Valley Farm',
    landArea: 2.5,
    accessibilityType: 'Truck',
    waterSources: ['Irrigation Canal', 'Rain Catchment'],

    // Pledged Crops
    pledgedCrops: [
      allProduce[0].copyWith(
        // Item 1
        pledgedAmount: 500.0,
        harvestDate: DateTime.now().add(const Duration(days: 30)),
        selectedVariety: 'Upland',
      ),
      allProduce[1].copyWith(
        // Item 2
        pledgedAmount: 300.0,
        harvestDate: DateTime.now().add(const Duration(days: 15)),
        selectedVariety: 'Taiwan',
      ),
      allProduce[4].copyWith(
        // Item 5
        pledgedAmount: 1000.0,
        harvestDate: DateTime.now().add(const Duration(days: 60)),
        selectedVariety: 'Native Labuyo',
      ),
    ],
  );

  // --- MOCK CONSUMER PROFILE ---
  static final UserProfile mockConsumer = UserProfile(
    id: 'consumer-001',
    name: 'Elly Consumer',
    phone: '09177654321',
    joinedAt: DateTime.now().toString(),
    barangay: 'Poblacion',
    city: 'Valencia City',
    landmark: 'Behind City Hall',
    role: UserRole.consumer,
    dialect: 'Cebuano',

    // Consumer Details
    consumerSegment: 'Restaurant',
    segmentSize: 50, // e.g. capacity
    cookingFrequency: 'Daily',
    qualityPreferences: ['Class A (Premium)', 'Class B (Standard)'],

    // Demand Crops
    demandCrops: [
      allProduce[0].copyWith(
        // Item 1 requirement
        demandAmount: 50.0,
        preferredQuality: 'Class A (Premium)',
      ),
      allProduce[2].copyWith(
        // Item 3 requirement
        demandAmount: 100.0,
        preferredQuality: 'Class A (Premium)',
      ),
      allProduce[3].copyWith(
        // Item 4 requirement
        demandAmount: 30.0,
        preferredQuality: 'Class B (Standard)',
      ),
    ],
  );
}
