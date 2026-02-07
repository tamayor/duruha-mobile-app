import 'dart:math';

import 'package:duruha/features/farmer/features/main/domain/study_model.dart';
import 'package:intl/intl.dart';

/* 
  API DOCUMENTATION FOR BACKEND DEVELOPER
  =======================================
  Endpoint: GET /api/crops/{id}/market-study
  
  Description: Returns detailed market analysis and 12-month rolling forecast for a specific crop.
  
  Expected JSON Response Structure:
  {
    "crop_id": "crop_001",
    
    // Summary Scores (0.0 to 1.0)
    "local_demand_score": 0.85,
    "national_demand_score": 0.65,
    
    // Projected ROI / Pricing
    "price_projected_min": 80.0,
    "price_projected_max": 120.0,
    
    // 12-Month Rolling Forecast (Forecast Objects)
    // "month" should be formatted as "MMM" (e.g., "Feb", "Mar", "Apr") or a full date string to be formatted by client.
    
    "local_forecasts": [
      {
        "month": "Feb",
        "demand_kg": 500.0,
        "fulfilled_kg": 120.0  // Amount ALREADY pledged or supplied
      },
      ... // 11 more months
    ],
    
    "national_forecasts": [
      {
        "month": "Feb",
        "demand_kg": 5000.0,
        "fulfilled_kg": 4500.0
      },
      ... // 11 more months
    ]
  }
*/
class CropStudyRepository {
  Future<CropMarketStudy> getMarketStudy(String cropId) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 600));

    // Generate next 12 months starting from now
    final now = DateTime.now();
    final months = List.generate(12, (index) {
      final date = DateTime(now.year, now.month + index, 1);
      return DateFormat(
        'MMM\n'
        'yyyy',
      ).format(date);
    });

    final random = Random();

    // Create mock local forecast data
    final localForecasts = months.map((m) {
      // Random demand between 300 and 1000
      double demand = 300.0 + random.nextInt(700);
      // Fulfilled is mostly lower than demand, say 20% to 90%
      double fulfilled = demand * (0.2 + random.nextDouble() * 0.7);

      return MarketForecast(month: m, demandKg: demand, fulfilledKg: fulfilled);
    }).toList();

    // Create mock national forecast data (higher volume)
    final nationalForecasts = months.map((m) {
      // Random demand between 2000 and 8000
      double demand = 2000.0 + random.nextInt(6000);
      // Fulfilled
      double fulfilled = demand * (0.3 + random.nextDouble() * 0.6);

      return MarketForecast(month: m, demandKg: demand, fulfilledKg: fulfilled);
    }).toList();

    return CropMarketStudy(
      localForecasts: localForecasts,
      nationalForecasts: nationalForecasts,
      localDemandScore: 0.85,
      nationalDemandScore: 0.65,
      priceProjectedMin: 80.0,
      priceProjectedMax: 120.0,
    );
  }
}
