import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/price_lock_subscription_model.dart';
import 'package:flutter/foundation.dart';

class SubscriptionRepository {
  final _supabase = Supabase.instance.client;

  Future<PriceLockUsageResponse> getConsumerPriceLockUsage(
    String cplsId,
  ) async {
    try {
      final response = await _supabase.rpc(
        'get_consumer_price_lock_usage_by_id',
        params: {'p_cpls_id': cplsId},
      );

      // We expect the RPC to return a single JSON object.
      // If it returns a list of one object, we extract it.
      Map<String, dynamic> data;
      if (response is List && response.isNotEmpty) {
        data = response.first as Map<String, dynamic>;
      } else if (response is Map<String, dynamic>) {
        data = response;
      } else {
        throw Exception(
          "Unknown response type from RPC: ${response.runtimeType}",
        );
      }

      return PriceLockUsageResponse.fromJson(data);
    } catch (e) {
      debugPrint('Error getting consumer price lock usage: $e');
      rethrow;
    }
  }

  Future<List<PriceLockSubscription>>
  getConsumerPriceLockSubscriptions() async {
    try {
      final response = await _supabase.rpc(
        'get_consumer_price_lock_subscriptions',
      );

      if (response is List) {
        return response
            .map(
              (item) =>
                  PriceLockSubscription.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }

      throw Exception(
        "Unknown response type from RPC: ${response.runtimeType}",
      );
    } catch (e) {
      debugPrint('Error getting consumer price lock subscriptions: $e');
      rethrow;
    }
  }
}
