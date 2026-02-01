import 'package:duruha/shared/user/domain/user_models.dart';

class ConsumerProfile extends UserProfile {
  ConsumerProfile({
    required super.id,
    required super.joinedAt,
    required super.name,
    required super.phone,
    required super.barangay,
    required super.city,
    required super.province,
    required super.postalCode,
    required super.landmark,
    required super.dialect,
    required String consumerSegment,
    required int segmentSize,
    required String cookingFrequency,
    required List<String> qualityPreferences,
    List<ProduceItem> demandCrops = const [],
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
      phone: user.phone,
      barangay: user.barangay,
      city: user.city,
      province: user.province,
      postalCode: user.postalCode,
      landmark: user.landmark,
      dialect: user.dialect,
      consumerSegment: user.consumerSegment ?? '',
      segmentSize: user.segmentSize ?? 0,
      cookingFrequency: user.cookingFrequency ?? '',
      qualityPreferences: user.qualityPreferences ?? [],
      demandCrops: user.demandCrops ?? [],
    );
  }
}

abstract class ConsumerProfileRepository {
  Future<ConsumerProfile> getConsumerProfile(String consumerId);
}
