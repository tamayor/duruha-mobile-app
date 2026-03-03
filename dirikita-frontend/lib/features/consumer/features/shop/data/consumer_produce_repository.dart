import 'package:duruha/features/consumer/features/shop/domain/consumer_selected_produce.dart';
import 'package:duruha/supabase_config.dart';
import 'package:flutter/foundation.dart';

/// Fetches produce for the consumer shop.
///
/// Uses the [get_user_produce] RPC with [p_mode = 'consumer'], which returns:
///   • id, image_url, english_name, local_name, scientific_name,
///     category, base_unit
///   • variety_count           — total varieties for this produce
///   • variety_count_available — varieties with ≥1 active offer (next 30 days)
///   • avg_30d_offer_qty       — avg remaining_quantity across those offers
///
/// Response envelope: { "data": [...], "total_count": N }
class ConsumerProduceRepository {
  /// Fetches one page of produce for the consumer shop.
  ///
  /// Returns `(items, totalCount)`. Stop loading more when
  /// `items loaded so far >= totalCount`.
  Future<(List<ConsumerSelectedProduce>, int)> fetchProducePage({
    required String userId,
    int offset = 0,
    bool favoritesOnly = false,
    String search = '',
  }) async {
    try {
      final response = await supabase.rpc(
        'get_user_produce',
        params: {
          'p_is_favorite': favoritesOnly,
          'p_search': search,
          'p_offset': offset,
        },
      );

      if (response == null) return (<ConsumerSelectedProduce>[], 0);

      final data = response['data'] as List? ?? [];
      final totalCount =
          (response['total_count'] as num?)?.toInt() ?? data.length;

      final items = data
          .map(
            (item) =>
                ConsumerSelectedProduce.fromJson(item as Map<String, dynamic>),
          )
          .toList();

      return (items, totalCount);
    } catch (e) {
      debugPrint('❌ [ConsumerProduceRepo] fetchProducePage error: $e');
      return (<ConsumerSelectedProduce>[], 0);
    }
  }
}
