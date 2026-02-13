import 'dart:io';

import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/shared/user/domain/user_models.dart';

class ConsumerProfile extends UserProfile {
  ConsumerProfile({
    required super.id,
    required super.joinedAt,
    required super.name,
    super.email,
    required super.phone,
    required super.barangay,
    required super.city,
    required super.landmark,
    required super.province,
    required super.postalCode,
    super.imageUrl,
    required super.dialect,
    String? consumerSegment,
    int? segmentSize,
    String? cookingFrequency,
    List<String> qualityPreferences = const [],
    List<Produce> demandCrops = const [],
  }) : super(
         role: UserRole.consumer,
         consumerSegment: consumerSegment,
         segmentSize: segmentSize,
         cookingFrequency: cookingFrequency,
         qualityPreferences: qualityPreferences,
         demandCrops: demandCrops,
       );

  factory ConsumerProfile.fromUserProfile(UserProfile user) {
    if (user.role != UserRole.consumer) {
      throw Exception('User is not a consumer');
    }
    return ConsumerProfile(
      id: user.id,
      joinedAt: user.joinedAt,
      name: user.name,
      email: user.email,
      phone: user.phone,
      barangay: user.barangay,
      city: user.city,
      province: user.province,
      postalCode: user.postalCode,
      landmark: user.landmark,
      imageUrl: user.imageUrl,
      dialect: user.dialect,
      consumerSegment: user.consumerSegment,
      segmentSize: user.segmentSize,
      cookingFrequency: user.cookingFrequency,
      qualityPreferences: user.qualityPreferences ?? [],
      demandCrops: user.demandCrops ?? [],
    );
  }

  ConsumerProfile copyWith({
    String? id,
    String? joinedAt,
    String? name,
    String? email,
    String? phone,
    String? barangay,
    String? city,
    String? province,
    String? landmark,
    String? postalCode,
    String? imageUrl,
    List<String>? dialect,
    String? consumerSegment,
    int? segmentSize,
    String? cookingFrequency,
    List<String>? qualityPreferences,
    List<Produce>? demandCrops,
  }) {
    return ConsumerProfile(
      id: id ?? this.id,
      joinedAt: joinedAt ?? this.joinedAt,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      barangay: barangay ?? this.barangay,
      city: city ?? this.city,
      province: province ?? this.province,
      landmark: landmark ?? this.landmark,
      postalCode: postalCode ?? this.postalCode,
      imageUrl: imageUrl ?? this.imageUrl,
      dialect: dialect ?? this.dialect,
      consumerSegment: consumerSegment ?? this.consumerSegment,
      segmentSize: segmentSize ?? this.segmentSize,
      cookingFrequency: cookingFrequency ?? this.cookingFrequency,
      qualityPreferences: qualityPreferences ?? this.qualityPreferences ?? [],
      demandCrops: demandCrops ?? this.demandCrops ?? [],
    );
  }
}

abstract class ConsumerProfileRepository {
  Future<ConsumerProfile> getConsumerProfile(String consumerId);
  Future<String> uploadProfileImage(File file); // Returns the URL
  Future<void> updateProfile(ConsumerProfile profile);
}
