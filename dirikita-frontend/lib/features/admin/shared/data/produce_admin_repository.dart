import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart'; // Correct domain import

class ProduceAdminRepository {
  final SupabaseClient supabase;

  ProduceAdminRepository(this.supabase);

  Future<PaginatedProduce> getAllProduceWithVarieties({
    ProduceCursor? cursor,
    int limit = 10,
  }) async {
    debugPrint(
      "🚀 [ADMIN API] Fetching Produce with Varieties via RPC (cursor: ${cursor?.id}, limit: $limit)",
    );

    try {
      final response = await supabase.rpc(
        'get_produce_with_varieties_and_listing',
        params: {
          'p_cursor_updated_at': cursor?.updatedAt,
          'p_cursor_id': cursor?.id,
          'p_limit': limit,
        },
      );

      if (response == null) {
        return PaginatedProduce(data: [], count: 0, hasMore: false);
      }

      List<dynamic> data;
      bool hasMore = false;
      ProduceCursor? nextCursor;

      if (response is List) {
        data = response;
        hasMore = data.length == limit;
      } else if (response is Map) {
        final map = response as Map<String, dynamic>;
        data =
            (map['data'] ??
                    map['items'] ??
                    map['produce'] ??
                    map['result'] ??
                    [])
                as List<dynamic>;

        hasMore = map['has_more'] as bool? ?? data.length == limit;
        if (map['next_cursor'] != null) {
          final nc = map['next_cursor'] as Map<String, dynamic>;
          nextCursor = ProduceCursor(
            updatedAt: nc['updated_at']?.toString(),
            id: nc['id']?.toString(),
          );
        }
      } else {
        throw Exception('Unexpected response type: ${response.runtimeType}');
      }

      // Parse using the existing domain model's fromJson
      final produceList = data.map((json) => Produce.fromJson(json)).toList();

      debugPrint(
        "✅ [ADMIN API] Successfully loaded ${produceList.length} produce categories.",
      );
      return PaginatedProduce(
        data: produceList,
        count: produceList.length,
        hasMore: hasMore,
        nextCursor: nextCursor,
      );
    } catch (e) {
      debugPrint("❌ [ADMIN API] Failed to fetch produce: $e");
      throw Exception('Failed to load produce: $e');
    }
  }

  Future<List<Produce>> searchProduce(String query) async {
    debugPrint("🚀 [ADMIN API] Searching Produce via RPC: $query");
    try {
      final response = await supabase.rpc(
        'search_produce',
        params: {'p_query': query, 'p_limit': 20},
      );

      final data = response as Map<String, dynamic>;
      final produceList = (data['data'] as List)
          .map((json) => Produce.fromJson(json))
          .toList();

      debugPrint(
        "✅ [ADMIN API] Successfully loaded ${produceList.length} search results.",
      );
      return produceList;
    } catch (e) {
      debugPrint("❌ [ADMIN API] Failed to search produce: $e");
      throw Exception('Failed to search produce: $e');
    }
  }

  Future<void> updateVarietyPrices(
    List<String> varietyIds,
    double marketPrice,
    double price,
    double traderPrice,
    double farmerPrice,
  ) async {
    debugPrint("🚀 [ADMIN API] Updating Variety Prices via RPC");

    try {
      final response = await supabase.rpc(
        'update_variety_prices',
        params: {
          'p_variety_ids': varietyIds,
          'p_market_price': marketPrice,
          'p_price': price,
          'p_trader_price': traderPrice,
          'p_farmer_price': farmerPrice,
        },
      );

      // Handle the new custom JSON response from the RPC
      final responseMap = response as Map<String, dynamic>;

      if (responseMap['success'] == true) {
        debugPrint(
          "✅ [ADMIN API] Successfully updated ${responseMap['orders_updated']} orders.",
        );
      } else {
        final errorMsg = responseMap['error'] ?? 'Unknown database error';
        debugPrint("❌ [ADMIN API] Database returned error: $errorMsg");
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint("❌ [ADMIN API] Failed to update variety prices: $e");
      throw Exception('Failed to update variety prices: $e');
    }
  }

  Future<void> upsertProduceMatrix(Map<String, dynamic> matrixData) async {
    debugPrint("🚀 [ADMIN API] Upserting Produce Matrix");

    try {
      // 1. Upsert Produce
      final produceResult = await supabase
          .from('produce')
          .upsert({
            if (matrixData['id'] != null) 'id': matrixData['id'],
            'english_name': matrixData['english_name'],
            'scientific_name': matrixData['scientific_name'],
            'base_unit': matrixData['base_unit'],
            'image_url': matrixData['image_url'],
            'category': matrixData['category'],
            'storage_group': matrixData['storage_group'],
            'respiration_rate': matrixData['respiration_rate'],
            'is_ethylene_producer': matrixData['is_ethylene_producer'],
            'is_ethylene_sensitive': matrixData['is_ethylene_sensitive'],
            'crush_weight_tolerance': matrixData['crush_weight_tolerance'],
            'cross_contamination_risk': matrixData['cross_contamination_risk'],
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final produceId = produceResult['id'];

      // 2. Process Varieties
      final varieties = matrixData['varieties'] as List<dynamic>? ?? [];
      for (var v in varieties) {
        final varietyResult = await supabase
            .from('produce_varieties')
            .upsert({
              if (v['variety_id'] != null) 'variety_id': v['variety_id'],
              'produce_id': produceId,
              'variety_name': v['variety_name'],
              'is_native': v['is_native'],
              'breeding_type': v['breeding_type'],
              'days_to_maturity_min': v['days_to_maturity_min'],
              'days_to_maturity_max': v['days_to_maturity_max'],
              'philippine_season': v['philippine_season'],
              'flood_tolerance': v['flood_tolerance'],
              'handling_fragility': v['handling_fragility'],
              'shelf_life_days': v['shelf_life_days'],
              'optimal_storage_temp_c': v['optimal_storage_temp_c'],
              'packaging_requirement': v['packaging_requirement'],
              'appearance_desc': v['appearance_desc'],
              'image_url': v['image_url'],
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        final varietyId = varietyResult['variety_id'];

        // 3. Process Listings
        final listings = v['listings'] as List<dynamic>? ?? [];
        for (var l in listings) {
          await supabase.from('produce_variety_listing').upsert({
            if (l['listing_id'] != null) 'listing_id': l['listing_id'],
            'variety_id': varietyId,
            'produce_form': l['produce_form'],
            'farmer_to_trader_price': l['farmer_to_trader_price'],
            'farmer_to_duruha_price': l['farmer_to_duruha_price'],
            'duruha_to_consumer_price': l['duruha_to_consumer_price'],
            'market_to_consumer_price': l['market_to_consumer_price'],
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }

      debugPrint("✅ [ADMIN API] Produce Matrix upserted successfully.");
    } catch (e) {
      debugPrint("❌ [ADMIN API] Failed to upsert produce matrix: $e");
      throw Exception('Failed to save produce: $e');
    }
  }

  Future<void> updateListingPrices(
    List<String> listingIds,
    double marketPrice,
    double price,
    double traderPrice,
    double farmerPrice,
  ) async {
    debugPrint("🚀 [ADMIN API] Updating Listing Prices");

    try {
      await supabase
          .from('produce_variety_listing')
          .update({
            'market_to_consumer_price': marketPrice,
            'duruha_to_consumer_price': price,
            'farmer_to_trader_price': traderPrice,
            'farmer_to_duruha_price': farmerPrice,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .inFilter('listing_id', listingIds);
      debugPrint(
        "✅ [ADMIN API] Successfully updated ${listingIds.length} listings.",
      );
    } catch (e) {
      debugPrint("❌ [ADMIN API] Failed to update listing prices: $e");
      throw Exception('Failed to update listing prices: $e');
    }
  }

  Future<void> createVarietyListing({
    required String varietyId,
    required String produceForm,
  }) async {
    debugPrint("🚀 [ADMIN API] Creating new Variety Listing: $produceForm");

    try {
      await supabase.from('produce_variety_listing').insert({
        'variety_id': varietyId,
        'produce_form': produceForm,
        'farmer_to_trader_price': 0.0,
        'farmer_to_duruha_price': 0.0,
        'duruha_to_consumer_price': 0.0,
        'market_to_consumer_price': 0.0,
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint("✅ [ADMIN API] Successfully created listing $produceForm.");
    } catch (e) {
      debugPrint("❌ [ADMIN API] Failed to create variety listing: $e");
      throw Exception('Failed to create produce form: $e');
    }
  }
}
