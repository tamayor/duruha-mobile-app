class ConsumerOrderMatchResponse {
  final List<ConsumerOrderMatch> orders;
  final PaginationMetadata? pagination;

  ConsumerOrderMatchResponse({required this.orders, this.pagination});

  String? get nextCursor => pagination?.nextCursor;

  factory ConsumerOrderMatchResponse.fromJson(Map<String, dynamic> json) {
    if (json['order_id'] != null && json['produce'] != null) {
      return ConsumerOrderMatchResponse(
        orders: [ConsumerOrderMatch.fromJson(json)],
      );
    }

    // Handle the new simplified list format from get_consumer_orders
    final ordersJson = json['orders'] as List<dynamic>?;
    return ConsumerOrderMatchResponse(
      orders:
          ordersJson
              ?.map(
                (v) => v != null
                    ? ConsumerOrderMatch.fromJson(v as Map<String, dynamic>)
                    : null,
              )
              .whereType<ConsumerOrderMatch>()
              .toList() ??
          [],
      pagination: json['pagination'] != null
          ? PaginationMetadata.fromJson(
              json['pagination'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'orders': orders.map((v) => v.toJson()).toList(),
    'pagination': pagination?.toJson(),
  };
}

class PaginationMetadata {
  final int limit;
  final String? nextCursor;
  final int total;
  final bool hasMore;

  PaginationMetadata({
    required this.limit,
    this.nextCursor,
    required this.total,
    required this.hasMore,
  });

  factory PaginationMetadata.fromJson(Map<String, dynamic> json) {
    return PaginationMetadata(
      limit: (json['limit'] as num?)?.toInt() ?? 10,
      nextCursor: json['next_cursor']?.toString(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      hasMore: json['has_more'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'limit': limit,
    'next_cursor': nextCursor,
    'total': total,
    'has_more': hasMore,
  };
}

class ConsumerOrderMatch {
  final String orderId;
  final String? note;
  final String dateCreated;
  final bool isActive;
  final String paymentMethod;
  final List<ProduceItem> produceItems;
  final OrderStats? stats;
  final bool isPlan;

  ConsumerOrderMatch({
    required this.orderId,
    this.note,
    required this.dateCreated,
    required this.isActive,
    this.paymentMethod = 'Not Paid',
    required this.produceItems,
    this.stats,
    this.isPlan = false,
  });

  factory ConsumerOrderMatch.fromJson(Map<String, dynamic> json) {
    return ConsumerOrderMatch(
      orderId: json['order_id']?.toString() ?? '',
      note: json['note']?.toString(),
      dateCreated:
          json['date_created']?.toString() ??
          json['created_at']?.toString() ??
          '',
      isActive: json['is_active'] == true,
      paymentMethod: json['payment_method']?.toString() ?? 'Not Paid',
      produceItems:
          (json['produce'] as List<dynamic>? ??
                  json['produce_items'] as List<dynamic>? ??
                  [])
              .map(
                (v) => v is Map<String, dynamic>
                    ? ProduceItem.fromJson(v)
                    : ProduceItem.fromName(v.toString()),
              )
              .toList(),
      stats: json['stats'] != null ? OrderStats.fromJson(json['stats']) : null,
      isPlan: json['is_plan'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'order_id': orderId,
    'note': note,
    'date_created': dateCreated,
    'is_active': isActive,
    'payment_method': paymentMethod,
    'produce': produceItems.map((v) => v.toJson()).toList(),
    'stats': stats?.toJson(),
    'is_plan': isPlan,
  };

  double get totalAmount => produceItems.fold(0.0, (sum, item) {
    final double varietyTotal = item.varieties.fold(
      0.0,
      (vSum, v) => vSum + v.varietySubtotal(item.isPriceLock),
    );
    final double deliveryTotal = item.varieties.fold(
      0.0,
      (dSum, v) =>
          dSum +
          v.varietyGroups.fold(0.0, (gSum, vg) {
            if (vg.deliveryStatus == 'CANCELLED') return gSum;
            return gSum + (vg.deliveryFee ?? 0.0);
          }),
    );
    return sum + varietyTotal + item.effectiveQualityFee + deliveryTotal;
  });

  // Compatibility getters
  String get createdAt => dateCreated;

  bool get isCancellable {
    // If any item/variety is beyond these statuses, the whole order is no longer cancellable
    const nonCancellable = [
      'QC_PASSED',
      'DISPATCHED',
      'IN_TRANSIT_TO_HUB',
      'ARRIVED_AT_HUB',
      'SORTING',
      'OUT_FOR_DELIVERY',
      'ARRIVED',
      'DELIVERED',
    ];

    for (final item in produceItems) {
      for (final variety in item.varieties) {
        for (final group in variety.varietyGroups) {
          if (nonCancellable.contains(group.deliveryStatus)) {
            return false;
          }
        }
      }
    }
    return true;
  }

  bool get isPaid => produceItems.any(
    (item) => item.varieties.any((v) => v.varietyGroups.any((vg) => vg.isPaid)),
  );
  String get offerOrderMatchId => orderId;
  List<ProduceItem> get orderItems => produceItems;
  bool get isSummary => produceItems.every((item) => item.varieties.isEmpty);
  bool get isPriceFinalized =>
      produceItems.every((item) => item.isPriceFinalized);

  // Dummy order structure to avoid breaking UI expecting nested order
  OrderSummary get order => OrderSummary(
    orderId: orderId,
    consumerId: '', // Unknown from flat structure
    note: note,
    isActive: isActive,
    createdAt: dateCreated,
    updatedAt: dateCreated,
    stats: stats,
    isPlan: isPlan,
  );

  // Dummy orderTotals structure to avoid breaking UI expecting nested totals
  OrderTotals get orderTotals => OrderTotals(
    totalFinalPrice: totalAmount,
    totalVariableConsumerPrice: totalAmount,
    totalPriceLock: 0,
  );
}

class OrderSummary {
  final String orderId;
  final String consumerId;
  final String? note;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  final OrderStats? stats;
  final bool isPlan;

  OrderSummary({
    required this.orderId,
    required this.consumerId,
    this.note,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.stats,
    this.isPlan = false,
  });

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    return OrderSummary(
      orderId: json['order_id']?.toString() ?? '',
      consumerId: json['consumer_id']?.toString() ?? '',
      note: json['note']?.toString(),
      isActive: json['is_active'] as bool? ?? false,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      stats: json['stats'] != null ? OrderStats.fromJson(json['stats']) : null,
      isPlan: json['is_plan'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'order_id': orderId,
    'consumer_id': consumerId,
    'note': note,
    'is_active': isActive,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'stats': stats?.toJson(),
    'is_plan': isPlan,
  };
}

class OrderStats {
  final Map<String, int> statusCounts;
  final int paidCount;
  final int unpaidCount;

  OrderStats({
    required this.statusCounts,
    required this.paidCount,
    required this.unpaidCount,
  });

  factory OrderStats.fromJson(Map<String, dynamic> json) {
    final statusJson = json['status'] as Map<String, dynamic>? ?? {};
    final statusCounts = statusJson.map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    );
    return OrderStats(
      statusCounts: statusCounts,
      paidCount: (json['paid'] as num?)?.toInt() ?? 0,
      unpaidCount: (json['unpaid'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': statusCounts,
    'paid': paidCount,
    'unpaid': unpaidCount,
  };
}

class OrderTotals {
  final num totalFinalPrice;
  final num totalVariableConsumerPrice;
  final num totalPriceLock;

  OrderTotals({
    required this.totalFinalPrice,
    required this.totalVariableConsumerPrice,
    required this.totalPriceLock,
  });

  factory OrderTotals.fromJson(Map<String, dynamic> json) {
    return OrderTotals(
      totalFinalPrice: json['total_final_price'] as num? ?? 0,
      totalVariableConsumerPrice:
          json['total_variable_consumer_price'] as num? ?? 0,
      totalPriceLock: json['total_price_lock'] as num? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_final_price': totalFinalPrice,
    'total_variable_consumer_price': totalVariableConsumerPrice,
    'total_price_lock': totalPriceLock,
  };

  // Compatibility fields (fallback if UI expects them)
  int get priceLockVarietyCount => 0;
  int get marketVarietyCount => 0;
}

class ProduceItem {
  final String produceId;
  final String produceEnglishName;
  final String? produceLocalName;
  final double produceTotal;
  final String quality;
  final double qualityFee;
  final int itemIndex;
  final bool isDone;
  final List<ProduceVariety> varieties;

  ProduceItem({
    required this.produceId,
    required this.produceEnglishName,
    this.produceLocalName,
    required this.produceTotal,
    required this.quality,
    required this.qualityFee,
    this.itemIndex = 0,
    this.isDone = false,
    required this.varieties,
  });

  factory ProduceItem.fromJson(Map<String, dynamic> json) {
    return ProduceItem(
      produceId: json['id']?.toString() ?? json['produce_id']?.toString() ?? '',
      produceEnglishName:
          json['english_name']?.toString() ??
          json['produce_english_name']?.toString() ??
          '',
      produceLocalName:
          json['local_name']?.toString() ??
          json['produce_local_name']?.toString(),
      produceTotal: (json['produce_total'] as num?)?.toDouble() ?? 0.0,
      quality: json['quality']?.toString() ?? 'Regular',
      qualityFee: (json['quality_fee'] as num?)?.toDouble() ?? 0.0,
      itemIndex: (json['item_index'] as num?)?.toInt() ?? 0,
      isDone: json['is_done'] == true,
      varieties:
          (json['variety_group'] as List<dynamic>? ??
                  json['varieties'] as List<dynamic>? ??
                  [])
              .map((v) => ProduceVariety.fromJson(v as Map<String, dynamic>))
              .toList(),
    );
  }

  factory ProduceItem.fromName(String name) {
    return ProduceItem(
      produceId: '',
      produceEnglishName: name,
      produceTotal: 0.0,
      quality: 'Regular',
      qualityFee: 0.0,
      itemIndex: 0,
      isDone: false,
      varieties: [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': produceId,
    'english_name': produceEnglishName,
    'local_name': produceLocalName,
    'produce_total': produceTotal,
    'quality': quality,
    'quality_fee': qualityFee,
    'item_index': itemIndex,
    'is_done': isDone,
    'variety_group': varieties.map((v) => v.toJson()).toList(),
  };

  // Computed: isPriceLock/isAny delegate to variety_group level
  bool get isPriceLock => varieties.any((v) => v.isPriceLock);
  bool get isAny => varieties.any((v) => v.isAny);

  // Compatibility getters
  String get produceDialectName => produceLocalName ?? produceEnglishName;
  String get produceImageUrl => '';

  bool get isCancelled => varieties.every((v) => v.isCancelled);
  double get effectiveQualityFee => isCancelled ? 0.0 : qualityFee;

  double get deliveryFee =>
      varieties.isNotEmpty && varieties.first.varietyGroups.isNotEmpty
      ? (varieties.first.varietyGroups.first.deliveryFee ?? 0.0)
      : 0.0;
  String get carrierName =>
      varieties.isNotEmpty && varieties.first.varietyGroups.isNotEmpty
      ? (varieties.first.varietyGroups.first.carrierName ?? '')
      : '';
  String get deliveryStatus =>
      varieties.isNotEmpty && varieties.first.varietyGroups.isNotEmpty
      ? (varieties.first.varietyGroups.first.deliveryStatus ?? 'PENDING')
      : 'PENDING';
  String get dispatchAt =>
      varieties.isNotEmpty && varieties.first.varietyGroups.isNotEmpty
      ? (varieties.first.varietyGroups.first.dispatchDate ?? '')
      : '';
  String get dateNeeded =>
      varieties.isNotEmpty ? varieties.first.dateNeeded : '';

  List<ProduceVarietyGroup> get varietyGroups => [
    ProduceVarietyGroup(varieties, isPriceLock),
  ];
  bool get isPriceFinalized => varieties.every((v) => v.isPriceFinalized);
}

class ProduceVarietyGroup {
  final List<ProduceVariety> varieties;
  final bool isItemPriceLocked;
  ProduceVarietyGroup(this.varieties, this.isItemPriceLocked);

  String get groupId => "0";
  double get totalQuantity => varieties.fold(0.0, (sum, v) => sum + v.quantity);
  double get totalPrice => varieties.fold(0.0, (sum, v) => sum + v.finalPrice);
}

class ProduceVariety {
  final int index;
  final bool isPriceLock;
  final bool isAny;
  final double quantity;
  final String? cplsId;
  final String? cfpsId;
  final String dateNeeded;
  final String form;
  final List<VarietySelection> varietyGroups;

  ProduceVariety({
    this.index = 0,
    this.isPriceLock = false,
    this.isAny = false,
    required this.quantity,
    this.cplsId,
    this.cfpsId,
    required this.dateNeeded,
    required this.form,
    required this.varietyGroups,
  });

  factory ProduceVariety.fromJson(Map<String, dynamic> json) {
    return ProduceVariety(
      index: (json['index'] as num?)?.toInt() ?? 0,
      isPriceLock: json['is_price_lock'] == true,
      isAny: json['is_any'] == true,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      cplsId: json['cpls_id']?.toString(),
      cfpsId: json['cfps_id']?.toString(),
      dateNeeded: json['date_needed']?.toString() ?? '',
      form: json['form']?.toString() ?? '',
      varietyGroups:
          (json['varieties'] as List<dynamic>? ??
                  json['variety_groups'] as List<dynamic>? ??
                  [])
              .map((v) => VarietySelection.fromJson(v as Map<String, dynamic>))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'index': index,
    'is_price_lock': isPriceLock,
    'is_any': isAny,
    'quantity': quantity,
    'cpls_id': cplsId,
    'cfps_id': cfpsId,
    'date_needed': dateNeeded,
    'form': form,
    'varieties': varietyGroups.map((v) => v.toJson()).toList(),
  };

  // Compatibility getters mapping down to allocations
  String get varietyName => varietyGroups.isNotEmpty
      ? (varietyGroups.first.name ?? 'Unknown Variety')
      : 'Unknown Variety';
  String? get produceForm => form;

  // We consider the variety group price-locked if the item or variety itself requested it
  String pricingMode(bool isItemPriceLocked) =>
      (isItemPriceLocked || isPriceLock) ? 'price_lock' : 'market';

  // Expose these fields from the first selection for backward compat where UI only shows one generic row
  bool get isPaid => varietyGroups.isNotEmpty && varietyGroups.first.isPaid;
  double? get variableConsumerPrice =>
      varietyGroups.isNotEmpty ? varietyGroups.first.variablePrice : null;
  double get finalPrice =>
      varietyGroups.isNotEmpty ? (varietyGroups.first.finalPrice ?? 0.0) : 0.0;
  double? get priceLock =>
      varietyGroups.isNotEmpty ? varietyGroups.first.priceLock : null;

  /// Returns the total price for this variety sum(quantity * unitPrice).
  double varietySubtotal(bool isItemPriceLocked) =>
      varietyGroups.fold(0.0, (sum, vg) {
        if (vg.deliveryStatus == 'CANCELLED') return sum;
        double unitPrice = vg.variablePrice ?? 0.0;
        if (vg.finalPrice != null && vg.finalPrice! > 0) {
          unitPrice = vg.finalPrice!;
        } else if ((isItemPriceLocked || isPriceLock) && vg.priceLock != null) {
          unitPrice = vg.priceLock!;
        }
        return sum + (vg.quantity * unitPrice);
      });

  bool get isFinalized =>
      varietyGroups.isNotEmpty &&
      varietyGroups.every(
        (vg) =>
            vg.deliveryStatus == 'DISPATCHED' ||
            vg.deliveryStatus == 'QC_PASSED',
      );
  bool get isPriceFinalized => varietyGroups.every((vg) => vg.isPriceFinalized);

  MatchCompat? get match =>
      varietyGroups.isNotEmpty && varietyGroups.first.deliveryStatus != null
      ? MatchCompat(this)
      : null;

  bool get isCancelled =>
      varietyGroups.every((vg) => vg.deliveryStatus == 'CANCELLED');
}

class VarietySelection {
  final String? name;
  final String selectionType; // 'OPEN' | 'MATCHED'
  final double quantity;
  final String? dispatchDate;
  final String? carrierName;
  final String? carrierId;
  final String? deliveryStatus;
  final double? deliveryFee;
  final double? priceLock;
  final double? finalPrice;
  final double? variablePrice;
  final bool isPaid;
  final String? listingId;
  final String? oomId;

  VarietySelection({
    this.name,
    this.selectionType = 'OPEN',
    required this.quantity,
    this.dispatchDate,
    this.carrierName,
    this.carrierId,
    this.deliveryStatus,
    this.deliveryFee,
    this.priceLock,
    this.finalPrice,
    this.variablePrice,
    required this.isPaid,
    this.listingId,
    this.oomId,
  });

  factory VarietySelection.fromJson(Map<String, dynamic> json) {
    return VarietySelection(
      name: json['name']?.toString() ?? json['variety_name']?.toString(),
      selectionType: json['selection_type']?.toString() ?? 'OPEN',
      quantity:
          (json['quantity'] as num?)?.toDouble() ??
          (json['allocated_quantity'] as num?)?.toDouble() ??
          0.0,
      dispatchDate:
          json['dispatch_date']?.toString() ?? json['dispatch_at']?.toString(),
      carrierName: json['carrier_name']?.toString(),
      carrierId: json['carrier_id']?.toString(),
      deliveryStatus: json['delivery_status']?.toString(),
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble(),
      priceLock: (json['price_lock'] as num?)?.toDouble(),
      finalPrice: (json['final_price'] as num?)?.toDouble(),
      variablePrice: (json['variable_price'] as num?)?.toDouble(),
      isPaid: json['is_paid'] == true,
      listingId: json['listing_id']?.toString(),
      oomId: json['oom_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'selection_type': selectionType,
    'quantity': quantity,
    'dispatch_date': dispatchDate,
    'carrier_name': carrierName,
    'carrier_id': carrierId,
    'delivery_status': deliveryStatus,
    'delivery_fee': deliveryFee,
    'price_lock': priceLock,
    'final_price': finalPrice,
    'variable_price': variablePrice,
    'is_paid': isPaid,
    'listing_id': listingId,
    'oom_id': oomId,
  };

  // Compat fields mapping to previous shape
  String get varietyName => name ?? 'Unknown';
  double get allocatedQuantity => quantity;
  bool get isSelected => true;
  bool get isPriceFinalized =>
      deliveryStatus == 'CANCELLED' || (finalPrice != null && finalPrice! > 0);
}

class MatchCompat {
  final ProduceVariety v;
  MatchCompat(this.v);

  String get deliveryStatus => v.varietyGroups.isNotEmpty
      ? (v.varietyGroups.first.deliveryStatus ?? 'PENDING')
      : 'PENDING';
  String get dispatchAt => v.varietyGroups.isNotEmpty
      ? (v.varietyGroups.first.dispatchDate ?? '')
      : '';
  double get deliveryFee => v.varietyGroups.isNotEmpty
      ? (v.varietyGroups.first.deliveryFee ?? 0.0)
      : 0.0;
  String get carrierName => v.varietyGroups.isNotEmpty
      ? (v.varietyGroups.first.carrierName ?? '')
      : '';
  CarrierCompat? get carrier =>
      carrierName.isNotEmpty ? CarrierCompat(carrierName) : null;
}

class CarrierCompat {
  final String name;
  CarrierCompat(this.name);
}

class PlaceOrderResult {
  final String orderId;
  final bool success;
  final String message;
  final int matched;
  final int failed;
  final List<PlaceOrderError> errors;
  final List<OrderSelection> selections;

  PlaceOrderResult({
    required this.orderId,
    required this.success,
    required this.message,
    required this.matched,
    required this.failed,
    required this.errors,
    this.selections = const [],
  });

  factory PlaceOrderResult.fromJson(Map<String, dynamic> json) {
    return PlaceOrderResult(
      orderId: json['order_id']?.toString() ?? '',
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      matched: (json['matched'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      errors:
          (json['errors'] as List<dynamic>?)
              ?.map((e) => PlaceOrderError.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      selections:
          (json['selections'] as List<dynamic>?)
              ?.map((s) => OrderSelection.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'order_id': orderId,
    'success': success,
    'message': message,
    'matched': matched,
    'failed': failed,
    'errors': errors.map((e) => e.toJson()).toList(),
    'selections': selections.map((s) => s.toJson()).toList(),
  };
}

class PlaceOrderError {
  final String copvsId;
  final String produceId;
  final String form;
  final double requestedQty;
  final double unfulfilledQty;
  final String reason;

  PlaceOrderError({
    required this.copvsId,
    required this.produceId,
    required this.form,
    required this.requestedQty,
    required this.unfulfilledQty,
    required this.reason,
  });

  factory PlaceOrderError.fromJson(Map<String, dynamic> json) {
    return PlaceOrderError(
      copvsId: json['copvs_id']?.toString() ?? '',
      produceId: json['produce_id']?.toString() ?? '',
      form: json['form']?.toString() ?? '',
      requestedQty: (json['requested_qty'] as num?)?.toDouble() ?? 0.0,
      unfulfilledQty: (json['unfulfilled_qty'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'copvs_id': copvsId,
    'produce_id': produceId,
    'form': form,
    'requested_qty': requestedQty,
    'unfulfilled_qty': unfulfilledQty,
    'reason': reason,
  };
}

class OrderSelection {
  final String covId;
  final String varietyId;
  final String varietyName;
  final double allocatedQty;
  final String farmerId;
  final double distanceKm;
  final String availableFrom;
  final String availableTo;
  final bool chosen;
  final String reason;

  OrderSelection({
    required this.covId,
    required this.varietyId,
    required this.varietyName,
    required this.allocatedQty,
    required this.farmerId,
    required this.distanceKm,
    required this.availableFrom,
    required this.availableTo,
    required this.chosen,
    required this.reason,
  });

  factory OrderSelection.fromJson(Map<String, dynamic> json) {
    return OrderSelection(
      covId: json['cov_id']?.toString() ?? '',
      varietyId: json['variety_id']?.toString() ?? '',
      varietyName: json['variety_name']?.toString() ?? '',
      allocatedQty: (json['allocated_qty'] as num?)?.toDouble() ?? 0.0,
      farmerId: json['farmer_id']?.toString() ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      availableFrom: json['available_from']?.toString() ?? '',
      availableTo: json['available_to']?.toString() ?? '',
      chosen: json['chosen'] == true,
      reason: json['reason']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'cov_id': covId,
    'variety_id': varietyId,
    'variety_name': varietyName,
    'allocated_qty': allocatedQty,
    'farmer_id': farmerId,
    'distance_km': distanceKm,
    'available_from': availableFrom,
    'available_to': availableTo,
    'chosen': chosen,
    'reason': reason,
  };
}
