import 'dart:io';

import 'package:duruha/shared/user/domain/user_models.dart';

class FarmerProfile extends UserProfile {
  FarmerProfile({
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
    required String farmAlias,
    required double landArea,
    required String accessibilityType,
    required List<String> waterSources,
    required List<String> paymentMethods,
    required List<String> operatingDays,
    required String deliveryWindow,
    List<ProduceItem> pledgedCrops = const [],
    this.trustScore = 0,
    this.cropPoints = 0,
    this.unlockedBadgeIds = const [],
  }) : super(
         role: UserRole.farmer,
         farmAlias: farmAlias,
         landArea: landArea,
         accessibilityType: accessibilityType,
         waterSources: waterSources,
         paymentMethods: paymentMethods,
         operatingDays: operatingDays,
         deliveryWindow: deliveryWindow,
         pledgedCrops: pledgedCrops,
       );

  final int trustScore;
  final int cropPoints;
  final List<String> unlockedBadgeIds;

  factory FarmerProfile.fromUserProfile(UserProfile user) {
    if (user.role != UserRole.farmer) {
      throw Exception('User is not a farmer'); // Or handle appropriately
    }
    return FarmerProfile(
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
      farmAlias: user.farmAlias ?? '',
      landArea: user.landArea ?? 0.0,
      accessibilityType: user.accessibilityType ?? '',
      waterSources: user.waterSources ?? [],
      paymentMethods: user.paymentMethods ?? [],
      operatingDays: user.operatingDays ?? [],
      deliveryWindow: user.deliveryWindow ?? '',
      pledgedCrops: user.pledgedCrops ?? [],
    );
  }

  FarmerProfile copyWith({
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
    String? dialect,
    String? farmAlias,
    double? landArea,
    String? accessibilityType,
    List<String>? waterSources,
    List<String>? paymentMethods,
    List<String>? operatingDays,
    String? deliveryWindow,
    List<ProduceItem>? pledgedCrops,
    int? trustScore,
    int? cropPoints,
    List<String>? unlockedBadgeIds,
  }) {
    return FarmerProfile(
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
      farmAlias: farmAlias ?? this.farmAlias ?? '',
      landArea: landArea ?? this.landArea ?? 0.0,
      accessibilityType: accessibilityType ?? this.accessibilityType ?? '',
      waterSources: waterSources ?? this.waterSources ?? [],
      paymentMethods: paymentMethods ?? this.paymentMethods ?? [],
      operatingDays: operatingDays ?? this.operatingDays ?? [],
      deliveryWindow: deliveryWindow ?? this.deliveryWindow ?? '',
      pledgedCrops: pledgedCrops ?? this.pledgedCrops ?? [],
      trustScore: trustScore ?? this.trustScore,
      cropPoints: cropPoints ?? this.cropPoints,
      unlockedBadgeIds: unlockedBadgeIds ?? this.unlockedBadgeIds,
    );
  }
}

abstract class FarmerProfileRepository {
  Future<FarmerProfile> getFarmerProfile(String farmerId);
  Future<String> uploadProfileImage(File file); // Returns the URL
  Future<void> updateProfile(FarmerProfile profile);
}
