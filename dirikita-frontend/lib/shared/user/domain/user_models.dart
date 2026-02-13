import 'package:duruha/shared/produce/domain/produce_model.dart';

enum UserRole { farmer, consumer }

class UserProfile {
  final String id;
  final String joinedAt;
  final String name;
  final String? email;
  final String phone;
  final String barangay;
  final String city;
  final String province;
  final String landmark;
  final String postalCode;
  final String? imageUrl;
  final UserRole role;
  final List<String> dialect;
  // Farmer Specific
  final String? farmAlias;
  final double? landArea;
  final String? accessibilityType;
  final List<String>? waterSources;
  final List<Produce>? pledgedCrops;
  final List<String>? paymentMethods;
  final List<String>? operatingDays;
  final String? deliveryWindow;

  // Consumer Specific
  final String? consumerSegment; // Household, Restaurant, etc.
  final int? segmentSize;
  final String? cookingFrequency;
  final List<String>? qualityPreferences;
  final List<Produce>? demandCrops;

  UserProfile({
    required this.id,
    required this.joinedAt,
    required this.name,
    this.email,
    required this.phone,
    required this.barangay,
    required this.city,
    required this.province,
    required this.landmark,
    required this.postalCode,
    this.imageUrl,
    required this.role,
    required this.dialect,
    this.farmAlias,
    this.landArea,
    this.accessibilityType,
    this.waterSources,
    this.pledgedCrops,
    this.paymentMethods,
    this.operatingDays,
    this.deliveryWindow,
    this.consumerSegment,
    this.segmentSize,
    this.cookingFrequency,
    this.qualityPreferences,
    this.demandCrops,
  });

  bool get isFarmer => role == UserRole.farmer;
}
