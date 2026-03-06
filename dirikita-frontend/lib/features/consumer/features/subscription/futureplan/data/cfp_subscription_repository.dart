import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/consumer_future_plan_subscription_model.dart';

class ConsumerFuturePlanRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<ConsumerFuturePlanSubscription>>
  fetchAllFuturePlanSubscriptions() async {
    try {
      final response = await _supabase.rpc(
        'get_consumer_future_plan_subscriptions',
      );

      return (response as List)
          .map((json) => ConsumerFuturePlanSubscription.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching CFP subscriptions: $e');
      rethrow;
    }
  }

  Future<FuturePlanUsage> fetchFuturePlanUsage(String cfpsId) async {
    try {
      final response = await _supabase.rpc(
        'get_consumer_future_plan_usage_by_id',
        params: {'p_cfps_id': cfpsId},
      );

      return FuturePlanUsage.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error fetching CFP usage for $cfpsId: $e');
      rethrow;
    }
  }
}
