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
    required this.consumerId,
    this.consumerSegment,
    this.segmentSize,
    this.cookingFrequency,
    this.qualityPreferences = const [],
    this.consumerFavProduce = const [],
    this.isPriceLocked = false,
  }) : super(role: UserRole.consumer);
  final String consumerId;
  final String? consumerSegment;
  final int? segmentSize;
  final String? cookingFrequency;
  final List<String> qualityPreferences;
  final List<Produce> consumerFavProduce;
  final bool isPriceLocked;

  factory ConsumerProfile.fromJson(Map<String, dynamic> json) {
    final user = UserProfile.fromJson(json);
    return ConsumerProfile(
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
      consumerId: json['consumer_id'] as String? ?? '',
      consumerSegment: json['consumer_segment'] as String?,
      cookingFrequency: json['cooking_frequency'] as String?,
      isPriceLocked: json['is_price_locked'] as bool? ?? false,
      qualityPreferences: json['quality_preferences'] != null
          ? List<String>.from(json['quality_preferences'] as List)
          : [],
      consumerFavProduce: json['fav_produce'] != null
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

  factory ConsumerProfile.fromUserProfile(UserProfile user) {
    if (user is ConsumerProfile) return user;
    if (user.role != UserRole.consumer) {
      throw Exception('User is not a consumer');
    }
    return ConsumerProfile(
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
      consumerId: '', // Needs to be populated
      consumerSegment: null,
      segmentSize: null,
      cookingFrequency: null,
      qualityPreferences: [],
      consumerFavProduce: [],
      isPriceLocked: false,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'consumer_id': consumerId,
      'consumer_segment': consumerSegment,
      'cooking_frequency': cookingFrequency,
      'quality_preferences': qualityPreferences,
      'fav_produce': consumerFavProduce.map((p) => p.id).toList(),
      'is_price_locked': isPriceLocked,
    });
    return json;
  }

  ConsumerProfile copyWith({
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
    String? consumerId,
    String? consumerSegment,
    int? segmentSize,
    String? cookingFrequency,
    List<String>? qualityPreferences,
    List<Produce>? consumerFavProduce,
    String? addressId,
    String? addressLine1,
    String? addressLine2,
    bool? isPriceLocked,
  }) {
    return ConsumerProfile(
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
      consumerId: consumerId ?? this.consumerId,
      consumerSegment: consumerSegment ?? this.consumerSegment,
      segmentSize: segmentSize ?? this.segmentSize,
      cookingFrequency: cookingFrequency ?? this.cookingFrequency,
      qualityPreferences: qualityPreferences ?? this.qualityPreferences,
      consumerFavProduce: consumerFavProduce ?? this.consumerFavProduce,
      isPriceLocked: isPriceLocked ?? this.isPriceLocked,
    );
  }
}

abstract class ConsumerProfileRepository {
  Future<ConsumerProfile> getConsumerProfile(String consumerId);
  Future<String> uploadProfileImage(File file); // Returns the URL
  Future<void> updateProfile(ConsumerProfile profile);
  Future<String?> deleteAddress(String userId, String addressId);
}
