import 'package:flutter/foundation.dart';
import 'package:duruha/shared/produce/domain/market_listing_model.dart';
import 'package:duruha/shared/produce/domain/produce_basic_info.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/supabase_config.dart';

class ProduceRepository {
  Future<List<Produce>> fetchProduce() async {
    final response = await supabase.from('produce_master_view').select();
    final List<Produce> produceList = (response as List)
        .map((json) => Produce.fromJson(json))
        .toList();

    return _attachVarietyOfferQuantities(produceList);
  }

  Future<List<Produce>> _attachVarietyOfferQuantities(
    List<Produce> produceList,
  ) async {
    if (produceList.isEmpty) return produceList;

    final varietyIds = produceList
        .expand((p) => p.varieties)
        .map((v) => v.id)
        .where((id) => id.isNotEmpty)
        .toList();

    if (varietyIds.isEmpty) return produceList;

    // Fetch aggregated quantities from farmer_offers for the next 30 days
    final now = DateTime.now();
    final thirtyDaysLater = now.add(const Duration(days: 30));

    final offersResponse = await supabase
        .from('farmer_offers')
        .select('variety_id, listing_id, remaining_quantity')
        .eq('is_active', true)
        .gte('available_to', now.toIso8601String())
        .lte('available_from', thirtyDaysLater.toIso8601String())
        .inFilter('variety_id', varietyIds);

    final Map<String, double> varietyQtyMap = {};
    final Map<String, double> listingQtyMap = {};

    for (var offer in (offersResponse as List)) {
      final vId = offer['variety_id'].toString();
      final lId = offer['listing_id']?.toString();
      final qty = (offer['remaining_quantity'] ?? 0.0).toDouble();

      varietyQtyMap[vId] = (varietyQtyMap[vId] ?? 0.0) + qty;
      if (lId != null) {
        listingQtyMap[lId] = (listingQtyMap[lId] ?? 0.0) + qty;
      }
    }

    // Map quantities back to produce list
    return produceList.map((p) {
      final updatedVarieties = p.varieties.map((v) {
        // IMPORTANT: Only varieties with at least one listing can be ordered.
        // If a variety has no listings, it shouldn't show stock to the consumer.
        if (v.listings.isEmpty) {
          return v.copyWith(total30DaysQuantity: 0, listings: []);
        }

        // Update listings with specific stock
        final updatedListings = v.listings.map((l) {
          if (listingQtyMap.containsKey(l.listingId)) {
            final lStock = listingQtyMap[l.listingId]!;
            return MarketListing(
              listingId: l.listingId,
              produceForm: l.produceForm,
              farmerToTraderPrice: l.farmerToTraderPrice,
              farmerToDuruhaPrice: l.farmerToDuruhaPrice,
              duruhaToConsumerPrice: l.duruhaToConsumerPrice,
              marketToConsumerPrice: l.marketToConsumerPrice,
              remainingQuantity: lStock,
            );
          }
          return l;
        }).toList();

        if (varietyQtyMap.containsKey(v.id)) {
          return v.copyWith(
            total30DaysQuantity: varietyQtyMap[v.id]!,
            listings: updatedListings,
          );
        }
        return v.copyWith(listings: updatedListings);
      }).toList();

      return Produce(
        id: p.id,
        englishName: p.englishName,
        scientificName: p.scientificName,
        createdAt: p.createdAt,
        baseUnit: p.baseUnit,
        imageUrl: p.imageUrl,
        category: p.category,
        updatedAt: p.updatedAt,
        crossContaminationRisk: p.crossContaminationRisk,
        crushWeightTolerance: p.crushWeightTolerance,
        respirationRate: p.respirationRate,
        storageGroup: p.storageGroup,
        isEthyleneProducer: p.isEthyleneProducer,
        isEthyleneSensitive: p.isEthyleneSensitive,
        varieties: updatedVarieties,
        dialects: p.dialects,
      );
    }).toList();
  }

  // Compatibility Alias
  Future<List<Produce>> getAllProduce() => fetchProduce();

  Future<List<Produce>> fetchProduceByIds(
    List<String> ids, {
    String mode = "details",
  }) async {
    if (ids.isEmpty) return [];
    try {
      final response = await supabase.rpc(
        'get_specific_produce',
        params: {'p_produce_ids': ids, 'p_mode': mode},
      );

      // Handle envelope structure { data, total_count }
      final List<dynamic> data;
      if (response is Map<String, dynamic> && response.containsKey('data')) {
        data = response['data'] as List? ?? [];
      } else if (response is List) {
        data = response;
      } else {
        debugPrint('⚠️ [ProduceRepo] Unexpected RPC response: $response');
        return [];
      }

      final List<Produce> produceList = data
          .map((json) => Produce.fromJson(json as Map<String, dynamic>))
          .toList();
      return _attachVarietyOfferQuantities(produceList);
    } catch (e) {
      debugPrint('❌ [ProduceRepo] fetchProduceByIds error: $e');
      return [];
    }
  }

  Future<Produce?> fetchProduceById(String id) async {
    try {
      // Use direct table query instead of produce_master_view to ensure real-time freshness.
      // We alias child tables to match the nested JSON structure expected by Produce.fromJson.
      final response = await supabase
          .from('produce')
          .select('''
            *,
            varieties:produce_varieties (
              *,
              listings:produce_variety_listing (*)
            ),
            dialects:produce_dialects (
              local_name,
              dialect:dialects (
                dialect_name
              )
            )
          ''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      // Ensure the return structure of dialects matches the model expectations.
      // ProduceDialect.fromJson expects {'dialect_name': ..., 'local_name': ...}
      final List<dynamic> rawDialects = response['dialects'] as List? ?? [];
      final List<Map<String, dynamic>> mappedDialects = rawDialects.map((d) {
        final dialectMap = d as Map<String, dynamic>;
        final innerDialect = dialectMap['dialect'] as Map<String, dynamic>?;
        return {
          'local_name': dialectMap['local_name'],
          'dialect_name': innerDialect?['dialect_name'] ?? 'Unknown',
        };
      }).toList();

      final json = Map<String, dynamic>.from(response);
      json['dialects'] = mappedDialects;

      final produce = Produce.fromJson(json);
      final listWithQtys = await _attachVarietyOfferQuantities([produce]);
      return listWithQtys.first;
    } catch (e) {
      debugPrint('❌ [ProduceRepo] fetchProduceById error: $e');
      return null;
    }
  }

  /// Fetches all produce (not favorites) via the `get_user_produce` RPC.
  /// The RPC handles dialect-aware local name lookup server-side.
  ///
  /// [userId] defaults to the current session user when omitted.
  Future<List<ProduceBasicInfo>> fetchProduceBasicInfo(
    List<String> dialects, {
    String? userId,
    String search = '',
    int offset = 0,
    int limit = 0,
  }) async {
    final uid = userId ?? supabase.auth.currentUser?.id;
    if (uid == null) return [];

    try {
      final response = await supabase.rpc(
        'get_user_produce',
        params: {
          'p_user_id': uid,
          'p_is_favorite': false,
          'p_search': search,
          'p_limit': offset,
          'p_mode': 'farmer',
        },
      );

      final map = response as Map<String, dynamic>;
      final items = map['data'] as List? ?? [];

      return items
          .map(
            (item) => ProduceBasicInfo.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('❌ [ProduceRepo] fetchProduceBasicInfo error: $e');
      return [];
    }
  }

  /// Paginated variant — returns `(items, totalCount)`.
  /// Use `offset` to fetch successive pages (page size is 10, set server-side).
  Future<(List<ProduceBasicInfo>, int)> fetchProduceBasicInfoPaged({
    String? userId,
    String search = '',
    int offset = 0,
  }) async {
    final uid = userId ?? supabase.auth.currentUser?.id;
    if (uid == null) return (<ProduceBasicInfo>[], 0);

    try {
      final response = await supabase.rpc(
        'get_user_produce',
        params: {
          'p_user_id': uid,
          'p_is_favorite': false,
          'p_search': search,
          'p_limit': offset, // server uses this as OFFSET
          'p_mode': 'farmer',
        },
      );

      final map = response as Map<String, dynamic>;
      final items = (map['data'] as List? ?? [])
          .map(
            (item) => ProduceBasicInfo.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      final total = (map['total_count'] as num?)?.toInt() ?? items.length;

      return (items, total);
    } catch (e) {
      debugPrint('❌ [ProduceRepo] fetchProduceBasicInfoPaged error: $e');
      return (<ProduceBasicInfo>[], 0);
    }
  }

  Future<void> updateProduceDialects(
    String produceId,
    List<Map<String, dynamic>> dialectsPayload,
  ) async {
    await supabase.rpc(
      'update_produce',
      params: {
        'p_user_id': supabase.auth.currentUser!.id,
        'p_id': produceId,
        'p_payload': {'dialects': dialectsPayload},
      },
    );
  }

  Future<Map<String, dynamic>> addProduceVariety(
    Map<String, dynamic> varietyData,
  ) async {
    final response = await supabase
        .from('produce_varieties')
        .upsert(varietyData)
        .select()
        .single();
    return response;
  }

  // --- Favorite Produce Management ---

  Future<List<String>> fetchFavoriteProduceIds(
    String userId,
    String? role,
  ) async {
    final table = role == 'FARMER' ? 'user_farmers' : 'user_consumers';
    try {
      final response = await supabase
          .from(table)
          .select('fav_produce')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null || response['fav_produce'] == null) return [];
      return List<String>.from(response['fav_produce'] as List);
    } catch (e) {
      //debugPrint("❌ [PRODUCE REPO] Error fetching favorites: $e");
      return [];
    }
  }

  Future<void> toggleFavorite(
    String userId,
    String? role,
    String produceId,
  ) async {
    final table = role == 'FARMER' ? 'user_farmers' : 'user_consumers';
    final currentFavorites = await fetchFavoriteProduceIds(userId, role);

    List<String> updatedFavorites;
    if (currentFavorites.contains(produceId)) {
      updatedFavorites = currentFavorites
          .where((id) => id != produceId)
          .toList();
    } else {
      updatedFavorites = [...currentFavorites, produceId];
    }

    await supabase
        .from(table)
        .update({'fav_produce': updatedFavorites})
        .eq('user_id', userId);
  }
}
