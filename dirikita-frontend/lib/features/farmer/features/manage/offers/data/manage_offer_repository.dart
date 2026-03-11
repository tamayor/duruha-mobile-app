import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duruha/features/farmer/features/manage/offers/domain/offer_model.dart';
import 'package:duruha/supabase_config.dart';
import 'dart:convert';
import 'package:flutter/material.dart';

/// Sort options matching the SQL p_sort parameter.
enum OfferSort {
  dateDesc,
  dateAsc,
  reservedDesc,
  reservedAsc,
  availFromAsc,
  availFromDesc,
  availToAsc,
  availToDesc,
}

extension OfferSortExt on OfferSort {
  String get param => switch (this) {
    OfferSort.dateDesc => 'date_desc',
    OfferSort.dateAsc => 'date_asc',
    OfferSort.reservedDesc => 'reserved_desc',
    OfferSort.reservedAsc => 'reserved_asc',
    OfferSort.availFromAsc => 'avail_from_asc',
    OfferSort.availFromDesc => 'avail_from_desc',
    OfferSort.availToAsc => 'avail_to_asc',
    OfferSort.availToDesc => 'avail_to_desc',
  };

  String get label => switch (this) {
    OfferSort.reservedDesc => 'Reserved — most first',
    OfferSort.reservedAsc => 'Reserved — least first',
    OfferSort.dateDesc => 'Created — newest first',
    OfferSort.dateAsc => 'Created — oldest first',
    OfferSort.availFromAsc => 'Start date — earliest first',
    OfferSort.availFromDesc => 'Start date — latest first',
    OfferSort.availToAsc => 'End date — earliest first',
    OfferSort.availToDesc => 'End date — latest first',
  };

  /// Whether the cursor value for this sort is a timestamp field.
  bool get cursorIsTimestamp => switch (this) {
    OfferSort.reservedDesc || OfferSort.reservedAsc => false,
    _ => true,
  };

  /// Extract the cursor value string from the last offer for this sort.
  String? cursorVal(FlatOffer last) => switch (this) {
    OfferSort.dateDesc ||
    OfferSort.dateAsc => last.offer.createdAt.toIso8601String(),
    OfferSort.reservedDesc ||
    OfferSort.reservedAsc => last.offer.reservedQty.toString(),
    OfferSort.availFromAsc ||
    OfferSort.availFromDesc => last.offer.availableFrom.toIso8601String(),
    OfferSort.availToAsc ||
    OfferSort.availToDesc => last.offer.availableTo.toIso8601String(),
  };
}

class ManageOfferRepository {
  /// Fetches a flat list of offers from `get_farmer_offers`.
  /// Supports search, sort, date-range filter, and keyset pagination.
  Future<({List<FlatOffer> offers, bool hasMore})> fetchOffers({
    required bool active,
    String? cursorVal,
    String? cursorId,
    String? search,
    OfferSort sort = OfferSort.dateDesc,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final response = await supabase.rpc(
        'get_farmer_offers',
        params: {
          'p_active': active,
          'p_limit': 20,
          if (cursorVal != null) 'p_cursor_val': cursorVal,
          if (cursorId != null) 'p_cursor_id': cursorId,
          if (search != null && search.isNotEmpty) 'p_search': search,
          'p_sort': sort.param,
          if (dateFrom != null)
            'p_date_from': dateFrom.toIso8601String().substring(0, 10),
          if (dateTo != null)
            'p_date_to': dateTo.toIso8601String().substring(0, 10),
        },
      );

      final data = response as Map<String, dynamic>?;
      if (data == null) return (offers: <FlatOffer>[], hasMore: false);

      final offersRaw = data['offers'] as List? ?? [];
      final hasMore = data['has_more'] as bool? ?? false;

      final offers = offersRaw
          .map((e) => FlatOffer.fromJson(e as Map<String, dynamic>))
          .toList();

      return (offers: offers, hasMore: hasMore);
    } catch (e) {
      debugPrint('❌ [API ERROR] fetchOffers: $e');
      return (offers: <FlatOffer>[], hasMore: false);
    }
  }

  /// Fetches full offer detail (offer fields + orders + summary) in one RPC call.
  /// This replaces the previous fetchOrdersByOfferId + fetchOfferById pair.
  Future<OfferDetail?> fetchOfferDetail(String offerId) async {
    try {
      final response = await supabase.rpc(
        'get_farmer_offer_by_id',
        params: {'p_offer_id': offerId},
      );

      Map<String, dynamic>? data;
      if (response is String) {
        final decoded = jsonDecode(response);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } else if (response is Map) {
        data = Map<String, dynamic>.from(response);
      }

      if (data == null) return null;
      return OfferDetail.fromJson(data);
    } catch (e, st) {
      debugPrint('❌ [API ERROR] fetchOfferDetail: $e\n$st');
      return null;
    }
  }

  /// Updates offer orders' delivery status and/or dispatch date via the RPC.
  /// Works for a single order or bulk — pass one or more [orderIds].
  /// At least one of [deliveryStatus] or [dispatchAt] must be provided.
  /// Returns the message from the database, or an error string.
  Future<String?> updateOfferOrders({
    required String offerId,
    required List<String> orderIds,
    String? deliveryStatus,
    DateTime? dispatchAt,
  }) async {
    assert(
      deliveryStatus != null || dispatchAt != null,
      'At least one of deliveryStatus or dispatchAt must be provided.',
    );
    try {
      final response = await supabase.rpc(
        'update_farmer_offer_details',
        params: {
          'p_offer_id': offerId,
          'p_mode': 'update_orders',
          'p_order_ids': orderIds,
          if (deliveryStatus != null) 'p_delivery_status': deliveryStatus,
          if (dispatchAt != null) 'p_dispatch_at': dispatchAt.toIso8601String(),
        },
      );
      return response as String?;
    } catch (e) {
      debugPrint('❌ [API ERROR] updateOfferOrders: $e');
      if (e is PostgrestException) return 'Error: ${e.message}';
      return 'Error: $e';
    }
  }

  /// Updates an offer's status (delete, activate, or update) using the RPC.
  /// Returns the message from the database.
  Future<String?> updateOfferStatus({
    required String offerId,
    required String mode,
    Map<String, dynamic>? update,
  }) async {
    try {
      final response = await supabase.rpc(
        'update_farmer_offer_details',
        params: {
          'p_offer_id': offerId,
          'p_mode': mode,
          if (update != null) 'p_update': update,
        },
      );
      return response as String?;
    } catch (e) {
      debugPrint('❌ [API ERROR] updateOfferStatus ($mode): $e');
      if (e is PostgrestException) {
        return 'Error: ${e.message}';
      }
      return 'Error: $e';
    }
  }
}
