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
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'crop_id': cropId,
    'crop_name': cropName,
    'crop_name_dialect': cropNameDialect,
    'selected_variants': variants,
    'harvest_date': harvestDate.toIso8601String(),
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
  };
}
