import 'package:duruha/features/farmer/features/profile/domain/ratings_model.dart';

abstract class PerformanceRepository {
  Future<FarmerPerformance> getPerformanceStats(String farmerId);
}

class PerformanceRepositoryImpl implements PerformanceRepository {
  /* sample API implementation
  Future<FarmerPerformance> getPerformanceStats(String farmerId) async {
    final response = await http.get(Uri.parse('$baseUrl/farmer/$farmerId/performance'));
    if (response.statusCode == 200) {
      return FarmerPerformance.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load performance stats');
    }
  }
  */

  @override
  Future<FarmerPerformance> getPerformanceStats(String farmerId) async {
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 600));

    return const FarmerPerformance(
      trustScore: 982,
      trustSubtitle: "Top 2% of Farmers",
      cropPoints: 14500,
      pointsSubtitle: "Level 12 Veteran",
      currentRankName: "Master Harvester Bronze",
      rankProgress: 0.8,
      rankNextGoal: "You are 500 points away from Silver rank!",
    );
  }
}
