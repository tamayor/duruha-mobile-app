import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duruha/features/farmer/features/manage/offers/domain/offer_model.dart';
import 'package:duruha/supabase_config.dart';
import 'dart:convert';
import 'package:flutter/material.dart';

class ManageOfferRepository {
  /// Fetches date-grouped offers from the `get_farmer_offers` RPC.
  /// [active] = true → active offers tab; false → history tab.
  /// [cursor] = ISO8601 timestamp of the last item seen (null = first page).
  /// Returns ({groups, hasMore}).
  Future<({List<DailyOfferGroup> groups, bool hasMore})> fetchOffers({
    required bool active,
    String? cursor,
  }) async {
    try {
      final response = await supabase.rpc(
        'get_farmer_offers',
        params: {
          'p_active': active,
          if (cursor != null) 'p_cursor': cursor,
          'p_limit': 10,
        },
      );

      final data = response as Map<String, dynamic>?;
      if (data == null) return (groups: <DailyOfferGroup>[], hasMore: false);

      final offersRaw = data['offers'] as List? ?? [];
      final hasMore = data['has_more'] as bool? ?? false;

      final groups = offersRaw
          .map((e) => DailyOfferGroup.fromJson(e as Map<String, dynamic>))
          .toList();

      return (groups: groups, hasMore: hasMore);
    } catch (e) {
      debugPrint('❌ [API ERROR] fetchOffers: $e');
      return (groups: <DailyOfferGroup>[], hasMore: false);
    }
  }

  /// Fetches orders associated with a specific harvest offer ID, along with metadata/summary.
  Future<({List<FarmerOfferOrder> orders, Map<String, dynamic>? summary})>
  fetchOrdersByOfferId(String offerId) async {
    try {
      debugPrint("offerId: $offerId");
      final response = await supabase.rpc(
        'get_farmer_offer_orders',
        params: {'p_offer_id': offerId},
      );

      debugPrint("RPC raw response type: ${response.runtimeType}");
      debugPrint("RPC raw response: $response");

      Map<String, dynamic>? data;
      if (response is String) {
        final decoded = jsonDecode(response);
        if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      } else if (response is Map) {
        data = Map<String, dynamic>.from(response);
      }

      if (data == null || data['orders'] == null) {
        debugPrint("No orders found in data.");
        return (orders: <FarmerOfferOrder>[], summary: null);
      }

      final ordersRaw = data['orders'] as List;
      debugPrint("orders amount: ${ordersRaw.length}");
      final ordersList = ordersRaw
          .map((row) => FarmerOfferOrder.fromJson(row as Map<String, dynamic>))
          .toList();

      data.remove('orders'); // The remaining data is the summary.

      return (orders: ordersList, summary: data);
    } catch (e, st) {
      debugPrint("❌ [API ERROR] fetchOrdersByOfferId: $e\n$st");
      return (orders: <FarmerOfferOrder>[], summary: null);
    }
  }

  /// Updates the delivery status of a specific order.
  Future<bool> updateOrderDeliveryStatus(
    String orderItemId,
    String status,
  ) async {
    try {
      debugPrint("orderId: $orderItemId");
      await supabase
          .from('offer_order_match_items')
          .update({'delivery_status': status})
          .eq('id', orderItemId);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print("❌ [API ERROR] updateOrderDeliveryStatus: $e");
      return false;
    }
  }

  /// Updates the delivery status of multiple orders.
  Future<bool> updateOrdersDeliveryStatus(
    List<String> orderIds,
    String? status,
    DateTime? dispatchAt,
  ) async {
    try {
      final updateData = <String, dynamic>{'delivery_status': status};
      if (dispatchAt != null) {
        updateData['dispatch_at'] = dispatchAt.toIso8601String();
      }

      await supabase
          .from('farmer_offer_orders')
          .update(updateData)
          .inFilter('id', orderIds);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print("❌ [API ERROR] updateOrdersDeliveryStatus: $e");
      return false;
    }
  }

  /// Updates the dispatch date of multiple orders.
  Future<bool> updateOrdersDispatchDate(
    List<String> orderIds,
    DateTime dispatchAt,
  ) async {
    try {
      await supabase
          .from('farmer_offer_orders')
          .update({'dispatch_at': dispatchAt.toIso8601String()})
          .inFilter('id', orderIds);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print("❌ [API ERROR] updateOrdersDispatchDate: $e");
      return false;
    }
  }

  /// Fetches a single offer by ID via a direct database query.
  Future<HarvestOffer?> fetchOfferById(String offerId) async {
    try {
      final response = await supabase
          .from('farmer_offers')
          .select('''
            *,
            farmer_price_lock_subscriptions(
              status
            ),
            produce_varieties (
              variety_name
            )
          ''')
          .eq('offer_id', offerId)
          .single();

      // Construct a JSON map compatible with HarvestOffer.fromJson
      final Map<String, dynamic> offerData = Map<String, dynamic>.from(
        response,
      );

      // Flatten the fpls_status from the joined table
      if (offerData['farmer_price_lock_subscriptions'] != null) {
        offerData['fpls_status'] =
            offerData['farmer_price_lock_subscriptions']['status'];
      }

      // Flatten the variety_name from the joined table
      if (offerData['produce_varieties'] != null) {
        offerData['variety_name'] =
            offerData['produce_varieties']['variety_name'];
      }

      return HarvestOffer.fromJson(offerData);
    } catch (e) {
      debugPrint('❌ [API ERROR] fetchOfferById: $e');
      return null;
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
        'update_farmer_offer_status',
        params: {
          'p_offer_id': offerId,
          'p_mode': mode,
          if (update != null) 'p_update': update,
        },
      );
      return response as String?;
    } catch (e) {
      debugPrint("❌ [API ERROR] updateOfferStatus ($mode): $e");
      if (e is PostgrestException) {
        return "Error: ${e.message}";
      }
      return "Error: $e";
    }
  }
}
