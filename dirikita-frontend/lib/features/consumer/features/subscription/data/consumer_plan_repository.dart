import 'package:duruha/supabase_config.dart';
import 'package:flutter/foundation.dart';
import '../domain/consumer_plan_subscription_model.dart';

class ConsumerPlanRepository {
  final _supabase = supabase;

  /// Fetches the consumer's active plan from the view (already filtered to active + not expired).
  Future<ConsumerPlanSubscription?> getActivePlan(String consumerId) async {
    try {
      final response = await _supabase
          .from('v_consumer_active_plan')
          .select()
          .eq('consumer_id', consumerId)
          .maybeSingle();

      if (response == null) return null;
      return ConsumerPlanSubscription.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    } catch (e) {
      debugPrint('Error fetching active plan: $e');
      rethrow;
    }
  }

  /// Fetches all plan subscriptions for the consumer (all statuses).
  Future<List<ConsumerPlanSubscription>> getAllPlans(String consumerId) async {
    try {
      final response = await _supabase
          .from('consumer_plan_subscriptions')
          .select('''
            cps_id,
            consumer_id,
            cpc_id,
            status,
            starts_at,
            ends_at,
            trial_ends_at,
            remaining_credits,
            renew_count,
            last_renewed_at,
            consumer_plan_configs (
              tier,
              billing_interval,
              plan_name,
              fee,
              monthly_equivalent,
              monthly_credit_limit,
              max_order_value,
              min_order_value,
              quality_level,
              schedule_window_days
            )
          ''')
          .eq('consumer_id', consumerId)
          .order('created_at', ascending: false);

      return (response as List).map((item) {
        final json = Map<String, dynamic>.from(item as Map);
        final rawConfig = json['consumer_plan_configs'];
        Map<String, dynamic> config = {};

        if (rawConfig is List && rawConfig.isNotEmpty) {
          config = Map<String, dynamic>.from(rawConfig[0]);
        } else if (rawConfig is Map) {
          config = Map<String, dynamic>.from(rawConfig);
        }

        return ConsumerPlanSubscription.fromJson({...json, ...config});
      }).toList();
    } catch (e) {
      debugPrint('Error fetching all plans: $e');
      rethrow;
    }
  }

  /// Fetches a single subscription by ID (for details screen).
  Future<ConsumerPlanSubscription?> getSubscriptionById(String cpsId) async {
    try {
      final response = await _supabase
          .from('consumer_plan_subscriptions')
          .select('''
            cps_id,
            consumer_id,
            cpc_id,
            status,
            starts_at,
            ends_at,
            trial_ends_at,
            remaining_credits,
            renew_count,
            last_renewed_at,
            consumer_plan_configs (
              tier,
              billing_interval,
              plan_name,
              fee,
              monthly_equivalent,
              monthly_credit_limit,
              max_order_value,
              min_order_value,
              quality_level
            )
          ''')
          .eq('cps_id', cpsId)
          .maybeSingle();

      if (response == null) return null;
      final json = Map<String, dynamic>.from(response as Map);
      final rawConfig = json['consumer_plan_configs'];
      Map<String, dynamic> config = {};

      if (rawConfig is List && rawConfig.isNotEmpty) {
        config = Map<String, dynamic>.from(rawConfig[0]);
      } else if (rawConfig is Map) {
        config = Map<String, dynamic>.from(rawConfig);
      }

      return ConsumerPlanSubscription.fromJson({...json, ...config});
    } catch (e) {
      debugPrint('Error fetching subscription by ID: $e');
      rethrow;
    }
  }
}
