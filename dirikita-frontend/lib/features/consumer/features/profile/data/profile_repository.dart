import 'dart:io';

import 'package:duruha/features/consumer/features/profile/domain/profile_model.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';

class ConsumerProfileRepositoryImpl implements ConsumerProfileRepository {
  @override
  Future<ConsumerProfile> getConsumerProfile(String consumerId) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));
    // Return mock data for now

    return ConsumerProfile(
      id: 'consumer-001',
      name: 'Elly Consumer',
      joinedAt: DateTime.now().toString(),
      phone: '09177654321',
      barangay: 'Barangay 5',
      city: 'Malaybalay City',
      province: 'Bukidnon',
      postalCode: '8700',
      landmark: 'Near Cathedral',
      dialect: ['Cebuano'],
      email: 'consumer@example.com',
      consumerSegment: 'Household',
      segmentSize: 4,
      cookingFrequency: 'Daily',
      qualityPreferences: ['Freshness', 'Organic'],
      demandCrops: List.generate(
        5,
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
  Future<void> updateProfile(ConsumerProfile profile) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    return;
  }
}
