import 'package:duruha/features/consumer/features/profile/domain/profile_model.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';

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
      landmark: 'Behind City Hall',
      dialect: 'Cebuano',

      // Consumer Details
      consumerSegment: 'Restaurant',
      segmentSize: 50, // e.g. capacity
      cookingFrequency: 'Daily',
      qualityPreferences: ['Class A (Premium)', 'Class B (Standard)'],
    );
  }
}
