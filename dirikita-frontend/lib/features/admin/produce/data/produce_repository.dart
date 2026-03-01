import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';

/// Single admin repository for all produce-related RPCs:
///   • get_produce_with_varieties_and_listing  (paginated list)
///   • search_produce                          (full-text search)
///   • create_produce                          (atomic insert)
///   • update_produce                          (atomic update)
class ProduceRepository {
  final SupabaseClient supabase;

  ProduceRepository(this.supabase);

  // ---------------------------------------------------------------------------
  // READ – paginated list
  // ---------------------------------------------------------------------------

  Future<PaginatedProduce> getAllProduceWithVarieties({
    ProduceCursor? cursor,
    int limit = 10,
  }) async {
    debugPrint(
      '🚀 [ProduceRepo] get_produce_with_varieties_and_listing '
      '(cursor: ${cursor?.id}, limit: $limit)',
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

      final produceList = data.map((j) => Produce.fromJson(j)).toList();
      debugPrint('✅ [ProduceRepo] loaded ${produceList.length} produce.');
      return PaginatedProduce(
        data: produceList,
        count: produceList.length,
        hasMore: hasMore,
        nextCursor: nextCursor,
      );
    } catch (e) {
      debugPrint('❌ [ProduceRepo] getAllProduceWithVarieties: $e');
      throw Exception('Failed to load produce: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // READ – search
  // ---------------------------------------------------------------------------

  Future<List<Produce>> searchProduce(String query) async {
    debugPrint('🚀 [ProduceRepo] search_produce: $query');
    try {
      final response = await supabase.rpc(
        'search_produce',
        params: {'p_query': query, 'p_limit': 20},
      );
      final data = response as Map<String, dynamic>;
      final produceList = (data['data'] as List)
          .map((j) => Produce.fromJson(j))
          .toList();
      debugPrint('✅ [ProduceRepo] search returned ${produceList.length}.');
      return produceList;
    } catch (e) {
      debugPrint('❌ [ProduceRepo] searchProduce: $e');
      throw Exception('Failed to search produce: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // WRITE – create (calls create_produce RPC)
  // ---------------------------------------------------------------------------

  /// Creates a brand-new produce with all its varieties and listings.
  /// [adminId] should be `supabase.auth.currentUser!.id`.
  Future<void> createProduce({
    required String adminId,
    required Map<String, dynamic> payload,
  }) async {
    debugPrint('🚀 [ProduceRepo] create_produce  admin=$adminId');
    try {
      await supabase.rpc(
        'create_produce',
        params: {'p_user_id': adminId, 'p_payload': payload},
      );
      debugPrint('✅ [ProduceRepo] create_produce succeeded.');
    } catch (e) {
      debugPrint('❌ [ProduceRepo] create_produce failed: $e');
      throw Exception('Failed to create produce: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // WRITE – update (calls update_produce RPC)
  // ---------------------------------------------------------------------------

  /// Updates an existing produce (identified by [produceId]) together
  /// with all its varieties and listings.
  Future<void> updateProduce({
    required String adminId,
    required String produceId,
    required Map<String, dynamic> payload,
  }) async {
    debugPrint(
      '🚀 [ProduceRepo] update_produce  admin=$adminId  produce=$produceId',
    );
    try {
      await supabase.rpc(
        'update_produce',
        params: {'p_user_id': adminId, 'p_id': produceId, 'p_payload': payload},
      );
      debugPrint('✅ [ProduceRepo] update_produce succeeded.');
    } catch (e) {
      debugPrint('❌ [ProduceRepo] update_produce failed: $e');
      throw Exception('Failed to update produce: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Static helpers – build nested RPC payload from form field values
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> buildPayload({
    String? produceId,
    required String englishName,
    required String scientificName,
    required String baseUnit,
    required String imageUrl,
    required String category,
    required String storageGroup,
    required String respirationRate,
    required bool isEthyleneProducer,
    required bool isEthyleneSensitive,
    required int crushWeightTolerance,
    required String crossContaminationRisk,
    required List<Map<String, dynamic>> varieties,
    List<Map<String, dynamic>> dialects = const [],
  }) {
    return {
      if (produceId != null) 'id': produceId,
      'english_name': englishName,
      'scientific_name': scientificName,
      'base_unit': baseUnit,
      'image_url': imageUrl,
      'category': category,
      'storage_group': storageGroup,
      'respiration_rate': respirationRate,
      'is_ethylene_producer': isEthyleneProducer,
      'is_ethylene_sensitive': isEthyleneSensitive,
      'crush_weight_tolerance': crushWeightTolerance,
      'cross_contamination_risk': crossContaminationRisk,
      'varieties': varieties,
      'dialects': dialects,
    };
  }

  static Map<String, dynamic> buildVariety({
    String? varietyId,
    required String name,
    required bool isNative,
    required String breedingType,
    int? daysToMaturityMin,
    int? daysToMaturityMax,
    required String philippineSeason,
    int? floodTolerance,
    int? handlingFragility,
    required int shelfLifeDays,
    double? optimalStorageTempC,
    required String packagingRequirement,
    required String appearanceDesc,
    required String imageUrl,
    required List<Map<String, dynamic>> listings,
  }) {
    return {
      if (varietyId != null) 'variety_id': varietyId,
      'variety_name': name,
      'is_native': isNative,
      'breeding_type': breedingType,
      'days_to_maturity_min': daysToMaturityMin,
      'days_to_maturity_max': daysToMaturityMax,
      'philippine_season': philippineSeason,
      'flood_tolerance': floodTolerance,
      'handling_fragility': handlingFragility,
      'shelf_life_days': shelfLifeDays,
      'optimal_storage_temp_c': optimalStorageTempC,
      'packaging_requirement': packagingRequirement,
      'appearance_desc': appearanceDesc,
      'image_url': imageUrl,
      'listings': listings,
    };
  }

  static Map<String, dynamic> buildListing({
    String? listingId,
    required String produceForm,
    required double farmerToTraderPrice,
    required double farmerToDuruhaPrice,
    required double duruhaToConsumerPrice,
    required double marketToConsumerPrice,
  }) {
    return {
      if (listingId != null) 'listing_id': listingId,
      'produce_form': produceForm,
      'farmer_to_trader_price': farmerToTraderPrice,
      'farmer_to_duruha_price': farmerToDuruhaPrice,
      'duruha_to_consumer_price': duruhaToConsumerPrice,
      'market_to_consumer_price': marketToConsumerPrice,
    };
  }
}
