import 'package:flutter/material.dart';

class DeliveryStatus {
  static const String pending = 'PENDING';
  static const String accepted = 'ACCEPTED';
  static const String preparing = 'PREPARING';
  static const String readyForQc = 'READY_FOR_QC';
  static const String qcPassed = 'QC_PASSED';
  static const String dispatched = 'DISPATCHED';
  static const String inTransitToHub = 'IN_TRANSIT_TO_HUB';
  static const String arrivedAtHub = 'ARRIVED_AT_HUB';
  static const String sorting = 'SORTING';
  static const String outForDelivery = 'OUT_FOR_DELIVERY';
  static const String arrived = 'ARRIVED';
  static const String delivered = 'DELIVERED';
  static const String qcRejected = 'QC_REJECTED';
  static const String cancelled = 'CANCELLED';
  static const String returned = 'RETURNED';

  static const List<String> all = [
    pending,
    accepted,
    preparing,
    readyForQc,
    qcPassed,
    dispatched,
    inTransitToHub,
    arrivedAtHub,
    sorting,
    outForDelivery,
    arrived,
    delivered,
    qcRejected,
    cancelled,
    returned,
  ];

  static const List<String> farmerEditable = [
    pending,
    accepted,
    preparing,
    readyForQc,
  ];

  static Color getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    final normalized = status.toUpperCase();

    switch (normalized) {
      case delivered:
        return Colors.green;
      case arrived:
      case arrivedAtHub:
        return Colors.teal;
      case dispatched:
      case inTransitToHub:
      case outForDelivery:
        return Colors.blue;
      case cancelled:
      case qcRejected:
      case returned:
        return Colors.red;
      case preparing:
        return Colors.lightGreen;
      case sorting:
        return Colors.grey;
      case readyForQc:
        return Colors.orange;
      case qcPassed:
        return Colors.yellow[700]!;
      case pending:
        return Colors.grey;
      case accepted:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  static String getDisplayLabel(String status) {
    return status.replaceAll('_', ' ');
  }
}
