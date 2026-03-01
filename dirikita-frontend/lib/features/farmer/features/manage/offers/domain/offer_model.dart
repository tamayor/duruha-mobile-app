class DailyOfferGroup {
  final DateTime dateCreated;
  final List<ProduceGroup> produces;

  DailyOfferGroup({required this.dateCreated, required this.produces});

  factory DailyOfferGroup.fromJson(Map<String, dynamic> json) {
    return DailyOfferGroup(
      dateCreated: json['date_created'] != null
          ? DateTime.parse(json['date_created'])
          : DateTime.now(),
      produces: (json['produce'] as List? ?? [])
          .map((p) => ProduceGroup.fromJson(p))
          .toList(),
    );
  }
}

class ProduceGroup {
  final String produceId;
  final String produceLocalName;
  final String produceEnglishName;
  final List<HarvestOffer> varieties;

  ProduceGroup({
    required this.produceId,
    required this.produceLocalName,
    required this.produceEnglishName,
    required this.varieties,
  });

  factory ProduceGroup.fromJson(Map<String, dynamic> json) {
    return ProduceGroup(
      produceId: json['produce_id'] ?? '',
      produceLocalName: json['produce_local_name']?.toString().trim() ?? '',
      produceEnglishName: json['produce_english_name']?.toString().trim() ?? '',
      varieties: (json['produce_varieties'] as List? ?? [])
          .map((v) => HarvestOffer.fromJson(v))
          .toList(),
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
      ordersTotalPrice: (json['orders_total_price'] as num? ?? 0.0).toDouble(),
      farmerTotalEarnings: (json['farmer_total_earnings'] as num? ?? 0.0)
          .toDouble(),
      orders: (json['orders'] as List? ?? [])
          .map((o) => FarmerOfferOrder.fromJson(o))
          .toList(),
    );
  }
}

class FarmerOfferOrder {
  final String? consumerId;
  final double price;
  final double quantity;
  final String? quality;
  final double farmerPayout;
  final bool farmerIsPaid;
  final String? deliveryStatus;
  final DateTime? dispatchAt;
  final String? carrierName;
  final String? consumerName;
  final DateTime createdAt;
  final String offerOrderMatchId;
  final DateTime? dateNeeded;

  FarmerOfferOrder({
    this.consumerId,
    required this.price,
    required this.quantity,
    this.quality,
    required this.farmerPayout,
    required this.farmerIsPaid,
    this.deliveryStatus,
    this.dispatchAt,
    this.carrierName,
    this.consumerName,

    required this.createdAt,
    required this.offerOrderMatchId,
    this.dateNeeded,
  });

  factory FarmerOfferOrder.fromJson(Map<String, dynamic> json) {
    final double parsedPrice =
        (json['final_price'] ??
                json['variable_farmer_price'] ??
                json['price_lock'] ??
                json['price'] ??
                0.0)
            .toDouble();

    final double parsedQuantity = (json['quantity'] ?? 0.0).toDouble();

    final DateTime created = json['order_at'] != null
        ? DateTime.parse(json['order_at'])
        : (json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now());

    return FarmerOfferOrder(
      consumerId: json['consumer_id'],
      price: parsedPrice,
      quantity: parsedQuantity,
      offerOrderMatchId:
          (json['foa_id'] ?? json['offer_order_match_item_id'] ?? ''),
      dateNeeded: json['date_needed'] != null
          ? DateTime.parse(json['date_needed'])
          : created,
      quality: json['quality'],
      farmerPayout: (json['farmer_payout'] ?? (parsedPrice * parsedQuantity))
          .toDouble(),
      farmerIsPaid: json['is_paid'] ?? json['farmer_is_paid'] ?? false,
      deliveryStatus: json['delivery_status'],
      dispatchAt: json['dispatch_at'] != null
          ? DateTime.parse(json['dispatch_at'])
          : null,
      carrierName: json['carrier_name'],
      consumerName: json['consumer_name'],
      createdAt: created,
    );
  }

  FarmerOfferOrder copyWith({
    String? consumerId,
    double? price,
    double? quantity,
    String? quality,
    double? farmerPayout,
    bool? farmerIsPaid,
    String? deliveryStatus,
    DateTime? dispatchAt,
    String? carrierName,
    String? consumerName,
    DateTime? createdAt,
    String? offerOrderMatchId,
    DateTime? dateNeeded,
  }) {
    return FarmerOfferOrder(
      consumerId: consumerId ?? this.consumerId,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      quality: quality ?? this.quality,
      farmerPayout: farmerPayout ?? this.farmerPayout,
      farmerIsPaid: farmerIsPaid ?? this.farmerIsPaid,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      dispatchAt: dispatchAt ?? this.dispatchAt,
      carrierName: carrierName ?? this.carrierName,
      consumerName: consumerName ?? this.consumerName,
      createdAt: createdAt ?? this.createdAt,
      offerOrderMatchId: offerOrderMatchId ?? this.offerOrderMatchId,
      dateNeeded: dateNeeded ?? this.dateNeeded,
    );
  }
}
