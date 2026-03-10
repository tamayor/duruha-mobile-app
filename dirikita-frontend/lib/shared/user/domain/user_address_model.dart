class UserAddress {
  final String addressId;
  final String? userId;
  final DateTime createdAt;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? province;
  final String? landmark;
  final String? region;
  final String? postalCode;
  final String? country;
  final double? latitude;
  final double? longitude;

  UserAddress({
    required this.addressId,
    this.userId,
    required this.createdAt,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.province,
    this.landmark,
    this.region,
    this.postalCode,
    this.country,
    this.latitude,
    this.longitude,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    double? lat;
    double? lng;

    if (json['location'] != null && json['location'] is Map) {
      final coords = json['location']['coordinates'];
      if (coords != null && coords is List && coords.length >= 2) {
        lng = (coords[0] as num?)?.toDouble();
        lat = (coords[1] as num?)?.toDouble();
      }
    }

    return UserAddress(
      addressId: json['address_id'] as String,
      userId: json['user_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      addressLine1: json['address_line_1'] as String?,
      addressLine2: json['address_line_2'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      landmark: json['landmark'] as String?,
      region: json['region'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String?,
      latitude: lat,
      longitude: lng,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address_id': addressId,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'address_line_1': addressLine1,
      'address_line_2': addressLine2,
      'city': city,
      'province': province,
      'landmark': landmark,
      'region': region,
      'postal_code': postalCode,
      'country': country,
      'location': latitude != null && longitude != null
          ? 'POINT($longitude $latitude)'
          : null,
    };
  }

  String get fullAddress {
    final parts = [
      addressLine1,
      addressLine2,
      city,
      province,
      postalCode,
    ].where((p) => p != null && p.isNotEmpty).toList();
    return parts.join(', ');
  }

  UserAddress copyWith({
    String? addressId,
    String? userId,
    DateTime? createdAt,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? province,
    String? landmark,
    String? region,
    String? postalCode,
    String? country,
    double? latitude,
    double? longitude,
  }) {
    return UserAddress(
      addressId: addressId ?? this.addressId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      province: province ?? this.province,
      landmark: landmark ?? this.landmark,
      region: region ?? this.region,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
