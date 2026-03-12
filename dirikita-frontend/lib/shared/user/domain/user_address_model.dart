import 'dart:typed_data';

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

    if (json['location'] != null) {
      if (json['location'] is Map) {
        final coords = json['location']['coordinates'];
        if (coords != null && coords is List && coords.length >= 2) {
          lng = (coords[0] as num?)?.toDouble();
          lat = (coords[1] as num?)?.toDouble();
        }
      } else if (json['location'] is String) {
        final locStr = json['location'] as String;
        // PostGIS geography WKB hex: little-endian, starts with '01'
        // With SRID: 0101000020E6100000... (10 char prefix before coords)
        // Without SRID: 0101000000... (9 char prefix before coords = 18 hex chars)
        if (locStr.startsWith('01')) {
          final parsed = _parseWkbHex(locStr);
          if (parsed != null) {
            lng = parsed[0];
            lat = parsed[1];
          }
        }
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
      latitude: lat ?? (json['latitude'] as num?)?.toDouble(),
      longitude: lng ?? (json['longitude'] as num?)?.toDouble(),
    );
  }

  /// Parses a PostGIS WKB/EWKB Hex String into [longitude, latitude].
  /// EWKB with SRID (geography): 01 + 01000020 + E6100000 + X(8 bytes) + Y(8 bytes)
  ///   byte order(1) + type(4) + srid(4) = 9 bytes = 18 hex chars before coords
  /// Plain WKB (geometry): 01 + 01000000 + X(8 bytes) + Y(8 bytes)
  ///   byte order(1) + type(4) = 5 bytes = 10 hex chars before coords
  static List<double>? _parseWkbHex(String hex) {
    if (hex.length < 42) return null;
    try {
      if (!hex.startsWith('01')) return null;

      // Type is 4 bytes little-endian at hex[2..9].
      // Read as LE: reverse byte pairs then parse.
      // e.g. "01000020" LE → bytes [01,00,00,20] → BE "20000001" → 0x20000001
      final typeLeHex = hex.substring(2, 10);
      String typeBeHex = '';
      for (int i = typeLeHex.length - 2; i >= 0; i -= 2) {
        typeBeHex += typeLeHex.substring(i, i + 2);
      }
      final typeInt = int.parse(typeBeHex, radix: 16);
      final hasSrid = (typeInt & 0x20000000) != 0;
      // EWKB layout: 1(endian) + 4(type) + 4(srid if present) = 9 or 5 bytes = 18 or 10 hex chars
      final int offset = hasSrid ? 18 : 10;

      if (hex.length < offset + 32) return null;

      final xHex = hex.substring(offset, offset + 16);
      final yHex = hex.substring(offset + 16, offset + 32);

      return [_hexToDouble(xHex), _hexToDouble(yHex)];
    } catch (e) {
      return null;
    }
  }

  static double _hexToDouble(String hex) {
    // Reverse byte order since it's little endian
    String reversed = '';
    for (int i = hex.length - 2; i >= 0; i -= 2) {
      reversed += hex.substring(i, i + 2);
    }
    
    // Parse to int, then use bitwise conversion to double
    int bits = int.parse(reversed, radix: 16);
    return _bitsToDouble(bits);
  }
  
  static double _bitsToDouble(int bits) {
    var buffer = ByteData(8);
    buffer.setUint64(0, bits);
    return buffer.getFloat64(0);
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
