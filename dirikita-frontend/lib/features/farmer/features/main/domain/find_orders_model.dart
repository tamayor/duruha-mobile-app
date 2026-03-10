class FindOrdersResult {
  final FindOrdersPagination pagination;
  final List<FindOrderItem> orders;

  FindOrdersResult({required this.pagination, required this.orders});

  factory FindOrdersResult.fromJson(Map<String, dynamic> json) {
    return FindOrdersResult(
      pagination: FindOrdersPagination.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
      orders: (json['orders'] as List<dynamic>? ?? [])
          .map((e) => FindOrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FindOrdersPagination {
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final String mode;
  final double radiusKm;

  FindOrdersPagination({
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.mode,
    required this.radiusKm,
  });

  factory FindOrdersPagination.fromJson(Map<String, dynamic> json) {
    return FindOrdersPagination(
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      totalCount: json['total_count'] as int,
      totalPages: (json['total_pages'] as num).toInt(),
      mode: json['mode'] as String,
      radiusKm: (json['radius_km'] as num).toDouble(),
    );
  }
}

class FindOrderItem {
  final String orderId;
  final String copId;
  final String? note;
  final String produceId;
  final String produceEnglishName;
  final String produceLocalName;
  final String? produceImageUrl;
  final String? produceForm;
  final String? quality;
  final double? distanceKm;
  final bool isFavouriteProduce;
  final ConsumerLocation? consumerLocation;
  final List<VarietyGroup> varietyGroup;

  FindOrderItem({
    required this.orderId,
    required this.copId,
    this.note,
    required this.produceId,
    required this.produceEnglishName,
    required this.produceLocalName,
    this.produceImageUrl,
    this.produceForm,
    this.quality,
    this.distanceKm,
    required this.isFavouriteProduce,
    this.consumerLocation,
    required this.varietyGroup,
  });

  factory FindOrderItem.fromJson(Map<String, dynamic> json) {
    return FindOrderItem(
      orderId: json['order_id'] as String,
      copId: json['cop_id'] as String,
      note: json['note'] as String?,
      produceId: json['produce_id'] as String,
      produceEnglishName: json['produce_english_name'] as String,
      produceLocalName: json['produce_local_name'] as String,
      produceImageUrl: json['produce_image_url'] as String?,
      produceForm: json['produce_form'] as String?,
      quality: json['quality'] as String?,
      distanceKm: json['distance_km'] != null
          ? (json['distance_km'] as num).toDouble()
          : null,
      isFavouriteProduce: json['is_favourite_produce'] as bool? ?? false,
      consumerLocation: json['consumer_location'] != null
          ? ConsumerLocation.fromJson(
              json['consumer_location'] as Map<String, dynamic>,
            )
          : null,
      varietyGroup: (json['variety_group'] as List<dynamic>? ?? [])
          .map((e) => VarietyGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Earliest date needed across all variety groups
  DateTime? get earliestDateNeeded {
    if (varietyGroup.isEmpty) return null;
    return varietyGroup
        .map((g) => g.dateNeeded)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Total quantity across all variety groups
  double get totalQuantity =>
      varietyGroup.fold(0, (sum, g) => sum + g.quantity);

  /// Unique variety names across all variety groups
  List<String> get uniqueVarieties {
    final names = varietyGroup
        .expand((g) => g.varieties)
        .map((v) => v.varietyName)
        .whereType<String>()
        .toSet()
        .toList();
    names.sort();
    return names;
  }
}

class VarietyGroup {
  final String covgId;
  final DateTime dateNeeded;
  final double quantity;
  final List<VarietyOption> varieties;

  VarietyGroup({
    required this.covgId,
    required this.dateNeeded,
    required this.quantity,
    required this.varieties,
  });

  factory VarietyGroup.fromJson(Map<String, dynamic> json) {
    return VarietyGroup(
      covgId: json['covg_id'] as String,
      dateNeeded: DateTime.parse(json['date_needed'] as String),
      quantity: (json['quantity'] as num).toDouble(),
      varieties: (json['varieties'] as List<dynamic>? ?? [])
          .map((e) => VarietyOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class VarietyOption {
  final String? varietyName;
  final double? ftdPrice;
  final String? covId;

  VarietyOption({this.varietyName, this.ftdPrice, this.covId});

  factory VarietyOption.fromJson(Map<String, dynamic> json) {
    return VarietyOption(
      varietyName: json['variety_name'] as String?,
      ftdPrice: json['ftd_price'] != null
          ? (json['ftd_price'] as num).toDouble()
          : null,
      covId: json['cov_id'] as String?,
    );
  }
}

class ConsumerLocation {
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? province;

  ConsumerLocation({
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.province,
  });

  factory ConsumerLocation.fromJson(Map<String, dynamic> json) {
    return ConsumerLocation(
      addressLine1: json['address_line_1'] as String?,
      addressLine2: json['address_line_2'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
    );
  }

  String get displayAddress {
    final parts = [
      addressLine1,
      addressLine2,
      city,
      province,
    ].where((p) => p != null && p.isNotEmpty).toList();
    return parts.join(', ');
  }
}
