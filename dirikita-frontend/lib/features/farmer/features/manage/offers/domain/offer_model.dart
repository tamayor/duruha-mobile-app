/// Thin produce info carried on every flat offer — also used by the detail screens.
class ProduceOfferGroup {
  final String produceId;
  final String produceLocalName;
  final String produceEnglishName;
  /// Unused in the flat list view; kept for compatibility with detail screens
  /// (e.g. OfferDetailLoaderScreen passes `dates: []`).
  final List<DailyOfferGroup> dates;

  ProduceOfferGroup({
    required this.produceId,
    required this.produceLocalName,
    required this.produceEnglishName,
    this.dates = const [],
  });

  String get displayName =>
      produceLocalName.isNotEmpty ? produceLocalName : produceEnglishName;
}

/// Kept only for OfferDetailLoaderScreen compatibility; not used in the list.
class DailyOfferGroup {
  final DateTime dateCreated;
  final List<HarvestOffer> varieties;

  DailyOfferGroup({required this.dateCreated, required this.varieties});
}

/// A single flat offer as returned by get_farmer_offers — carries produce info inline.
class FlatOffer {
  final HarvestOffer offer;
  final ProduceOfferGroup produce;

  FlatOffer({required this.offer, required this.produce});

  factory FlatOffer.fromJson(Map<String, dynamic> json) {
    return FlatOffer(
      offer: HarvestOffer.fromJson(json),
      produce: ProduceOfferGroup(
        produceId: json['produce_id'] ?? '',
        produceLocalName: json['produce_local_name']?.toString().trim() ?? '',
        produceEnglishName:
            json['produce_english_name']?.toString().trim() ?? '',
      ),
    );
  }
}

class HarvestOffer {
  final String offerId;
  final String varietyName;
  final double quantity;
  final double remainingQuantity;
  final bool isActive;
  final bool isPriceLocked;
  final double? totalPriceLockCredit;
  final double? remainingPriceLockCredit;
  final DateTime availableFrom;
  final DateTime availableTo;
  final DateTime createdAt;
  final double ordersTotalPrice;
  final double farmerTotalEarnings;
  final String? fplsStatus;
  final List<FarmerOfferOrder> orders;

  double get reservedQty => quantity - remainingQuantity;

  HarvestOffer({
    required this.offerId,
    required this.varietyName,
    required this.quantity,
    required this.remainingQuantity,
    required this.isActive,
    required this.isPriceLocked,
    this.totalPriceLockCredit,
    this.remainingPriceLockCredit,
    required this.availableFrom,
    required this.availableTo,
    required this.createdAt,
    required this.ordersTotalPrice,
    required this.farmerTotalEarnings,
    required this.fplsStatus,
    required this.orders,
  });

  factory HarvestOffer.fromJson(Map<String, dynamic> json) {
    return HarvestOffer(
      offerId: json['offer_id'] ?? '',
      varietyName: json['variety_name'] ?? '',
      quantity: (json['quantity'] as num? ?? 0.0).toDouble(),
      remainingQuantity: (json['remaining_quantity'] as num? ?? 0.0).toDouble(),
      fplsStatus: json['fpls_status'] ?? '',
      isActive: json['is_active'] ?? true,
      isPriceLocked: json['is_price_locked'] ?? false,
      totalPriceLockCredit: (json['total_price_lock_credit'] as num?)
          ?.toDouble(),
      remainingPriceLockCredit: (json['remaining_price_lock_credit'] as num?)
          ?.toDouble(),
      availableFrom: json['available_from'] != null
          ? DateTime.parse(json['available_from'])
          : DateTime.now(),
      availableTo: json['available_to'] != null
          ? DateTime.parse(json['available_to'])
          : DateTime(2100),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      ordersTotalPrice: (json['orders_total_price'] as num? ?? 0.0).toDouble(),
      farmerTotalEarnings: (json['farmer_total_earnings'] as num? ?? 0.0)
          .toDouble(),
      orders: (json['orders'] as List? ?? [])
          .map((o) => FarmerOfferOrder.fromJson(o))
          .toList(),
    );
  }

  HarvestOffer copyWith({
    String? offerId,
    String? varietyName,
    double? quantity,
    double? remainingQuantity,
    bool? isActive,
    bool? isPriceLocked,
    double? totalPriceLockCredit,
    double? remainingPriceLockCredit,
    DateTime? availableFrom,
    DateTime? availableTo,
    DateTime? createdAt,
    double? ordersTotalPrice,
    double? farmerTotalEarnings,
    String? fplsStatus,
    List<FarmerOfferOrder>? orders,
  }) {
    return HarvestOffer(
      offerId: offerId ?? this.offerId,
      varietyName: varietyName ?? this.varietyName,
      quantity: quantity ?? this.quantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      isActive: isActive ?? this.isActive,
      isPriceLocked: isPriceLocked ?? this.isPriceLocked,
      totalPriceLockCredit: totalPriceLockCredit ?? this.totalPriceLockCredit,
      remainingPriceLockCredit:
          remainingPriceLockCredit ?? this.remainingPriceLockCredit,
      availableFrom: availableFrom ?? this.availableFrom,
      availableTo: availableTo ?? this.availableTo,
      createdAt: createdAt ?? this.createdAt,
      ordersTotalPrice: ordersTotalPrice ?? this.ordersTotalPrice,
      farmerTotalEarnings: farmerTotalEarnings ?? this.farmerTotalEarnings,
      fplsStatus: fplsStatus ?? this.fplsStatus,
      orders: orders ?? this.orders,
    );
  }
}

/// Full offer detail returned by get_farmer_offer_orders — includes offer fields,
/// orders, and summary totals. This is the single source of truth for the detail screen.
class OfferDetail {
  final HarvestOffer offer;

  // Summary totals
  final double activeTotal;
  final double ordersTotalPrice;
  final double farmerTotalEarnings;

  // Subscription meta
  final String? fpsId;
  final String? fpsStatus;
  final String? fpsPlanCode;
  final String? fpsPlanName;
  final bool fpsPriceLockEnabled;

  final List<FarmerOfferOrder> orders;

  OfferDetail({
    required this.offer,
    required this.activeTotal,
    required this.ordersTotalPrice,
    required this.farmerTotalEarnings,
    this.fpsId,
    this.fpsStatus,
    this.fpsPlanCode,
    this.fpsPlanName,
    this.fpsPriceLockEnabled = false,
    required this.orders,
  });

  factory OfferDetail.fromJson(Map<String, dynamic> json) {
    final ordersRaw = json['orders'] as List? ?? [];
    final orders =
        ordersRaw.map((o) => FarmerOfferOrder.fromJson(o as Map<String, dynamic>)).toList();

    final offer = HarvestOffer(
      offerId: json['offer_id'] ?? '',
      varietyName: json['variety_name'] ?? '',
      quantity: (json['quantity'] as num? ?? 0.0).toDouble(),
      remainingQuantity: (json['remaining_quantity'] as num? ?? 0.0).toDouble(),
      isActive: json['is_active'] ?? true,
      isPriceLocked: json['is_price_locked'] ?? false,
      totalPriceLockCredit: (json['total_price_lock_credit'] as num?)?.toDouble(),
      remainingPriceLockCredit:
          (json['remaining_price_lock_credit'] as num?)?.toDouble(),
      availableFrom: json['available_from'] != null
          ? DateTime.parse(json['available_from'])
          : DateTime.now(),
      availableTo: json['available_to'] != null
          ? DateTime.parse(json['available_to'])
          : DateTime(2100),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      fplsStatus: json['fps_status'],
      ordersTotalPrice: (json['orders_total_price'] as num? ?? 0.0).toDouble(),
      farmerTotalEarnings: (json['farmer_total_earnings'] as num? ?? 0.0).toDouble(),
      orders: orders,
    );

    return OfferDetail(
      offer: offer,
      activeTotal: (json['active_total'] as num? ?? 0.0).toDouble(),
      ordersTotalPrice: (json['orders_total_price'] as num? ?? 0.0).toDouble(),
      farmerTotalEarnings: (json['farmer_total_earnings'] as num? ?? 0.0).toDouble(),
      fpsId: json['fps_id'] as String?,
      fpsStatus: json['fps_status'] as String?,
      fpsPlanCode: json['fps_plan_code'] as String?,
      fpsPlanName: json['fps_plan_name'] as String?,
      fpsPriceLockEnabled: json['fps_price_lock_enabled'] as bool? ?? false,
      orders: orders,
    );
  }

  /// Returns a copy with a refreshed offer (e.g. after status change).
  OfferDetail copyWithOffer(HarvestOffer updatedOffer) {
    return OfferDetail(
      offer: updatedOffer,
      activeTotal: activeTotal,
      ordersTotalPrice: ordersTotalPrice,
      farmerTotalEarnings: farmerTotalEarnings,
      fpsId: fpsId,
      fpsStatus: fpsStatus,
      fpsPlanCode: fpsPlanCode,
      fpsPlanName: fpsPlanName,
      fpsPriceLockEnabled: fpsPriceLockEnabled,
      orders: orders,
    );
  }

  /// Returns a copy with refreshed orders + summary.
  OfferDetail copyWithOrders({
    required List<FarmerOfferOrder> orders,
    double? activeTotal,
    double? ordersTotalPrice,
    double? farmerTotalEarnings,
  }) {
    return OfferDetail(
      offer: offer,
      activeTotal: activeTotal ?? this.activeTotal,
      ordersTotalPrice: ordersTotalPrice ?? this.ordersTotalPrice,
      farmerTotalEarnings: farmerTotalEarnings ?? this.farmerTotalEarnings,
      fpsId: fpsId,
      fpsStatus: fpsStatus,
      fpsPlanCode: fpsPlanCode,
      fpsPlanName: fpsPlanName,
      fpsPriceLockEnabled: fpsPriceLockEnabled,
      orders: orders,
    );
  }
}

class ConsumerDeliveryAddress {
  final String addressId;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? province;
  final String? region;
  final String? postalCode;
  final String? landmark;
  final String? country;

  ConsumerDeliveryAddress({
    required this.addressId,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.province,
    this.region,
    this.postalCode,
    this.landmark,
    this.country,
  });

  factory ConsumerDeliveryAddress.fromJson(Map<String, dynamic> json) {
    return ConsumerDeliveryAddress(
      addressId: json['address_id'] ?? '',
      addressLine1: json['address_line_1'],
      addressLine2: json['address_line_2'],
      city: json['city'],
      province: json['province'],
      region: json['region'],
      postalCode: json['postal_code'],
      landmark: json['landmark'],
      country: json['country'],
    );
  }

  String get shortAddress {
    final parts = [addressLine1, city, province].where((p) => p != null && p.isNotEmpty).toList();
    return parts.join(', ');
  }
}

class FarmerOfferOrder {
  final String? consumerId;
  final double price;
  final double finalPrice;
  final double ftdPrice;
  final double quantity;
  final String? quality;
  final String? produceNote;
  final double farmerPayout;
  final bool farmerIsPaid;
  final String? deliveryStatus;
  final DateTime? dispatchAt;
  final String? carrierName;
  final String? consumerName;
  final DateTime createdAt;
  final String offerOrderMatchId;
  final DateTime? dateNeeded;
  final ConsumerDeliveryAddress? consumerAddress;

  FarmerOfferOrder({
    this.consumerId,
    required this.price,
    required this.finalPrice,
    required this.ftdPrice,
    required this.quantity,
    this.quality,
    this.produceNote,
    required this.farmerPayout,
    required this.farmerIsPaid,
    this.deliveryStatus,
    this.dispatchAt,
    this.carrierName,
    this.consumerName,
    required this.createdAt,
    required this.offerOrderMatchId,
    this.dateNeeded,
    this.consumerAddress,
  });

  /// True when dispatch date is not set, is far future (>= year 2100),
  /// or is more than 365 days from today — meaning the farmer still needs to set it.
  bool get needsDispatchSetup {
    if (dispatchAt == null) return true;
    if (dispatchAt!.year >= 2100) return true;
    if (dispatchAt!.difference(DateTime.now()).inDays >= 365) return true;
    return false;
  }

  factory FarmerOfferOrder.fromJson(Map<String, dynamic> json) {
    final double parsedFinalPrice = (json['final_price'] ?? 0.0).toDouble();
    final double parsedFtdPrice = (json['ftd_price'] ?? parsedFinalPrice).toDouble();
    final double parsedPrice =
        (json['price_lock'] ?? json['final_price'] ?? 0.0).toDouble();

    final double parsedQuantity = (json['quantity'] ?? 0.0).toDouble();

    final DateTime created = json['order_at'] != null
        ? DateTime.parse(json['order_at'])
        : (json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now());

    final addressJson = json['consumer_address'];

    return FarmerOfferOrder(
      consumerId: json['consumer_id'],
      price: parsedPrice,
      finalPrice: parsedFinalPrice,
      ftdPrice: parsedFtdPrice,
      quantity: parsedQuantity,
      offerOrderMatchId:
          (json['foa_id'] ?? json['offer_order_match_item_id'] ?? ''),
      dateNeeded: json['date_needed'] != null
          ? DateTime.parse(json['date_needed'])
          : created,
      quality: json['quality'],
      produceNote: json['produce_note'],
      farmerPayout: parsedFtdPrice,
      farmerIsPaid: json['is_paid'] ?? json['farmer_is_paid'] ?? false,
      deliveryStatus: json['delivery_status'],
      dispatchAt: json['dispatch_at'] != null
          ? DateTime.parse(json['dispatch_at'])
          : null,
      carrierName: json['carrier_name'],
      consumerName: json['consumer_name'],
      createdAt: created,
      consumerAddress: addressJson != null
          ? ConsumerDeliveryAddress.fromJson(
              Map<String, dynamic>.from(addressJson))
          : null,
    );
  }

  FarmerOfferOrder copyWith({
    String? consumerId,
    double? price,
    double? finalPrice,
    double? ftdPrice,
    double? quantity,
    String? quality,
    String? produceNote,
    double? farmerPayout,
    bool? farmerIsPaid,
    String? deliveryStatus,
    DateTime? dispatchAt,
    String? carrierName,
    String? consumerName,
    DateTime? createdAt,
    String? offerOrderMatchId,
    DateTime? dateNeeded,
    ConsumerDeliveryAddress? consumerAddress,
  }) {
    return FarmerOfferOrder(
      consumerId: consumerId ?? this.consumerId,
      price: price ?? this.price,
      finalPrice: finalPrice ?? this.finalPrice,
      ftdPrice: ftdPrice ?? this.ftdPrice,
      quantity: quantity ?? this.quantity,
      quality: quality ?? this.quality,
      produceNote: produceNote ?? this.produceNote,
      farmerPayout: farmerPayout ?? this.farmerPayout,
      farmerIsPaid: farmerIsPaid ?? this.farmerIsPaid,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      dispatchAt: dispatchAt ?? this.dispatchAt,
      carrierName: carrierName ?? this.carrierName,
      consumerName: consumerName ?? this.consumerName,
      createdAt: createdAt ?? this.createdAt,
      offerOrderMatchId: offerOrderMatchId ?? this.offerOrderMatchId,
      dateNeeded: dateNeeded ?? this.dateNeeded,
      consumerAddress: consumerAddress ?? this.consumerAddress,
    );
  }
}
