import 'package:duruha/shared/user/domain/user_models.dart';

class FarmerProfile extends UserProfile {
  FarmerProfile({
    required super.id,
    required super.joinedAt,
    required super.name,
    required super.phone,
    required super.barangay,
    required super.city,
    required super.landmark,
    required super.dialect,
    required String farmAlias,
    required double landArea,
    required String accessibilityType,
    required List<String> waterSources,
    List<ProduceItem> pledgedCrops = const [],
  }) : super(
         role: UserRole.farmer,
         farmAlias: farmAlias,
         landArea: landArea,
         accessibilityType: accessibilityType,
         waterSources: waterSources,
         pledgedCrops: pledgedCrops,
       );

  factory FarmerProfile.fromUserProfile(UserProfile user) {
    if (user.role != UserRole.farmer) {
      throw Exception('User is not a farmer'); // Or handle appropriately
    }
    return FarmerProfile(
      id: user.id,
      joinedAt: user.joinedAt,
      name: user.name,
      phone: user.phone,
      barangay: user.barangay,
      city: user.city,
      landmark: user.landmark,
      dialect: user.dialect,
      farmAlias: user.farmAlias ?? '',
      landArea: user.landArea ?? 0.0,
      accessibilityType: user.accessibilityType ?? '',
      waterSources: user.waterSources ?? [],
      pledgedCrops: user.pledgedCrops ?? [],
    );
  }
}

abstract class FarmerProfileRepository {
  Future<FarmerProfile> getFarmerProfile(String farmerId);
}
