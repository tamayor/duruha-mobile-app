import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/farmer_price_lock_subscription_model.dart';
import '../domain/farmer_price_lock_usage_model.dart';

class FarmerSubscriptionRepository {
  final supabase = Supabase.instance.client;

  Future<List<FarmerPriceLockSubscription>>
      getFarmerPriceLockSubscriptions() async {
    final response = await supabase.rpc('get_farmer_price_lock_subscriptions');

    final List<dynamic> data = response as List<dynamic>;

    return data
        .map(
          (json) =>
              FarmerPriceLockSubscription.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<FarmerPriceLockUsageDetail> getFarmerPriceLockUsageById(
    String fplsId,
  ) async {
    final response = await supabase.rpc(
      'get_farmer_price_lock_usage_by_id',
      params: {'p_fpls_id': fplsId},
    );

    return FarmerPriceLockUsageDetail.fromJson(
      response as Map<String, dynamic>,
    );
  }
}
