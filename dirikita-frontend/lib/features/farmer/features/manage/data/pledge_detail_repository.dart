import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/features/farmer/shared/data/pledge_repository.dart';

class PledgeDetailRepository {
  final _sharedRepository = PledgeRepository();

  /// Fetches a single pledge by ID with simulation delay.
  Future<HarvestPledge> getPledgeById(String id) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Simulation for SOLD pledge with multi-date harvest for UI demo
    if (id.toUpperCase() == 'PLEDGE-003') {
      final now = DateTime.now();
      return HarvestPledge(
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
        sellingPrice: 12000.0, // Total Revenue
        imageUrl:
            'https://images.unsplash.com/photo-1607305387299-a3d9611cd469?q=80&w=2370&auto=format&fit=crop',
        perDatePledges: [
          HarvestEntry(
            date: now.subtract(const Duration(days: 12)),
            variety: 'Diamante',
            quantity: 100,
            earnings: 6000.0,
            isCompleted: true,
          ),
          HarvestEntry(
            date: now.subtract(const Duration(days: 10)),
            variety: 'Diamante',
            quantity: 100,
            earnings: 6000.0,
            isCompleted: true,
          ),
        ],
      );
    }

    if (id.toUpperCase() == 'PLEDGE-FINISHED') {
      final now = DateTime.now();
      return HarvestPledge(
        id: 'PLEDGE-FINISHED',
        cropId: 'prod_001',
        cropName: 'Tomato',
        cropNameDialect: 'Kamatis',
        variants: ['Diamante'],
        harvestDate: now.subtract(const Duration(days: 30)),
        quantity: 500,
        unit: 'kg',
        farmerId: 'farmer-123',
        targetMarket: 'Wholesale',
        createdAt: now.subtract(const Duration(days: 120)),
        currentStatus: 'Done',
        totalExpenses: 12000.0,
        sellingPrice: 35000.0,
        imageUrl:
            'https://images.unsplash.com/photo-1629114759085-f5383556d10c?q=80&w=2370&auto=format&fit=crop',
        perDatePledges: [
          HarvestEntry(
            date: now.subtract(const Duration(days: 32)),
            variety: 'Diamante',
            quantity: 250,
            earnings: 17500.0,
            isCompleted: true,
          ),
          HarvestEntry(
            date: now.subtract(const Duration(days: 30)),
            variety: 'Diamante',
            quantity: 250,
            earnings: 17500.0,
            isCompleted: true,
          ),
          HarvestEntry(
            date: now.subtract(const Duration(days: 30)),
            variety: 'Max',
            quantity: 250,
            earnings: 17500.0,
            isCompleted: true,
          ),
        ],
      );
    }

    final allPledges = await _sharedRepository.fetchMyPledges();
    return allPledges.firstWhere(
      (p) => p.id?.toLowerCase() == id.toLowerCase(),
      orElse: () => throw Exception('Pledge not found'),
    );
  }

  /// Toggle harvest date completion
  Future<bool> toggleHarvestDateStatus(
    String pledgeId,
    DateTime date,
    bool isCompleted,
  ) async {
    await Future.delayed(const Duration(seconds: 1));
    // ignore: avoid_print
    print(
      "✅ [PledgeDetailAPI] Toggled Harvest Date Status for $pledgeId: ${date.toIso8601String()} -> $isCompleted",
    );
    return true;
  }

  /// Update pledge status
  Future<bool> updatePledgeStatus(
    String pledgeId,
    String newStatus, {
    String? notes,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    // ignore: avoid_print
    print(
      "🔄 [PledgeDetailAPI] Updated Status for $pledgeId to $newStatus (Notes: $notes)",
    );
    return true;
  }

  /// Add an expense to the pledge
  Future<bool> addExpense(
    String pledgeId,
    Map<String, dynamic> expenseData,
  ) async {
    await Future.delayed(const Duration(seconds: 1));
    // ignore: avoid_print
    print("💰 [PledgeDetailAPI] Added Expense for $pledgeId: $expenseData");
    return true;
  }

  /// Update an expense
  Future<bool> updateExpense(
    String pledgeId,
    Map<String, dynamic> expenseData,
  ) async {
    await Future.delayed(const Duration(seconds: 1));
    // ignore: avoid_print
    print("✏️ [PledgeDetailAPI] Updated Expense for $pledgeId: $expenseData");
    return true;
  }

  /// Delete an expense
  Future<bool> deleteExpense(String pledgeId, String expenseId) async {
    await Future.delayed(const Duration(seconds: 1));
    // ignore: avoid_print
    print("🗑️ [PledgeDetailAPI] Deleted Expense $expenseId from $pledgeId");
    return true;
  }

  /// Delete a status history entry
  Future<bool> deleteStatusEntry(String pledgeId, String statusId) async {
    await Future.delayed(const Duration(seconds: 1));
    // ignore: avoid_print
    print(
      "rewind [PledgeDetailAPI] Deleted Status Entry $statusId from $pledgeId",
    );
    return true;
  }
}
