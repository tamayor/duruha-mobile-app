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
}
