import 'package:flutter/material.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import '../data/transaction_draft_service.dart';

class CropSelectionState {
  final TextEditingController dateController;

  // Multi-selection for harvest dates (plan mode)
  List<DateTime> selectedHarvestDates = [];

  // Per-variety dates
  Map<String, DateTime?> varietyAvailableDates = {};
  Map<String, DateTime?> varietyDisposalDates = {};
  Map<String, DateTime?> varietyDateNeeded = {};

  // rrule string per variety/input key (plan mode recurring schedules)
  Map<String, String?> varietyRecurrence = {};

  // Price lock toggles per variety/group key
  Map<String, bool> varietyPriceLock = {};

  // Track selected listing/form ID per variety (Key: variety name, Value: listing_id)
  Map<String, String?> varietySelectedFormId = {};

  String selectedUnit;
  List<String> selectedVariants;
  Map<String, TextEditingController> varietyQuantityControllers;
  List<Map<String, dynamic>>? simulatedDemand;

  // Map of Date → demand data (used during demand preview)
  Map<DateTime, DateDemandData> dateSpecificDemand = {};

  // Harvest pledge entries (plan/pledge mode)
  List<HarvestEntry> perDatePledges = [];

  // Grouped varieties — for "Any in [A || B]" grouping logic
  List<Set<String>> varietyGroups = [];

  // Field-level validation errors (Key: input key, Value: error message)
  Map<String, String?> validationErrors = {};

  bool isLoadingDemand = false;

  CropSelectionState({
    required this.dateController,
    required this.selectedUnit,
    required this.selectedVariants,
    Map<String, TextEditingController>? varietyQuantityControllers,
    Map<String, String?>? varietySelectedFormId,
    Map<String, DateTime?>? varietyAvailableDates,
    Map<String, DateTime?>? varietyDisposalDates,
    Map<String, DateTime?>? varietyDateNeeded,
    Map<String, String?>? varietyRecurrence,
    Map<String, bool>? varietyPriceLock,
  }) : varietyQuantityControllers = varietyQuantityControllers ?? {},
       varietySelectedFormId = varietySelectedFormId ?? {},
       varietyAvailableDates = varietyAvailableDates ?? {},
       varietyDisposalDates = varietyDisposalDates ?? {},
       varietyDateNeeded = varietyDateNeeded ?? {},
       varietyRecurrence = varietyRecurrence ?? {},
       varietyPriceLock = varietyPriceLock ?? {};

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
    if (perDatePledges.isNotEmpty) {
      return perDatePledges.fold(0, (sum, e) => sum + e.quantity);
    }
    double total = 0;
    for (var controller in varietyQuantityControllers.values) {
      total += double.tryParse(controller.text) ?? 0;
    }
    return total;
  }
}
