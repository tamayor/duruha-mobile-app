import 'package:duruha/core/helpers/duruha_status_helper.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';

enum DeliveryFrequency {
  once('Once'),
  weekly('Weekly'),
  biweekly('Bi-weekly'),
  monthly('Monthly');

  final String label;
  const DeliveryFrequency(this.label);
}

enum PaymentOption {
  fullPayment('Full Payment'),
  downPayment('Down Payment');

  final String label;
  const PaymentOption(this.label);
}

enum ProduceClass {
  A('A'),
  B('B'),
  C('C');

  final String code;
  const ProduceClass(this.code);
}

class SupplySchedule {
  final DateTime preferredStartDate;
  final DeliveryFrequency frequency;
  final DateTime? preferredEndDate;
  final int occurrences;

  SupplySchedule({
    required this.preferredStartDate,
    required this.frequency,
    this.preferredEndDate,
    this.occurrences = 1,
  });
}

class OrderItem {
  final Produce produce;
  final List<String> selectedVarieties;
  final List<ProduceClass> selectedClasses;
  final double quantityKg;
  final PaymentOption paymentOption;

  OrderItem({
    required this.produce,
    required this.selectedVarieties,
    required this.selectedClasses,
    required this.quantityKg,
    required this.paymentOption,
  });

  double get totalPrice {
    // Fallback to a base price if pricingEconomics is not available or handled via extensions
    return quantityKg * (produce.id.hashCode % 100 + 50).toDouble();
  }
}

class MarketOrder {
  final String id;
  final String batchId;
  final DateTime createdAt;
  final String status;
  final DuruhaOrderStatus orderStatus;
  final String? farmerName;
  final DateTime? estimatedDeliveryDate;
  final SupplySchedule? supplySchedule;
  final List<OrderItem> items;
  final List<Map<String, dynamic>>? batches;

  MarketOrder({
    required this.id,
    required this.batchId,
    required this.createdAt,
    required this.status,
    required this.orderStatus,
    this.farmerName,
    this.estimatedDeliveryDate,
    this.supplySchedule,
    required this.items,
    this.batches,
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.totalPrice);
  double get minSubtotal => subtotal; // Simplified for now
}
