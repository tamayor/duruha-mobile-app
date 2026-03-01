import 'package:duruha/features/farmer/features/sales/domain/farmer_selected_produce.dart';
import 'package:duruha/supabase_config.dart';
import 'package:flutter/foundation.dart';

class ProducePaginatedResult {
  final List<FarmerSelectedProduce> data;
  final int totalCount;

  ProducePaginatedResult({required this.data, required this.totalCount});
}

class FarmerProduceRepository {
  Future<ProducePaginatedResult> fetchFarmerProduce(
    String userId, {
    bool favoritesOnly = true,
    String searchQuery = '',
  }) async {
    final response = await supabase.rpc(
      'get_user_produce',
      params: {
        'p_user_id': userId,
        'p_is_favorite': favoritesOnly,
        'p_search': searchQuery,
      },
    );

    final List data = response['data'] as List? ?? [];
    final int totalCount = response['total_count'] as int? ?? 0;

    final produceList = data.map((item) {
      return FarmerSelectedProduce.fromJson({
        'id': item['id'],
        'image_url': item['image_url'],
        'english_name': item['english_name'],
        'local_name': item['local_name'],
        'variety_count': item['variety_count'],
      });
    }).toList();
    debugPrint(produceList.toString());
    return ProducePaginatedResult(data: produceList, totalCount: totalCount);
  }
}
