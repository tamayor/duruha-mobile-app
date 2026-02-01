import '../domain/pledge_model.dart';

class PledgeRepository {
  // Simulate an API call
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
      // Active Pledge 1
      HarvestPledge(
        id: 'PLEDGE-001',
        cropId: 'prod_010', // Fixed: Matches Onion in ProduceRepository
        cropName: 'Onion',
        cropNameDialect: 'Sulyaw',
        variants: ['Red Pinoy', 'Super Pinoy'],
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
      ),
      // Active Pledge 2
      HarvestPledge(
        id: 'PLEDGE-002',
        cropId: 'prod_003', // Fixed: Matches Bird's Eye Chili
        cropName: "Bird's Eye Chili",
        cropNameDialect: 'Siling Labuyo',
        variants: ['Native'],
        harvestDate: now.add(const Duration(days: 12)),
        quantity: 50,
        unit: 'kg',
        farmerId: 'farmer-123',
        targetMarket: 'National',
        createdAt: now.subtract(const Duration(days: 60)),
        currentStatus: 'Harvest',
        totalExpenses: 3200.0,
        imageUrl:
            'https://images.unsplash.com/photo-1546860255-95536c19724e?w=900&auto=format&fit=crop',
      ),
      // History Pledge 1 (Completed)
      HarvestPledge(
        id: 'PLEDGE-000-A',
        cropId: 'prod_001', // Fixed: Matches Tomato
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
    ];
  }

  // Simulate fetching demand forecast based on date
  Future<Map<String, dynamic>> getDemandForecast(
    String cropId,
    DateTime date,
  ) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Mock logic based on month
    final month = date.month;
    //final year = date.year;  - must be included in the future
    final isHighSeason = month >= 9 || month <= 2;

    // Detailed Mock Data
    final double localDemand = 1000.0;
    final double localFulfilled = (month % 2 != 0)
        ? 1000.0
        : 600.0; // Odd months full

    final double nationalDemand = 10000.0;
    final double nationalFulfilled = 4500.0;

    return {
      'local_demand_kg': localDemand,
      'local_fulfilled_kg': localFulfilled,
      'national_demand_kg': nationalDemand,
      'national_fulfilled_kg': nationalFulfilled,
      'local_price': isHighSeason ? 120.0 : 80.0,
      'national_price': isHighSeason ? 115.0 : 70.0,
    };
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
}
