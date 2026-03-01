class HarvestEntry {
  final DateTime date;
  final String variety;
  final double quantity;
  final double? earnings;
  final bool isCompleted;

  HarvestEntry({
    required this.date,
    required this.variety,
    required this.quantity,
    this.earnings,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'variety': variety,
    'quantity': quantity,
    'earnings': earnings,
    'is_completed': isCompleted,
  };

  factory HarvestEntry.fromJson(Map<String, dynamic> json) => HarvestEntry(
    date: DateTime.parse(json['date']),
    variety: json['variety'],
    quantity: (json['quantity'] as num).toDouble(),
    earnings: json['earnings'] != null
        ? (json['earnings'] as num).toDouble()
        : null,
    isCompleted: json['is_completed'] ?? false,
  );
}

class HarvestPledge {
  final String? id;
  final String? cropId;
  final String cropName;
  final String? cropNameDialect;
  final List<String> variants;
  final DateTime harvestDate;
  final double quantity;
  final String unit;
  final String farmerId;
  final String targetMarket;
  final DateTime? createdAt;
  final String currentStatus;
  final double totalExpenses;
  final double? sellingPrice;
  final String imageUrl;
  final DateTime? availableDate;
  final DateTime? disposalDate;
  final Map<String, double>? varietyQuantities;
  final List<HarvestEntry>? perDatePledges;
  final List<DateTime>? completedDates;
  final Map<String, DateTime?>? varietyAvailableDates;
  final Map<String, DateTime?>? varietyDisposalDates;

  HarvestPledge({
    this.id,
    this.cropId,
    required this.cropName,
    this.cropNameDialect,
    required this.variants,
    required this.harvestDate,
    required this.quantity,
    required this.unit,
    required this.farmerId,
    required this.targetMarket,
    this.createdAt,
    this.currentStatus = 'Set',
    this.totalExpenses = 0.0,
    this.sellingPrice,
    this.imageUrl = 'assets/images/placeholder.png',
    this.availableDate,
    this.disposalDate,
    this.varietyQuantities,
    this.perDatePledges,
    this.completedDates,
    this.varietyAvailableDates,
    this.varietyDisposalDates,
  });

  /// Compatibility getter to return the old structure: `Map<DateTime, Map<String, double>>`
  Map<DateTime, Map<String, double>> get perDatePledgesMap {
    if (perDatePledges == null) return {};
    final map = <DateTime, Map<String, double>>{};
    for (var entry in perDatePledges!) {
      final normalizedDate = DateTime(
        entry.date.year,
        entry.date.month,
        entry.date.day,
      );
      map.putIfAbsent(normalizedDate, () => {});
      map[normalizedDate]![entry.variety] = entry.quantity;
    }
    return map;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'crop_id': cropId,
    'crop_name': cropName,
    'crop_name_dialect': cropNameDialect,
    'selected_variants': variants,
    'harvest_date': harvestDate.toIso8601String(),
    'available_date': availableDate?.toIso8601String(),
    'disposal_date': disposalDate?.toIso8601String(),
    'variety_quantities': varietyQuantities,
    'per_date_pledges': perDatePledges?.map((e) => e.toJson()).toList(),
    'completed_dates': completedDates?.map((d) => d.toIso8601String()).toList(),
    'quantity': quantity,
    'unit': unit,
    'farmer_id': farmerId,
    'target_market': targetMarket,
    'current_status': currentStatus,
    'total_expenses': totalExpenses,
    'selling_price': sellingPrice,
    'image_url': imageUrl,
    'created_at':
        createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    'variety_available_dates': varietyAvailableDates?.map(
      (key, value) => MapEntry(key, value?.toIso8601String()),
    ),
    'variety_disposal_dates': varietyDisposalDates?.map(
      (key, value) => MapEntry(key, value?.toIso8601String()),
    ),
  };
}

class TransactionRequest {
  final String mode; // 'pledge' or 'offer'
  final List<HarvestPledge> pledges;

  TransactionRequest({required this.mode, required this.pledges});

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'pledges': pledges.map((p) => p.toJson()).toList(),
  };
}
