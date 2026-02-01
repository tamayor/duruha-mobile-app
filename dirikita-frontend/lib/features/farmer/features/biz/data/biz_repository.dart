import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/features/farmer/features/biz/domain/biz_model.dart';

class BizRepository {
  // Simulate an API call centered around business/financial data
  Future<List<HarvestPledge>> fetchSalesRecords() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    final now = DateTime.now();

    // Mocking some "Sold" pledges for the business hub
    return [
      HarvestPledge(
        id: 'SALE-001',
        cropId: 'onion-001',
        cropName: 'Red Onion',
        cropNameDialect: 'Sulyaw',
        variants: ['Red Pinoy'],
        harvestDate: now.subtract(const Duration(days: 5)),
        quantity: 1200,
        unit: 'kg',
        farmerId: 'farmer-123',
        targetMarket: 'National',
        createdAt: now.subtract(const Duration(days: 100)),
        currentStatus: 'Sold',
        totalExpenses: 25000.0,
        sellingPrice: 48000.0, // 40/kg
      ),
      HarvestPledge(
        id: 'SALE-002',
        cropId: 'tomato-001',
        cropName: 'Tomato',
        cropNameDialect: 'Kamatis',
        variants: ['Diamante'],
        harvestDate: now.subtract(const Duration(days: 12)),
        quantity: 500,
        unit: 'kg',
        farmerId: 'farmer-123',
        targetMarket: 'Local',
        createdAt: now.subtract(const Duration(days: 90)),
        currentStatus: 'Sold',
        totalExpenses: 8000.0,
        sellingPrice: 15000.0, // 30/kg
      ),
      HarvestPledge(
        id: 'SALE-003',
        cropId: 'chili-001',
        cropName: 'Red Chili',
        cropNameDialect: 'Siling Labuyo',
        variants: ['Native'],
        harvestDate: now.subtract(const Duration(days: 20)),
        quantity: 100,
        unit: 'kg',
        farmerId: 'farmer-123',
        targetMarket: 'National',
        createdAt: now.subtract(const Duration(days: 120)),
        currentStatus: 'Sold',
        totalExpenses: 5000.0,
        sellingPrice: 12000.0, // 120/kg
      ),
      // A recent one that is not sold yet (to verify filtering)
      HarvestPledge(
        id: 'ACTIVE-001',
        cropId: 'onion-001',
        cropName: 'Red Onion',
        cropNameDialect: 'Sulyaw',
        variants: ['Red Pinoy'],
        harvestDate: now.add(const Duration(days: 15)),
        quantity: 2000,
        unit: 'kg',
        farmerId: 'farmer-123',
        targetMarket: 'National',
        createdAt: now.subtract(const Duration(days: 45)),
        currentStatus: 'Grow',
        totalExpenses: 35000.0,
      ),
    ];
  }

  // Future method for insights/trends
  Future<BizInsights> getEarningsInsights() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    return BizInsights(
      monthlyGrowth: 12.5,
      topPerformingCrop: 'Red Onion',
      marketDemandNearby: 'High',
      totalRevenue: 75000.0,
      totalSalesCount: 15,
    );
  }
}
