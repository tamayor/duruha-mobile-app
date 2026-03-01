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
    super.latitude,
    super.longitude,
    super.dialect,
    required this.consumerId,
    this.consumerSegment,
    this.segmentSize,
    this.cookingFrequency,
    this.qualityPreferences = const [],
    this.consumerFavProduce = const [],
  }) : super(role: UserRole.consumer);
  final String consumerId;
  final String? consumerSegment;
  final int? segmentSize;
  final String? cookingFrequency;
  final List<String> qualityPreferences;
  final List<Produce> consumerFavProduce;

  factory ConsumerProfile.fromJson(Map<String, dynamic> json) {
    final user = UserProfile.fromJson(json);
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
      latitude: user.latitude,
      longitude: user.longitude,
      dialect: user.dialect,
      consumerId: json['consumer_id'] as String? ?? '',
      consumerSegment: json['consumer_segment'] as String?,
      cookingFrequency: json['cooking_frequency'] as String?,
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
      barangay: user.barangay,
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
    });
    return json;
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
    double? latitude,
    double? longitude,
    List<String>? dialect,
    String? consumerId,
    String? consumerSegment,
    int? segmentSize,
    String? cookingFrequency,
    List<String>? qualityPreferences,
    List<Produce>? consumerFavProduce,
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
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      dialect: dialect ?? this.dialect,
      consumerId: consumerId ?? this.consumerId,
      consumerSegment: consumerSegment ?? this.consumerSegment,
      segmentSize: segmentSize ?? this.segmentSize,
      cookingFrequency: cookingFrequency ?? this.cookingFrequency,
      qualityPreferences: qualityPreferences ?? this.qualityPreferences,
      consumerFavProduce: consumerFavProduce ?? this.consumerFavProduce,
    );
  }
}

abstract class ConsumerProfileRepository {
  Future<ConsumerProfile> getConsumerProfile(String consumerId);
  Future<String> uploadProfileImage(File file); // Returns the URL
  Future<void> updateProfile(ConsumerProfile profile);
}
