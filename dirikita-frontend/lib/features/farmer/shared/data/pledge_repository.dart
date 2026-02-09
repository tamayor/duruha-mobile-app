import '../domain/pledge_model.dart';
// import 'package:duruha/shared/produce/data/produce_repository.dart';
// import 'dart:math' as math;
// import 'package:flutter/material.dart';

class PledgeRepository {
  // Simulate an API call (Legacy/Individual)
  Future<bool> createPledge(HarvestPledge pledge) async {
    try {
      // ignore: avoid_print
      print("🚀 [API REQUEST] Sending to Backend: ${pledge.toJson()}");

      // Replace with your actual http.post or dio.post call
      await Future.delayed(const Duration(seconds: 2));

      return true; // Success
    } catch (e) {
      // ignore: avoid_print
      print("❌ [API ERROR]: $e");
      return false;
    }
  }

  /// Simulate fetching all pledges for the current user
  Future<List<HarvestPledge>> fetchMyPledges() async {
    await Future.delayed(const Duration(milliseconds: 1000));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return [
      // 1. GROWING - Onion
      HarvestPledge(
        id: 'PLEDGE-001',
        cropId: 'prod_010',
        cropName: 'Onion',
        cropNameDialect: 'Sulyaw',
        variants: ['Red Pinoy', 'White Granex'],
        harvestDate: today.add(const Duration(days: 45)),
        quantity: 500,
        unit: 'kg',
        farmerId: 'farmer-123',
        targetMarket: 'Local',
        createdAt: now.subtract(const Duration(days: 15)),
        currentStatus: 'Grow',
        totalExpenses: 12500.0,
        sellingPrice: 0.0, // Not yet sold
        imageUrl:
            'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?w=900&auto=format&fit=crop',
        perDatePledges: [
          HarvestEntry(
            date: today.add(const Duration(days: 45)),
            variety: 'Red Pinoy',
            quantity: 250,
            isCompleted: false,
            earnings: 0.0,
          ),
          HarvestEntry(
            date: today.add(const Duration(days: 48)),
            variety: 'White Granex',
            quantity: 250,
            isCompleted: false,
            earnings: 0.0,
          ),
        ],
      ),

      // 2. FINISHED - Bird's Eye Chili
      // Consistent: 6000 + 6000 + 6000 = 18000
      HarvestPledge(
        id: 'PLEDGE-FINISHED',
        cropId: 'prod_003',
        cropName: "Bird's Eye Chili",
        cropNameDialect: 'Siling Labuyo',
        variants: ['Native', 'Todos'],
        harvestDate: today.subtract(const Duration(days: 3)),
        quantity: 80,
        unit: 'kg',
        farmerId: 'farmer-123',
        targetMarket: 'National',
        createdAt: now.subtract(const Duration(days: 60)),
        currentStatus: 'Done',
        totalExpenses: 3200.0,
        sellingPrice: 18000.0,
        imageUrl:
            'https://images.unsplash.com/photo-1546860255-95536c19724e?w=900&auto=format&fit=crop',
        perDatePledges: [
          HarvestEntry(
            date: today.subtract(const Duration(days: 7)),
            variety: 'Native',
            quantity: 30,
            isCompleted: true,
            earnings: 6000.0,
          ),
          HarvestEntry(
            date: today.subtract(const Duration(days: 7)),
            variety: 'Todos',
            quantity: 30,
            isCompleted: true,
            earnings: 6000.0,
          ),
          HarvestEntry(
            date: today.subtract(const Duration(days: 3)),
            variety: 'Native',
            quantity: 20,
            isCompleted: true,
            earnings: 6000.0,
          ),
        ],
      ),

      // 3. SOLD - Tomato
      // Consistent: 12000 = 12000
      HarvestPledge(
        id: 'PLEDGE-003',
        cropId: 'prod_001',
        cropName: 'Tomato',
        cropNameDialect: 'Kamatis',
        variants: ['Diamante'],
        harvestDate: today.subtract(const Duration(days: 10)),
        quantity: 200,
        unit: 'kg',
        farmerId: 'farmer-123',
        targetMarket: 'Local',
        createdAt: now.subtract(const Duration(days: 90)),
        currentStatus: 'Sold',
        totalExpenses: 4500.0,
        sellingPrice: 12000.0,
        imageUrl:
            'https://images.unsplash.com/photo-1607305387299-a3d9611cd469?q=80&w=2370&auto=format&fit=crop',
        perDatePledges: [
          HarvestEntry(
            date: today.subtract(const Duration(days: 10)),
            variety: 'Diamante',
            quantity: 200,
            isCompleted: true,
            earnings: 12000.0,
          ),
        ],
      ),

      // 6. SOLD - Eggplant
      // Consistent: 3000 + 3000 = 6000
      HarvestPledge(
        id: 'PLEDGE-006',
        cropId: 'prod_002',
        cropName: 'Eggplant',
        cropNameDialect: 'Talong',
        variants: ['Long Purple'],
        harvestDate: today.subtract(const Duration(days: 1)),
        quantity: 150,
        unit: 'kg',
        farmerId: 'farmer-123',
        targetMarket: 'Local',
        createdAt: now.subtract(const Duration(days: 45)),
        currentStatus: 'Sold',
        totalExpenses: 3500.0,
        sellingPrice: 6000.0,
        imageUrl:
            'https://images.unsplash.com/photo-1615485290382-441e4d0c9cb5?w=900&auto=format&fit=crop',
        perDatePledges: [
          HarvestEntry(
            date: today.subtract(const Duration(days: 1)),
            variety: 'Long Purple',
            quantity: 75,
            isCompleted: true,
            earnings: 3000.0,
          ),
          HarvestEntry(
            date: today.subtract(const Duration(days: 1)),
            variety: 'Long Purple',
            quantity: 75,
            isCompleted: true,
            earnings: 3000.0,
          ),
        ],
      ),
    ];
  }

  // Update pledge status
  Future<bool> updatePledgeStatus(
    String pledgeId,
    String newStatus, {
    String? notes,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    // In a real app, this would send an HTTP PATCH/PUT request
    //print(
    //  "🔄 [API] Updated Status for $pledgeId to $newStatus (Notes: $notes)",
    //);
    return true;
  }

  // Add an expense to the pledge
  Future<bool> addExpense(
    String pledgeId,
    Map<String, dynamic> expenseData,
  ) async {
    await Future.delayed(const Duration(seconds: 1));
    //print("💰 [API] Added Expense for $pledgeId: $expenseData");
    return true;
  }

  // Update an expense
  Future<bool> updateExpense(
    String pledgeId,
    Map<String, dynamic> expenseData,
  ) async {
    await Future.delayed(const Duration(seconds: 1));
    //print("✏️ [API] Updated Expense for $pledgeId: $expenseData");
    return true;
  }

  // Delete an expense
  Future<bool> deleteExpense(String pledgeId, String expenseId) async {
    await Future.delayed(const Duration(seconds: 1));
    //print("🗑️ [API] Deleted Expense $expenseId from $pledgeId");
    return true;
  }

  // Delete a status history entry (revert status)
  Future<bool> deleteStatusEntry(String pledgeId, String statusId) async {
    await Future.delayed(const Duration(seconds: 1));
    //print("rewind [API] Deleted Status Entry $statusId from $pledgeId");
    return true;
  }

  // Toggle harvest date completion
  Future<bool> toggleHarvestDateStatus(
    String pledgeId,
    DateTime date,
    bool isCompleted,
  ) async {
    await Future.delayed(const Duration(seconds: 1));
    // ignore: avoid_print
    print(
      "✅ [API] Toggled Harvest Date Status for $pledgeId: ${date.toIso8601String()} -> $isCompleted",
    );
    return true;
  }
}
