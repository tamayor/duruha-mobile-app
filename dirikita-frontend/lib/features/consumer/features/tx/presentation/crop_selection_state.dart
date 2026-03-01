import 'package:flutter/material.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import '../data/transaction_draft_service.dart';

class CropSelectionState {
  final TextEditingController dateController;
  // Multi-selection for harvest dates
  List<DateTime> selectedHarvestDates = [];
  // Removed single harvestDate and harvestWindow in favor of list
  // DateTime? harvestDate;
  // DateTimeRange? harvestWindow;
  // Per-variety availability dates (for Offer mode)
  Map<String, DateTime?> varietyAvailableDates = {};
  Map<String, DateTime?> varietyDisposalDates = {};
  Map<String, DateTime?> varietyDateNeeded = {};
  // Track selected listing/form ID per variety (Key: variety name/id, Value: listing_id)
  Map<String, String?> varietySelectedFormId = {};
  // Track price lock status per variety/item
  Map<String, bool> varietyPriceLock = {};
  String selectedUnit;
  List<String> selectedVariants;
  Map<String, TextEditingController> varietyQuantityControllers;
  List<Map<String, dynamic>>? simulatedDemand;
  // Map of Date -> Total Demand (sum of all varieties)
  Map<DateTime, DateDemandData> dateSpecificDemand = {};

  // List of harvest entries
  List<HarvestEntry> perDatePledges = [];

  // Grouped varieties (for Order mode persistence)
  List<Set<String>> varietyGroups = [];

  // Validation errors (Key: input key, Value: error message)
  Map<String, String?> validationErrors = {};

  bool isLoadingDemand = false;
  List<String> qualityPreferences = ['Select', 'Regular'];
  double qualityFee = 0.05;

  CropSelectionState({
    required this.dateController,
    required this.selectedUnit,
    required this.selectedVariants,
    Map<String, TextEditingController>? varietyQuantityControllers,
    Map<String, String?>? varietySelectedFormId,
    Map<String, bool>? varietyPriceLock,
    Map<String, DateTime?>? varietyAvailableDates,
    Map<String, DateTime?>? varietyDisposalDates,
    Map<String, DateTime?>? varietyDateNeeded,
  }) : varietyQuantityControllers = varietyQuantityControllers ?? {},
       varietySelectedFormId = varietySelectedFormId ?? {},
       varietyPriceLock = varietyPriceLock ?? {},
       varietyAvailableDates = varietyAvailableDates ?? {},
       varietyDisposalDates = varietyDisposalDates ?? {},
       varietyDateNeeded = varietyDateNeeded ?? {};

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
