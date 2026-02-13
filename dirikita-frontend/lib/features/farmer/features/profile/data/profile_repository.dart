import 'dart:io';

import 'package:duruha/features/farmer/features/profile/domain/profile_model.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';

class FarmerProfileRepositoryImpl implements FarmerProfileRepository {
  @override
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
      province: 'Davao del Sur',
      postalCode: '8000',
      landmark: 'Near Plaza',
      dialect: ['Cebuano'],
      // Farmer Details
      email: 'elly@example.com',
      farmAlias: 'Green Valley Farm',
      landArea: 2.5,
      accessibilityType: 'Truck',
      waterSources: ['Irrigation Canal', 'Rain Catchment'],
      paymentMethods: ['Cash', 'GCash'],
      operatingDays: ['Mon', 'Wed', 'Fri'],
      deliveryWindow: 'AM',
      pledgedCrops: List.generate(
        10,
        (i) => Produce(
          id: 'prod_${i + 1}',
          englishName: 'Crop ${i + 1}',
          scientificName: 'Scientific Name',
          category: 'Fruit Veg',
          varieties: [],
          dialects: [],
          basePrice: 0,
          baseUnit: 'kg',
        ),
      ),
      trustScore: 982,
      cropPoints: 14500,
      unlockedBadgeIds: [
        'years_silver',
        'transactions_bronze',
        'earnings_gold',
        'variety_gold',
      ],
      // imageUrl: 'https://i.pravatar.cc/300?img=12', // Uncomment to test with image
    );
  }

  @override
  Future<String> uploadProfileImage(File file) async {
    // Simulate network upload
    await Future.delayed(const Duration(seconds: 2));
    // Return a mock URL
    return 'https://i.pravatar.cc/300?img=${DateTime.now().millisecond % 70}';
  }

  @override
  Future<void> updateProfile(FarmerProfile profile) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    // In a real app, we would send the updated profile to the API
    // For now, we just simulate success
    return;
  }
}
