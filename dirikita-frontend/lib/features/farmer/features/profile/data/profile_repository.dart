import 'package:duruha/features/farmer/features/profile/domain/profile_model.dart';

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
    );
    ;
  }
}
