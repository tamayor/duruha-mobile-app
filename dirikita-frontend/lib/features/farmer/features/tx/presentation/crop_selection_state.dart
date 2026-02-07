import 'package:flutter/material.dart';
import '../../../shared/domain/pledge_model.dart';
import '../data/transaction_draft_service.dart';

class CropSelectionState {
  final TextEditingController dateController;
  // Multi-selection for harvest dates
  List<DateTime> selectedHarvestDates = [];
  // Removed single harvestDate and harvestWindow in favor of list
  // DateTime? harvestDate;
  // DateTimeRange? harvestWindow;
  DateTime? availableDate;
  DateTime? disposalDate;
  String selectedUnit;
  List<String> selectedVariants;
  Map<String, TextEditingController> varietyQuantityControllers;
  List<Map<String, dynamic>>? simulatedDemand;
  // Map of Date -> Total Demand (sum of all varieties)
  Map<DateTime, DateDemandData> dateSpecificDemand = {};

  // List of harvest entries
  List<HarvestEntry> perDatePledges = [];

  bool isLoadingDemand = false;

  CropSelectionState({
    required this.dateController,
    required this.selectedUnit,
    required this.selectedVariants,
    this.varietyQuantityControllers = const {},
  });

  Map<DateTime, Map<String, double>> get perDatePledgesMap {
    final map = <DateTime, Map<String, double>>{};
    for (var entry in perDatePledges) {
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

  double get totalQuantity {
    double total = 0;
    if (perDatePledges.isNotEmpty) {
      total = perDatePledges.fold(0, (sum, e) => sum + e.quantity);
    } else {
      for (var controller in varietyQuantityControllers.values) {
        total += double.tryParse(controller.text) ?? 0;
      }
    }
    return total;
  }
}
