enum UserRole { farmer, consumer, admin }

class UserProfile {
  final String id;
  final String joinedAt;
  final String name;
  final String? email;
  final String? phone;
  final String? addressId;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? province;
  final String? landmark;
  final String? postalCode;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final UserRole? role;
  final List<String> dialect;

  UserProfile({
    required this.id,
    required this.joinedAt,
    required this.name,
    this.email,
    this.phone,
    this.addressId,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.province,
    this.landmark,
    this.postalCode,
    this.imageUrl,
    this.latitude,
    this.longitude,
    this.role,
    this.dialect = const [],
  });

  bool get isFarmer => role == UserRole.farmer;
  bool get isConsumer => role == UserRole.consumer;
  bool get isAdmin => role == UserRole.admin;

  // Convert UserProfile to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'joined_at': joinedAt,
      'name': name,
      'email': email,
      'phone': phone,
      'address_id': addressId,
      'address_line_1': addressLine1,
      'address_line_2': addressLine2,
      'city': city,
      'province': province,
      'landmark': landmark,
      'postal_code': postalCode,
      'image_url': imageUrl,
      'location': latitude != null && longitude != null
          ? 'POINT($longitude $latitude)'
          : null,
      'role': role == UserRole.farmer
          ? 'FARMER'
          : (role == UserRole.admin ? 'ADMIN' : 'CONSUMER'),
      'dialect': dialect,
    };
  }

  // Create UserProfile from Supabase JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // GPS: the manage_profile RPC returns flat 'latitude'/'longitude' keys.
    // Legacy direct-table queries return a PostGIS 'location' object.
    double? lat;
    double? lng;

    if (json['latitude'] != null) {
      lat = (json['latitude'] as num?)?.toDouble();
      lng = (json['longitude'] as num?)?.toDouble();
    } else if (json['location'] != null && json['location'] is Map) {
      final coords = json['location']['coordinates'];
      lat = (coords?[1] as num?)?.toDouble();
      lng = (coords?[0] as num?)?.toDouble();
    }

    return UserProfile(
      id: json['id'] as String,
      joinedAt:
          json['joined_at'] as String? ?? DateTime.now().toIso8601String(),
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String? ?? '',
      addressId: json['address_id'] as String?,
      addressLine1: json['address_line_1'] as String?,
      addressLine2: json['address_line_2'] as String?,
      city: json['city'] as String? ?? '',
      province: json['province'] as String? ?? '',
      landmark: json['landmark'] as String? ?? '',
      postalCode: json['postal_code'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      latitude: lat,
      longitude: lng,
      role: json['role']?.toString().toUpperCase() == 'FARMER'
          ? UserRole.farmer
          : (json['role']?.toString().toUpperCase() == 'ADMIN'
                ? UserRole.admin
                : UserRole.consumer),
      dialect: json['dialect'] != null
          ? List<String>.from(json['dialect'] as List)
          : ['Cebuano'],
    );
  }
}
