import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/supabase_config.dart';
import '../domain/order_details_model.dart';
import 'package:flutter/foundation.dart';

class OrdersRepository {
  Future<ConsumerOrderMatchResponse> fetchOrderMatches({
    int limit = 10,
    String? cursor,
    bool isActive = true,
  }) async {
    try {
      final response = await supabase.rpc(
        'get_consumer_orders',
        params: {
          'p_limit': limit,
          'p_is_active': isActive,
          if (cursor != null) 'p_cursor': cursor,
        },
      );
      if (response == null) {
        return ConsumerOrderMatchResponse(orders: [], pagination: null);
      }
      return ConsumerOrderMatchResponse.fromJson(
        response as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('❌ [fetchOrderMatches ERROR]: $e');
      rethrow;
    }
  }

  Future<ConsumerOrderMatch> fetchOrderDetails(String orderId) async {
    try {
      final response = await supabase.rpc(
        'get_consumer_order_by_id',
        params: {'p_order_id': orderId},
      );
      if (response == null) {
        throw Exception('Order details not found for ID: $orderId');
      }
      return ConsumerOrderMatch.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('❌ [fetchOrderDetails ERROR]: $e');
      rethrow;
    }
  }

  Future<void> deleteOrderMatch(String matchId) async {
    try {
      final roleId = await SessionService.getRoleId();
      if (roleId == null) throw Exception("User is not authenticated");

      final response = await supabase.rpc(
        'update_consumer_order',
        params: {'p_order_id': matchId, 'p_mode': 'delete'},
      );
      final data = response as Map<String, dynamic>?;
      if (data != null && data['success'] == false) {
        throw Exception(data['message'] ?? 'Failed to delete order');
      }
      debugPrint('✅ [DELETE ORDER SUCCESS]: $matchId');
    } catch (e) {
      debugPrint('❌ [DELETE ORDER ERROR]: $e');
      rethrow;
    }
  }

  Future<void> cancelOrderMatch(String orderId) async {
    try {
      final roleId = await SessionService.getRoleId();
      if (roleId == null) throw Exception("User is not authenticated");

      final response = await supabase.rpc(
        'update_consumer_order',
        params: {'p_order_id': orderId, 'p_mode': 'cancel'},
      );
      final data = response as Map<String, dynamic>?;
      if (data != null && data['success'] == false) {
        throw Exception(data['message'] ?? 'Failed to cancel order');
      }
      debugPrint('✅ [CANCEL ORDER SUCCESS]: $orderId');
    } catch (e) {
      debugPrint('❌ [CANCEL ORDER ERROR]: $e');
      rethrow;
    }
  }

  Future<void> cancelSingleOrderMatchItem(String orderId, String oomId) async {
    try {
      final roleId = await SessionService.getRoleId();
      if (roleId == null) throw Exception("User is not authenticated");

      final response = await supabase.rpc(
        'update_consumer_order',
        params: {
          'p_order_id': orderId,
          'p_mode': 'cancel',
          'p_specific_oom_id': oomId,
        },
      );
      final data = response as Map<String, dynamic>?;
      if (data != null && data['success'] == false) {
        throw Exception(data['message'] ?? 'Failed to cancel item');
      }
      debugPrint('✅ [CANCEL OOM SUCCESS]: $oomId in order $orderId');
    } catch (e) {
      debugPrint('❌ [CANCEL OOM ERROR]: $e');
      rethrow;
    }
  }
}
