// lib/src/features/farm/data/crop_recommendation_repository.dart

import 'dart:math';
import 'package:duruha/features/farmer/features/farm/domain/recommendation_model.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';

/* 
  API DOCUMENTATION FOR BACKEND DEVELOPER
  =======================================
  Endpoint: GET /api/crops/recommendations
  
  Description: Returns a list of recommended crops based on market demand and profitability.
  
  Expected JSON Response Structure:
  [
    {
      "id": "crop_001",                   // Unique Crop ID
      "rank": 1,                          // Recommendation Rank (1 = Top Pick)
      "name_english": "Tomato",           // English Name
      "name_dialect": "Kamatis",          // Local Dialect Name (e.g., Tagalog)
      "image_url": "https://example...",  // URL to thumbnail image
      
      // Demand Scores (0.0 to 1.0)
      "demand_local": 0.85,               // High local demand
      "demand_nationwide": 0.65,          // Moderate national demand
      
      // Pledge/Volume Data (in kg)
      "target_pledge_kg": 5000.0,         // Total market need
      "current_pledge_kg": 1200.0,        // Amount currently pledged by other farmers
      
      // Price Data (Currency/kg)
      "price_min": 45.0,                  // Historical Low
      "price_max": 80.0                   // Historical High
    },
    ...
  ]
*/
class CropRecommendationRepository {
  Future<List<CropRecommendation>> getRecommendations() async {
    // Simulate network delay for a premium feel
    await Future.delayed(const Duration(milliseconds: 1000));

    final allProduce = await ProduceRepository().getAllProduce();
    final random = Random();

    // Take the top 5 to keep the dashboard focused and "Elite"
    return allProduce.take(5).toList().asMap().entries.map((entry) {
      final int index = entry.key;
      final produce = entry.value;

      // Logic: Local demand is often different from Nationwide
      // e.g. Nationwide might have enough, but your town (Local) is empty
      // We use full random range to simulate Low (0.0-0.4), Stable (0.4-0.7), High (0.7-1.0)
      final double demandLocal = random.nextDouble();
      final double demandNationwide = random.nextDouble();

      // FULFILLMENT DATA:
      // We set a target (e.g. 500kg) and a random current pledge amount
      final double target = 300.0 + (random.nextInt(7) * 100);
      final double current =
          random.nextDouble() *
          (target * 0.8); // Always under target to show room

      return CropRecommendation(
        id: produce.id,
        rank: index + 1,
        nameDialect: produce.namesByDialect['tagalog'] ?? produce.nameEnglish,
        nameEnglish: produce.nameEnglish,
        demandLocal: demandLocal,
        demandNationwide: demandNationwide,
        currentPledgeKg: current,
        targetPledgeKg: target,
        imageUrl: produce.imageThumbnailUrl,
        priceMin: produce.priceMinHistorical,
        priceMax: produce.priceMaxHistorical,
      );
    }).toList();
  }
}
