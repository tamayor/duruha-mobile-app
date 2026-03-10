import 'dart:io';

import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/shared/user/domain/user_models.dart';

class FarmerProfile extends UserProfile {
  FarmerProfile({
    required super.id,
    required super.joinedAt,
    required super.name,
    super.email,
    required super.phone,
    required super.city,
    required super.landmark,
    required super.province,
    required super.postalCode,
    super.imageUrl,
    super.latitude,
    super.longitude,
    super.dialect,
    super.addressId,
    super.addressLine1,
    super.addressLine2,
    required this.farmerId,
    required this.farmerAlias,
    required this.landArea,
    required this.accessibilityType,
    required this.waterSources,
    required this.operatingDays,
    required this.deliveryWindow,
    this.farmerFavProduce = const [],
    this.trustScore = 0,
    this.cropPoints = 0,
    this.unlockedBadgeIds = const [],
  }) : super(role: UserRole.farmer);

  final String farmerId;
  final String farmerAlias;
  final double landArea;
  final String accessibilityType;
  final List<String> waterSources;
  final List<Produce> farmerFavProduce;
  final List<String> operatingDays;
  final String deliveryWindow;
  final int trustScore;
  final int cropPoints;
  final List<String> unlockedBadgeIds;

  factory FarmerProfile.fromJson(Map<String, dynamic> json) {
    final user = UserProfile.fromJson(json);
    return FarmerProfile(
      id: user.id,
      joinedAt: user.joinedAt,
      name: user.name,
      email: user.email,
      phone: user.phone,
      city: user.city,
      province: user.province,
      postalCode: user.postalCode,
      landmark: user.landmark,
      imageUrl: user.imageUrl,
      latitude: user.latitude,
      longitude: user.longitude,
      dialect: user.dialect,
      addressId: user.addressId,
      addressLine1: user.addressLine1,
      addressLine2: user.addressLine2,
      farmerId: json['farmer_id'] as String? ?? '',
      farmerAlias: json['farmer_alias'] as String? ?? '',
      landArea: json['land_area'] != null
          ? (json['land_area'] as num).toDouble()
          : 0.0,
      accessibilityType: json['accessibility_type'] as String? ?? '',
      waterSources: json['water_sources'] != null
          ? List<String>.from(json['water_sources'] as List)
          : [],
      operatingDays: json['operating_days'] != null
          ? List<String>.from(json['operating_days'] as List)
          : [],
      deliveryWindow: json['delivery_window'] as String? ?? '',
      farmerFavProduce: json['fav_produce'] != null
          ? (json['fav_produce'] as List)
                .map(
                  (id) => Produce(
                    id: id.toString(),
                    englishName: '',
                    baseUnit: 'kg',
                    category: '',
                  ),
                )
                .toList()
          : [],
    );
  }

  factory FarmerProfile.fromUserProfile(UserProfile user) {
    if (user is FarmerProfile) return user;
    if (user.role != UserRole.farmer) {
      throw Exception('User is not a farmer'); // Or handle appropriately
    }
    return FarmerProfile(
      id: user.id,
      joinedAt: user.joinedAt,
      name: user.name,
      email: user.email,
      phone: user.phone,
      city: user.city,
      province: user.province,
      postalCode: user.postalCode,
      landmark: user.landmark,
      imageUrl: user.imageUrl,
      latitude: user.latitude,
      longitude: user.longitude,

      dialect: user.dialect,
      farmerId: '', // Needs to be populated
      farmerAlias: '', // Needs to be populated from somewhere
      landArea: 0.0,
      accessibilityType: '',
      waterSources: [],
      operatingDays: [],
      deliveryWindow: '',
      farmerFavProduce: [],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'farmer_id': farmerId,
      'farmer_alias': farmerAlias,
      'land_area': landArea,
      'accessibility_type': accessibilityType,
      'water_sources': waterSources,
      'operating_days': operatingDays,
      'delivery_window': deliveryWindow,
      'fav_produce': farmerFavProduce.map((p) => p.id).toList(),
    });
    return json;
  }

  FarmerProfile copyWith({
    String? id,
    String? joinedAt,
    String? name,
    String? email,
    String? phone,
    String? city,
    String? province,
    String? landmark,
    String? postalCode,
    String? imageUrl,
    double? latitude,
    double? longitude,
    List<String>? dialect,
    String? farmerId,
    String? farmerAlias,
    double? landArea,
    String? accessibilityType,
    List<String>? waterSources,
    List<String>? operatingDays,
    String? deliveryWindow,
    List<Produce>? farmerFavProduce,
    int? trustScore,
    int? cropPoints,
    List<String>? unlockedBadgeIds,
    String? addressId,
    String? addressLine1,
    String? addressLine2,
  }) {
    return FarmerProfile(
      id: id ?? this.id,
      joinedAt: joinedAt ?? this.joinedAt,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      province: province ?? this.province,
      landmark: landmark ?? this.landmark,
      postalCode: postalCode ?? this.postalCode,
      imageUrl: imageUrl ?? this.imageUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      dialect: dialect ?? this.dialect,
      addressId: addressId ?? this.addressId,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      farmerId: farmerId ?? this.farmerId,
      farmerAlias: farmerAlias ?? this.farmerAlias,
      landArea: landArea ?? this.landArea,
      accessibilityType: accessibilityType ?? this.accessibilityType,
      waterSources: waterSources ?? this.waterSources,
      operatingDays: operatingDays ?? this.operatingDays,
      deliveryWindow: deliveryWindow ?? this.deliveryWindow,
      farmerFavProduce: farmerFavProduce ?? this.farmerFavProduce,
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
  Future<String?> deleteAddress(String userId, String addressId);
}
