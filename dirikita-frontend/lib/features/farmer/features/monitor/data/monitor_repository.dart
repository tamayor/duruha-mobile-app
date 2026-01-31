import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import '../domain/monitor_models.dart';

class MonitorRepository {
  // Simulate API delay
  Future<void> _delay() => Future.delayed(const Duration(milliseconds: 800));

  /* sample API implementation
  // GET $baseUrl/pledges/my
  // Response: [
  //   {
  //     "id": "pledge_001",
  //     "crop_id": "prod_001",
  //     "crop_name": "Tomato",
  //     "crop_name_dialect": "Kamatis",
  //     "selected_variants": ["Diamante Max"],
  //     "harvest_date": "2024-03-25T00:00:00.000",
  //     "quantity": 200.0,
  //     "unit": "kg",
  //     "farmer_id": "farmer-001",
  //     "target_market": "Local",
  //     "current_status": "Grow",
  //     "total_expenses": 4500.0,
  //     "selling_price": 85.0,
  //     "created_at": "2024-03-01T10:00:00.000"
  //   }
  // ]
  Future<List<HarvestPledge>> getMyPledges() async {
    final response = await http.get(Uri.parse('$baseUrl/pledges/my'));
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((json) => HarvestPledge.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load pledges');
    }
  }
  */

  Future<List<HarvestPledge>> getMyPledges() async {
    await _delay();
    final now = DateTime.now();
    return [
      HarvestPledge(
        id: "pledge_001",
        cropId: "prod_001",
        cropName: "Tomato",
        cropNameDialect: "Kamatis",
        variants: ["Diamante Max"],
        quantity: 200,
        unit: "kg",
        farmerId: "farmer-001",
        targetMarket: "Local",
        createdAt: now.subtract(const Duration(days: 10)),
        harvestDate: now.add(const Duration(days: 20)),
        currentStatus: 'Grow',
        totalExpenses: 4500.0,
      ),
      HarvestPledge(
        id: "pledge_002",
        cropId: "prod_005",
        cropName: "Eggplant",
        cropNameDialect: "Talong",
        variants: ["Long Purple", "Small"],
        quantity: 500,
        unit: "kg",
        farmerId: "farmer-001",
        targetMarket: "National",
        createdAt: now.subtract(const Duration(days: 45)),
        harvestDate: now.add(const Duration(days: 5)),
        currentStatus: 'Harvest',
        totalExpenses: 8200.0,
      ),
      HarvestPledge(
        id: "pledge_003",
        cropId: "prod_001",
        cropName: "Tomato",
        cropNameDialect: "Kamatis",
        variants: ["Diamante Max"],
        quantity: 150,
        unit: "kg",
        farmerId: "farmer-001",
        targetMarket: "Local",
        createdAt: now.subtract(const Duration(days: 100)),
        harvestDate: now.subtract(const Duration(days: 10)),
        currentStatus: 'Sold',
        totalExpenses: 7500.0,
        sellingPrice: 85.0,
      ),
      HarvestPledge(
        id: "pledge_004",
        cropId: "prod_005",
        cropName: "Eggplant",
        cropNameDialect: "Talong",
        variants: ["Long Purple"],
        quantity: 300,
        unit: "kg",
        farmerId: "farmer-001",
        targetMarket: "National",
        createdAt: now.subtract(const Duration(days: 120)),
        harvestDate: now.subtract(const Duration(days: 30)),
        currentStatus: 'Sold',
        totalExpenses: 12000.0,
        sellingPrice: 70.0,
      ),
    ];
  }

  /* sample API implementation
  // GET $baseUrl/pledges/$id
  // Response: { same object as in getMyPledges }
  Future<HarvestPledge?> getPledgeById(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/pledges/$id'));
    if (response.statusCode == 200) {
      return HarvestPledge.fromJson(json.decode(response.body));
    }
    return null;
  }
  */

  Future<HarvestPledge?> getPledgeById(String id) async {
    final pledges = await getMyPledges();
    try {
      return pledges.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  /* sample API implementation
  // GET $baseUrl/pledges/$pledgeId/status-history
  // Response: [
  //   {
  //     "status": "Plant",
  //     "timestamp": "2024-03-05T08:30:00.000"
  //   }
  // ]
  Future<List<PledgeStatusHistory>> getStatusHistory(String pledgeId) async {
    final response = await http.get(Uri.parse('$baseUrl/pledges/$pledgeId/status-history'));
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((json) => PledgeStatusHistory.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load status history');
    }
  }
  */

  Future<List<PledgeStatusHistory>> getStatusHistory(String pledgeId) async {
    await _delay();
    return [
      PledgeStatusHistory(
        status: 'Set',
        timestamp: DateTime.now().subtract(const Duration(days: 15)),
      ),
      PledgeStatusHistory(
        status: 'Plant',
        timestamp: DateTime.now().subtract(const Duration(days: 12)),
      ),
    ];
  }

  /* sample API implementation
  // GET $baseUrl/pledges/$pledgeId/expenses
  // Response: [
  //   {
  //     "name": "Hybrid Seeds",
  //     "category": "Seeds",
  //     "cost": 1200.0
  //   }
  // ]
  Future<List<PledgeExpense>> getExpenseHistory(String pledgeId) async {
    final response = await http.get(Uri.parse('$baseUrl/pledges/$pledgeId/expenses'));
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((json) => PledgeExpense.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load expenses');
    }
  }
  */

  Future<List<PledgeExpense>> getExpenseHistory(String pledgeId) async {
    await _delay();
    return [
      const PledgeExpense(name: 'Hybrid Seeds', category: 'Seeds', cost: 1200),
      const PledgeExpense(
        name: 'NPK Fertilizer',
        category: 'Fertilizer',
        cost: 2500,
      ),
    ];
  }

  /* sample API implementation
  // GET $baseUrl/pledges/$pledgeId/schedule-history
  // Response: [
  //   {
  //     "oldDate": "2024-03-20T00:00:00.000",
  //     "newDate": "2024-03-25T00:00:00.000",
  //     "reason": "Weather Conditions",
  //     "notes": "Heavy rains delayed harvest",
  //     "timestamp": "2024-03-15T14:20:00.000"
  //   }
  // ]
  Future<List<PledgeScheduleHistory>> getScheduleHistory(String pledgeId) async {
    final response = await http.get(Uri.parse('$baseUrl/pledges/$pledgeId/schedule-history'));
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((json) => PledgeScheduleHistory.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load schedule history');
    }
  }
  */

  Future<List<PledgeScheduleHistory>> getScheduleHistory(
    String pledgeId,
  ) async {
    await _delay();
    return [];
  }

  /* sample API implementation
  // GET $baseUrl/config/reschedule-reasons
  // Response: ["Weather Conditions", "Pest/Disease Issue", ...]
  Future<List<String>> getRescheduleReasons() async {
    final response = await http.get(Uri.parse('$baseUrl/config/reschedule-reasons'));
    if (response.statusCode == 200) {
      return List<String>.from(json.decode(response.body));
    }
    return [];
  }
  */

  Future<List<String>> getRescheduleReasons() async {
    await _delay();
    return [
      'Weather Conditions',
      'Pest/Disease Issue',
      'Delayed Maturity',
      'Logistics Issue',
      'Personal/Labor Shortage',
    ];
  }

  /* sample API implementation
  // GET $baseUrl/config/input-categories
  // Response: ["Seeds", "Fertilizer", ...]
  Future<List<String>> getInputCategories() async {
    final response = await http.get(Uri.parse('$baseUrl/config/input-categories'));
    if (response.statusCode == 200) {
      return List<String>.from(json.decode(response.body));
    }
    return [];
  }
  */

  Future<List<String>> getInputCategories() async {
    await _delay();
    return [
      'Seeds',
      'Fertilizer',
      'Pesticide/Chem',
      'Labor',
      'Equipment/Tools',
      'Fuel',
      'Water/Irrigation',
      'Others',
    ];
  }

  /* sample API implementation
  // GET $baseUrl/config/pledge-statuses
  // Response: ["Set", "Cultivate", "Plant", ...]
  Future<List<String>> getPledgeStatuses() async {
    final response = await http.get(Uri.parse('$baseUrl/config/pledge-statuses'));
    if (response.statusCode == 200) {
      return List<String>.from(json.decode(response.body));
    }
    return [];
  }
  */

  Future<List<String>> getPledgeStatuses() async {
    await _delay();
    return [
      'Set',
      'Cultivate',
      'Plant',
      'Grow',
      'Harvest',
      'Process',
      'Ready to Sell',
      'Sold',
    ];
  }
}
