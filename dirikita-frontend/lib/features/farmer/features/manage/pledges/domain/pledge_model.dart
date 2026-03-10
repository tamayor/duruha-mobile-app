class FarmerPledgeGroup {
  final String produceId;
  final String produceEnglishName;
  final String produceLocalName;
  final String varietyName;
  final String produceForm;
  final List<PledgeScheduleEntry> pledgesSchedule;

  FarmerPledgeGroup({
    required this.produceId,
    required this.produceEnglishName,
    required this.produceLocalName,
    required this.varietyName,
    required this.produceForm,
    required this.pledgesSchedule,
  });

  factory FarmerPledgeGroup.fromJson(Map<String, dynamic> json) {
    return FarmerPledgeGroup(
      produceId: json['produce_id'] ?? '',
      produceEnglishName: json['produce_english_name'] ?? '',
      produceLocalName: json['produce_local_name'] ?? '',
      varietyName: json['variety_name'] ?? '',
      produceForm: json['produce_form'] ?? '',
      pledgesSchedule: (json['pledges_schedule'] as List? ?? [])
          .map((e) => PledgeScheduleEntry.fromJson(e))
          .toList(),
    );
  }

  String get produceDisplayName =>
      produceLocalName.isNotEmpty ? produceLocalName : produceEnglishName;
}

class PledgeScheduleEntry {
  final DateTime dateNeeded;
  final String? deliveryStatus;
  final DateTime? dispatchAt;
  final String? carrierId;
  final String? carrierName;
  final PledgeAddress? consumerAddress;
  final PledgeAddress? farmerAddress;
  final bool isPaid;
  final double finalPrice;
  final double ftdPrice;
  final double priceLock;
  final String? fpsId;
  final String? paymentMethod;
  final double quantity;
  final String? note;

  PledgeScheduleEntry({
    required this.dateNeeded,
    this.deliveryStatus,
    this.dispatchAt,
    this.carrierId,
    this.carrierName,
    this.consumerAddress,
    this.farmerAddress,
    required this.isPaid,
    required this.finalPrice,
    required this.ftdPrice,
    required this.priceLock,
    this.fpsId,
    this.paymentMethod,
    required this.quantity,
    this.note,
  });

  factory PledgeScheduleEntry.fromJson(Map<String, dynamic> json) {
    return PledgeScheduleEntry(
      dateNeeded: json['date_needed'] != null
          ? DateTime.parse(json['date_needed'])
          : DateTime.now(),
      deliveryStatus: json['delivery_status'],
      dispatchAt: json['dispatch_at'] != null
          ? DateTime.parse(json['dispatch_at'])
          : null,
      carrierId: json['carrier_id'],
      carrierName: json['carrier_name'],
      consumerAddress: json['consumer_address'] != null
          ? PledgeAddress.fromJson(json['consumer_address'])
          : null,
      farmerAddress: json['farmer_address'] != null
          ? PledgeAddress.fromJson(json['farmer_address'])
          : null,
      isPaid: json['is_paid'] ?? false,
      finalPrice: (json['final_price'] as num? ?? 0.0).toDouble(),
      ftdPrice: (json['ftd_price'] as num? ?? 0.0).toDouble(),
      priceLock: (json['price_lock'] as num? ?? 0.0).toDouble(),
      fpsId: json['fps_id'],
      paymentMethod: json['payment_method'],
      quantity: (json['quantity'] as num? ?? 0.0).toDouble(),
      note: json['note'],
    );
  }
}

class PledgeAddress {
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String province;
  final String? landmark;
  final String? region;
  final String? postalCode;
  final String country;

  PledgeAddress({
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.province,
    this.landmark,
    this.region,
    this.postalCode,
    required this.country,
  });

  factory PledgeAddress.fromJson(Map<String, dynamic> json) {
    return PledgeAddress(
      addressLine1: json['address_line_1'] ?? '',
      addressLine2: json['address_line_2'],
      city: json['city'] ?? '',
      province: json['province'] ?? '',
      landmark: json['landmark'],
      region: json['region'],
      postalCode: json['postal_code'],
      country: json['country'] ?? '',
    );
  }

  @override
  String toString() {
    final parts = [
      addressLine1,
      if (addressLine2 != null && addressLine2!.isNotEmpty) addressLine2,
      city,
      province,
    ];
    return parts.join(', ');
  }
}
