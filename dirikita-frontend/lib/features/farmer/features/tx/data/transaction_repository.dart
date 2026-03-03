import 'package:duruha/supabase_config.dart';
import 'package:flutter/foundation.dart';
import '../../../../../shared/produce/domain/produce_model.dart';
import '../../../shared/domain/farmer_price_lock_subscription_model.dart';
import 'transaction_draft_service.dart';

class TransactionRepository {
  /// Submits offers via the `create_farmer_offers` RPC.
  ///
  /// The RPC handles authentication server-side — it resolves the farmer_id
  /// from auth.uid() so we never send farmer_id from the client.
  ///
  /// Each [OfferFormEntry] maps to one offer row:
  ///   variety_id, listing_id, quantity, available_from, available_to
  Future<(bool, String)> submitOffers({
    required List<Produce> selectedProduce,
    required Map<String, List<OfferFormEntry>> produceOfferEntries,
  }) async {
    try {
      final List<Map<String, dynamic>> payload = [];

      for (final produce in selectedProduce) {
        final entries = produceOfferEntries[produce.id] ?? [];

        for (final entry in entries) {
          if (entry.quantity <= 0) continue;

          final variety = produce.availableVarieties.firstWhere(
            (v) => v.name == entry.varietyName,
            orElse: () => produce.availableVarieties.first,
          );

          payload.add({
            'variety_id': variety.id,
            'listing_id': entry.listingId.isEmpty ? null : entry.listingId,
            'quantity': entry.quantity,
            'available_from': entry.availableFrom?.toIso8601String(),
            'available_to': entry.availableTo?.toIso8601String(),
            'is_price_lock': entry.isPriceLock,
            'fpls_id': entry.fplsId,
            'total_price_lock_credit': entry.totalPriceLockCredit,
          });
        }
      }

      if (payload.isEmpty) return (true, 'No offers to submit');

      final result = await supabase.rpc(
        'create_farmer_offers',
        params: {'p_offers': payload},
      );

      // The RPC returns { 'inserted': int }
      final inserted = (result as Map?)?['inserted'] ?? payload.length;
      final message =
          '$inserted offer${inserted == 1 ? '' : 's'} submitted successfully!';

      debugPrint('✅ [RPC] create_farmer_offers: $result');
      return (true, message);
    } catch (e) {
      debugPrint('❌ [RPC ERROR] submitOffers: $e');
      return (false, 'Submission failed: ${e.toString()}');
    }
  }

  /// Fetches the currently active price lock subscription for the farmer, if any.
  Future<FarmerPriceLockSubscription?> fetchActivePriceLockSubscription(
    String farmerId,
  ) async {
    try {
      final response = await supabase
          .from('farmer_price_lock_subscriptions')
          .select('''
            *,
            farmer_price_lock_configs (
              plan_name,
              monthly_credit_limit,
              fee
            )
          ''')
          .eq('farmer_id', farmerId)
          .eq('status', 'active')
          .maybeSingle();

      if (response == null) return null;

      return FarmerPriceLockSubscription.fromJson(response);
    } catch (e) {
      debugPrint('❌ [RPC ERROR] fetchActivePriceLockSubscription: $e');
      return null;
    }
  }

  /// Fetches all price lock subscriptions for the farmer.
  Future<List<FarmerPriceLockSubscription>> fetchAllPriceLockSubscriptions(
    String farmerId,
  ) async {
    try {
      final response = await supabase
          .from('farmer_price_lock_subscriptions')
          .select('''
            *,
            farmer_price_lock_configs (
              plan_name,
              monthly_credit_limit,
              fee
            )
          ''')
          .eq('farmer_id', farmerId)
          .order('status', ascending: true) // we'll sort more precisely in dart
          .order('remaining_credits', ascending: false);

      return (response as List)
          .map((data) => FarmerPriceLockSubscription.fromJson(data))
          .toList();
    } catch (e) {
      debugPrint('❌ [RPC ERROR] fetchAllPriceLockSubscriptions: $e');
      return [];
    }
  }
}
