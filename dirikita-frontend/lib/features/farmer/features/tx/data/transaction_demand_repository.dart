import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:flutter/material.dart'; // For DateUtils
import 'dart:math' as math;
import 'transaction_draft_service.dart'; // For DateDemandData

class TransactionDemandRepository {
  // Fetch simulated demand for a whole month
  // Returns Map<DateTime, DateDemandData>
  Future<Map<DateTime, DateDemandData>> fetchMonthlyDemand(
    String cropId,
    int year,
    int month,
  ) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 600));

    final rng = math.Random(
      year * 100 + month + cropId.hashCode,
    ); // Consistent seed per month/crop

    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final results = <DateTime, DateDemandData>{};

    // We fetch produce once to generate valid breakdown mock
    // In real app, backend would return this.
    try {
      final produceRepo = ProduceRepository();
      final allProduce = await produceRepo.getAllProduce();
      final produce = allProduce.firstWhere((p) => p.id == cropId);

      for (int day = 1; day <= daysInMonth; day++) {
        // 70% chance of having demand
        if (rng.nextDouble() > 0.3) {
          final date = DateTime(year, month, day);
          final dateRng = math.Random(date.hashCode + cropId.hashCode);

          double seasonMultiplier = 1.0 + (dateRng.nextDouble() * 0.4) - 0.2;
          double totalDemand = 0;
          double totalFulfilled = 0;

          final breakdown = produce.availableVarieties.map((variety) {
            double basePrice = produce.pricingEconomics.duruhaFarmerPayout;
            double varietyPrice = basePrice + variety.priceModifier;
            double finalPrice = varietyPrice * seasonMultiplier;

            double demand = (100 + dateRng.nextInt(4900)).toDouble();
            double fulfilledPct = dateRng.nextDouble() > 0.8
                ? 1.0
                : (dateRng.nextDouble() * 0.9);

            double fulfilled = demand * fulfilledPct;
            totalDemand += demand;
            totalFulfilled += fulfilled;

            return <String, dynamic>{
              'variant': variety.name,
              'price': finalPrice,
              'demand_kg': demand,
              'fulfilled_kg': fulfilled,
            };
          }).toList();

          results[date] = DateDemandData(
            totalDemand: totalDemand,
            totalFulfilled: totalFulfilled,
            varietyBreakdown: breakdown,
          );
        }
      }
    } catch (e) {
      // Fail silently or return empty
    }

    return results;
  }

  // Deterministically generate demand for a specific date
  Future<DateDemandData> getDetailedDemand(String cropId, DateTime date) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 400));

    // We need the produce info to get varieties.
    // Ideally we cache this or fetch it.
    try {
      final produceRepo = ProduceRepository();
      final allProduce = await produceRepo.getAllProduce();
      final produce = allProduce.firstWhere(
        (p) => p.id == cropId,
        orElse: () => throw Exception("Crop not found"),
      );

      final rng = math.Random(date.hashCode + cropId.hashCode);

      // Seasonality
      double seasonMultiplier = 1.0 + (rng.nextDouble() * 0.4) - 0.2;

      double totalDemand = 0;
      double totalFulfilled = 0;

      final breakdown = produce.availableVarieties.map((variety) {
        double basePrice = produce.pricingEconomics.duruhaFarmerPayout;
        double varietyPrice = basePrice + variety.priceModifier;
        double finalPrice = varietyPrice * seasonMultiplier;

        double demand = (100 + rng.nextInt(4900)).toDouble();
        double fulfilledPct = rng.nextDouble() > 0.8
            ? 1.0
            : (rng.nextDouble() * 0.9);

        double fulfilled = demand * fulfilledPct;

        totalDemand += demand;
        totalFulfilled += fulfilled;

        return <String, dynamic>{
          'variant': variety.name,
          'price': finalPrice,
          'demand_kg': demand,
          'fulfilled_kg': fulfilled,
        };
      }).toList();

      return DateDemandData(
        totalDemand: totalDemand,
        totalFulfilled: totalFulfilled,
        varietyBreakdown: breakdown,
      );
    } catch (e) {
      // Fallback
      return DateDemandData(
        totalDemand: 0,
        totalFulfilled: 0,
        varietyBreakdown: [],
      );
    }
  }
}
