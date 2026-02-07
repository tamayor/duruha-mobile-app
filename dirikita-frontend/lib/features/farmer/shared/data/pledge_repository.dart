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

  // Simulate fetching all pledges for the current user
  Future<List<HarvestPledge>> fetchMyPledges() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1000));

    final now = DateTime.now();

    return [
      // 1. GROWING - Onion
      HarvestPledge(
        id: 'PLEDGE-001',
        cropId: 'prod_010',
        cropName: 'Onion',
        cropNameDialect: 'Sulyaw',
        variants: ['Red Pinoy', 'White Granex'],
        harvestDate: now.add(const Duration(days: 45)),
        quantity: 500,
        unit: 'kg',
        farmerId: 'farmer-123',
        targetMarket: 'Local',
        createdAt: now.subtract(const Duration(days: 15)),
        currentStatus: 'Grow',
        totalExpenses: 12500.0,
        imageUrl:
            'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?w=900&auto=format&fit=crop',
        perDatePledges: [
          HarvestEntry(
            date: DateTime(
              now.year,
              now.month,
              now.day,
            ).add(const Duration(days: 45)),
            variety: 'Red Pinoy',
            quantity: 200,
          ),
          HarvestEntry(
            date: DateTime(
              now.year,
              now.month,
              now.day,
            ).add(const Duration(days: 45)),
            variety: 'White Granex',
            quantity: 100,
          ),
          HarvestEntry(
            date: DateTime(
              now.year,
              now.month,
              now.day,
            ).add(const Duration(days: 48)),
            variety: 'Red Pinoy',
            quantity: 150,
          ),
          HarvestEntry(
            date: DateTime(
              now.year,
              now.month,
              now.day,
            ).add(const Duration(days: 48)),
            variety: 'White Granex',
            quantity: 50,
          ),
        ],
        completedDates: [
          DateTime(now.year, now.month, now.day).add(const Duration(days: 45)),
        ],
      ),

      // 2. READY TO HARVEST - Chili
      HarvestPledge(
        id: 'PLEDGE-002',
        cropId: 'prod_003',
        cropName: "Bird's Eye Chili",
        cropNameDialect: 'Siling Labuyo',
        variants: ['Native'],
        harvestDate: now.add(const Duration(days: 3)),
        quantity: 50,
        unit: 'kg',
        farmerId: 'farmer-123',
        targetMarket: 'National',
        createdAt: now.subtract(const Duration(days: 60)),
        currentStatus: 'Harvest',
        totalExpenses: 3200.0,
        imageUrl:
            'https://images.unsplash.com/photo-1546860255-95536c19724e?w=900&auto=format&fit=crop',
        perDatePledges: [
          HarvestEntry(
            date: DateTime(
              now.year,
              now.month,
              now.day,
            ).add(const Duration(days: 3)),
            variety: 'Native',
            quantity: 20,
          ),
          HarvestEntry(
            date: DateTime(
              now.year,
              now.month,
              now.day,
            ).add(const Duration(days: 7)),
            variety: 'Native',
            quantity: 30,
          ),
        ],
      ),

      // 3. SOLD - Tomato (Historical)
      HarvestPledge(
        id: 'PLEDGE-003',
        cropId: 'prod_001',
        cropName: 'Tomato',
        cropNameDialect: 'Kamatis',
        variants: ['Diamante'],
        harvestDate: now.subtract(const Duration(days: 10)),
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
      ),

      // 4. GROWING - Ginger
      HarvestPledge(
        id: 'PLEDGE-004',
        cropId: 'prod_008',
        cropName: 'Ginger',
        cropNameDialect: 'Luy-a',
        variants: ['Native'],
        harvestDate: now.add(const Duration(days: 120)),
        quantity: 100,
        unit: 'kg',
        farmerId: 'farmer-123',
        targetMarket: 'Local',
        createdAt: now.subtract(const Duration(days: 20)),
        currentStatus: 'Grow',
        totalExpenses: 2000.0,
        imageUrl:
            'https://images.unsplash.com/photo-1599940824399-b87987ceb72a?w=900&auto=format&fit=crop',
      ),

      // 5. GROWING - Garlic
      HarvestPledge(
        id: 'PLEDGE-005',
        cropId: 'prod_005',
        cropName: 'Garlic',
        cropNameDialect: 'Bawang',
        variants: ['Ilocos White'],
        harvestDate: now.add(const Duration(days: 30)),
        quantity: 300,
        unit: 'kg',
        farmerId: 'farmer-123',
        targetMarket: 'National',
        createdAt: now.subtract(const Duration(days: 40)),
        currentStatus: 'Grow',
        totalExpenses: 8000.0,
        imageUrl:
            'https://images.unsplash.com/photo-1540148426945-6cf22a6b2383?w=900&auto=format&fit=crop',
        perDatePledges: [
          HarvestEntry(
            date: DateTime(
              now.year,
              now.month,
              now.day,
            ).add(const Duration(days: 30)),
            variety: 'Ilocos White',
            quantity: 150,
          ),
          HarvestEntry(
            date: DateTime(
              now.year,
              now.month,
              now.day,
            ).add(const Duration(days: 35)),
            variety: 'Ilocos White',
            quantity: 150,
          ),
        ],
      ),

      // 6. HARVESTED - Eggplant
      HarvestPledge(
        id: 'PLEDGE-006',
        cropId: 'prod_002',
        cropName: 'Eggplant',
        cropNameDialect: 'Talong',
        variants: ['Long Purple'],
        harvestDate: now.subtract(const Duration(days: 1)),
        quantity: 150,
        unit: 'kg',
        farmerId: 'farmer-123',
        targetMarket: 'Local',
        createdAt: now.subtract(const Duration(days: 45)),
        currentStatus: 'Harvest',
        totalExpenses: 3500.0,
        imageUrl:
            'https://images.unsplash.com/photo-1615485290382-441e4d0c9cb5?w=900&auto=format&fit=crop',
        perDatePledges: [
          HarvestEntry(
            date: DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(const Duration(days: 1)),
            variety: 'Long Purple',
            quantity: 75,
          ),
          HarvestEntry(
            date: DateTime(
              now.year,
              now.month,
              now.day,
            ).add(const Duration(days: 2)),
            variety: 'Long Purple',
            quantity: 75,
          ),
        ],
        completedDates: [
          DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 1)),
        ],
      ),

      // 7. SOLD - Bitter Gourd
      HarvestPledge(
        id: 'PLEDGE-007',
        cropId: 'prod_007',
        cropName: 'Bitter Gourd',
        cropNameDialect: 'Ampalaya',
        variants: ['Galactica'],
        harvestDate: now.subtract(const Duration(days: 20)),
        quantity: 80,
        unit: 'kg',
        farmerId: 'farmer-123',
        targetMarket: 'Local',
        createdAt: now.subtract(const Duration(days: 55)),
        currentStatus: 'Sold',
        totalExpenses: 2200.0,
        sellingPrice: 5600.0,
        imageUrl:
            'https://images.unsplash.com/photo-1582515073490-399823e7642a?w=900&auto=format&fit=crop',
      ),

      // 8. GROWING - Cabbage
      HarvestPledge(
        id: 'PLEDGE-008',
        cropId: 'prod_008',
        cropName: 'Cabbage',
        cropNameDialect: 'Repolyo',
        variants: ['Scorpio', 'Rare Ball'],
        harvestDate: now.add(const Duration(days: 15)),
        quantity: 1000,
        unit: 'heads',
        farmerId: 'farmer-123',
        targetMarket: 'Export',
        createdAt: now.subtract(const Duration(days: 50)),
        currentStatus: 'Grow',
        totalExpenses: 15000.0,
        imageUrl:
            'https://images.unsplash.com/photo-1591196702597-062a17338521?w=900&auto=format&fit=crop',
        perDatePledges: [
          HarvestEntry(
            date: DateTime(
              now.year,
              now.month,
              now.day,
            ).add(const Duration(days: 15)),
            variety: 'Scorpio',
            quantity: 300,
          ),
          HarvestEntry(
            date: DateTime(
              now.year,
              now.month,
              now.day,
            ).add(const Duration(days: 15)),
            variety: 'Rare Ball',
            quantity: 200,
          ),
          HarvestEntry(
            date: DateTime(
              now.year,
              now.month,
              now.day,
            ).add(const Duration(days: 22)),
            variety: 'Scorpio',
            quantity: 300,
          ),
          HarvestEntry(
            date: DateTime(
              now.year,
              now.month,
              now.day,
            ).add(const Duration(days: 22)),
            variety: 'Rare Ball',
            quantity: 200,
          ),
        ],
      ),

      // 9. SOLD - Bell Pepper
      HarvestPledge(
        id: 'PLEDGE-009',
        cropId: 'prod_009',
        cropName: 'Bell Pepper',
        cropNameDialect: 'Atsal',
        variants: ['California Wonder'],
        harvestDate: now.subtract(const Duration(days: 5)),
        quantity: 40,
        unit: 'kg',
        farmerId: 'farmer-123',
        targetMarket: 'Local',
        createdAt: now.subtract(const Duration(days: 70)),
        currentStatus: 'Sold',
        totalExpenses: 1800.0,
        sellingPrice: 4800.0,
        imageUrl:
            'https://images.unsplash.com/photo-1566275529824-cca6d008f3da?w=900&auto=format&fit=crop',
      ),

      // 10. HARVESTED - Okra
      HarvestPledge(
        id: 'PLEDGE-010',
        cropId: 'prod_005',
        cropName: 'Okra',
        cropNameDialect: 'Okra',
        variants: ['Smooth Green'],
        harvestDate: now.subtract(const Duration(days: 2)),
        quantity: 120,
        unit: 'kg',
        farmerId: 'farmer-123',
        targetMarket: 'Local',
        createdAt: now.subtract(const Duration(days: 35)),
        currentStatus: 'Harvest',
        totalExpenses: 2500.0,
        imageUrl:
            'https://images.unsplash.com/photo-1627566144810-7e44923e3e07?w=900&auto=format&fit=crop',
        perDatePledges: [
          HarvestEntry(
            date: DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(const Duration(days: 2)),
            variety: 'Smooth Green',
            quantity: 60,
          ),
          HarvestEntry(
            date: DateTime(
              now.year,
              now.month,
              now.day,
            ).add(const Duration(days: 1)),
            variety: 'Smooth Green',
            quantity: 60,
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
