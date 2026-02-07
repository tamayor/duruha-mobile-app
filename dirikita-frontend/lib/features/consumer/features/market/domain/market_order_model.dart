import 'package:duruha/core/helpers/duruha_status_helper.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';

enum ProduceClass {
  A('A', 'Premium Quality', 1.0),
  B('B', 'Good Quality', 0.85),
  C('C', 'Standard Quality', 0.70);

  final String code;
  final String label;
  final double multiplier;

  const ProduceClass(this.code, this.label, this.multiplier);
}

enum PaymentOption {
  downPayment('20% Down Payment', 0.20),
  fullPayment('Full Payment', 1.0);

  final String label;
  final double percentage;

  const PaymentOption(this.label, this.percentage);
}

enum DeliveryFrequency {
  once('Once'),
  weekly('Weekly'),
  biWeekly('Every 2 weeks'),
  monthly('Monthly');

  final String label;
  const DeliveryFrequency(this.label);
}

class SupplySchedule {
  final DateTime preferredStartDate;
  final DateTime? preferredEndDate; // Null means "Until Cancelled"
  final DeliveryFrequency frequency;
  final List<int> preferredDaysOfWeek; // 1 (Mon) to 7 (Sun)

  SupplySchedule({
    required this.preferredStartDate,
    this.preferredEndDate,
    this.frequency = DeliveryFrequency.once,
    this.preferredDaysOfWeek = const [],
  });

  // Helper names for days
  static const List<String> dayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  int get occurrences {
    if (frequency == DeliveryFrequency.once) return 1;
    if (preferredEndDate == null) return -1; // -1 represents "Infinity"

    int count = 0;
    DateTime current = preferredStartDate;

    // If specific days are picked, potentially shift the 'base' start to the first occurrence
    if (preferredDaysOfWeek.isNotEmpty &&
        !preferredDaysOfWeek.contains(current.weekday)) {
      int safetyShift = 0;
      while (!preferredDaysOfWeek.contains(current.weekday) &&
          (preferredEndDate == null || current.isBefore(preferredEndDate!))) {
        current = current.add(const Duration(days: 1));
        safetyShift++;
        if (safetyShift > 31) break; // Don't shift further than a month
      }
    }

    // Safety break at 1000 to prevent infinite loops in UI
    int safety = 0;
    while (current.isBefore(preferredEndDate!) ||
        current.isAtSameMomentAs(preferredEndDate!)) {
      if (preferredDaysOfWeek.isEmpty ||
          preferredDaysOfWeek.contains(current.weekday)) {
        count++;
      }

      if (frequency == DeliveryFrequency.weekly) {
        current = current.add(const Duration(days: 7));
      } else if (frequency == DeliveryFrequency.biWeekly) {
        current = current.add(const Duration(days: 14));
      } else if (frequency == DeliveryFrequency.monthly) {
        // For monthly, we increment the month.
        // If they also picked a day, it might skip months if that day isn't found?
        // Usually day-of-week + monthly = "First Monday of month".
        // For now, we keep it simple: check the same date next month.
        current = DateTime(current.year, current.month + 1, current.day);
      } else {
        break;
      }

      safety++;
      if (safety > 1000) break;
    }
    return count;
  }

  Map<String, dynamic> toJson() => {
    'preferredStartDate': preferredStartDate.toIso8601String(),
    'preferredEndDate': preferredEndDate?.toIso8601String(),
    'frequency': frequency.name,
    'preferredDaysOfWeek': preferredDaysOfWeek,
    'calculatedOccurrences': occurrences,
  };
}

class MarketProduceItem {
  final Produce produce;
  final bool isLocallyAvailable;
  final String farmerLocation; // e.g., "Tubungan, Iloilo"
  final DateTime? estimatedHarvestDate;
  final double? availableQuantityKg;

  MarketProduceItem({
    required this.produce,
    required this.isLocallyAvailable,
    required this.farmerLocation,
    this.estimatedHarvestDate,
    this.availableQuantityKg,
  });
}

class OrderItem {
  final Produce produce;
  final List<String>? _selectedVarieties;
  List<String> get selectedVarieties => _selectedVarieties ?? const [];
  final List<ProduceClass>? _selectedClasses;
  List<ProduceClass> get selectedClasses => _selectedClasses ?? const [];
  final double quantityKg;
  final PaymentOption paymentOption;

  OrderItem({
    required this.produce,
    required List<String> selectedVarieties,
    required List<ProduceClass> selectedClasses,
    required this.quantityKg,
    required this.paymentOption,
  }) : _selectedVarieties = selectedVarieties,
       _selectedClasses = selectedClasses;

  double get minTotalPrice {
    double minBase = produce.pricingEconomics.duruhaConsumerPrice;
    if (selectedVarieties.isNotEmpty) {
      final basePrice = produce.pricingEconomics.duruhaConsumerPrice;
      final selectedPrices = produce.availableVarieties
          .where((v) => selectedVarieties.contains(v.name))
          .map((v) => basePrice + v.priceModifier);
      if (selectedPrices.isNotEmpty) {
        minBase = selectedPrices.reduce((a, b) => a < b ? a : b);
      }
    }

    double multiplier = 1.0;
    if (selectedClasses.isNotEmpty) {
      multiplier = selectedClasses
          .map((c) => c.multiplier)
          .reduce((a, b) => a < b ? a : b);
    }
    return minBase * quantityKg * multiplier;
  }

  // Calculate total price for this item (using max for safe estimation)
  double get totalPrice {
    double basePrice = produce.pricingEconomics.duruhaConsumerPrice;
    if (selectedVarieties.isNotEmpty) {
      final bPrice = produce.pricingEconomics.duruhaConsumerPrice;
      final selectedPrices = produce.availableVarieties
          .where((v) => selectedVarieties.contains(v.name))
          .map((v) => bPrice + v.priceModifier);
      if (selectedPrices.isNotEmpty) {
        basePrice = selectedPrices.reduce((a, b) => a > b ? a : b);
      }
    }

    double multiplier = 1.0;
    if (selectedClasses.isNotEmpty) {
      // Use the highest multiplier (highest quality) among selected classes
      multiplier = selectedClasses
          .map((c) => c.multiplier)
          .reduce((a, b) => a > b ? a : b);
    }
    return basePrice * quantityKg * multiplier;
  }

  // Calculate amount due now based on payment option
  double get amountDueNow {
    if (paymentOption == PaymentOption.downPayment) {
      // 20% of minimum payment
      return minTotalPrice * 0.20;
    }
    return totalPrice; // Full payment
  }

  // Check if the order item is complete
  bool get isComplete {
    return selectedVarieties.isNotEmpty && quantityKg > 0;
  }
}

class MarketOrder {
  final String id;
  final String batchId; // Logistics tracking
  final List<OrderItem> items;
  final DateTime createdAt;
  final String status; // Legacy/Display status
  final DuruhaOrderStatus orderStatus; // Systematic tracking
  final String? farmerName; // Farmer assigned to this order
  final DateTime? estimatedDeliveryDate; // For countdown
  final SupplySchedule? supplySchedule;
  final List<Map<String, dynamic>>? batches;

  MarketOrder({
    required this.id,
    required this.batchId,
    required this.items,
    required this.createdAt,
    this.status = 'pending',
    this.orderStatus = DuruhaOrderStatus.searching,
    this.farmerName,
    this.estimatedDeliveryDate,
    this.supplySchedule,
    this.batches,
  });

  double get minSubtotal {
    return items.fold(0.0, (sum, item) => sum + item.minTotalPrice);
  }

  // Calculate subtotal for all items
  double get subtotal {
    return items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  // Calculate total amount due now
  double get totalDueNow {
    return items.fold(0.0, (sum, item) => sum + item.amountDueNow);
  }

  // Calculate remaining balance
  double get remainingBalance {
    return subtotal - totalDueNow;
  }

  // Check if all items are complete
  bool get isComplete {
    return items.isNotEmpty && items.every((item) => item.isComplete);
  }
}
