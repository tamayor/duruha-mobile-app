class HarvestPledge {
  final String? cropId;
  final String cropName;
  final List<String> variants;
  final DateTime plantingDate;
  final double quantity;
  final String unit;
  final String farmerId;
  final String targetMarket;

  HarvestPledge({
    this.cropId,
    required this.cropName,
    required this.variants,
    required this.plantingDate,
    required this.quantity,
    required this.unit,
    required this.farmerId,
    required this.targetMarket,
  });

  Map<String, dynamic> toJson() => {
    'crop_id': cropId,
    'crop_name': cropName,
    'selected_variants': variants,
    'planting_date': plantingDate.toIso8601String(),
    'quantity': quantity,
    'unit': unit,
    'farmer_id': farmerId,
    'target_market': targetMarket,
    'timestamp': DateTime.now().toIso8601String(),
  };
}
