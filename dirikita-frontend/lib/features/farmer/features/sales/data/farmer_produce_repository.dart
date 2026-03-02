import 'package:duruha/features/farmer/features/sales/domain/farmer_selected_produce.dart';
import 'package:duruha/supabase_config.dart';
import 'package:flutter/foundation.dart';

class ProducePaginatedResult {
  final List<FarmerSelectedProduce> data;
  final int totalCount;
  final int? nextOffset;
  final bool hasMore;

  ProducePaginatedResult({
    required this.data,
    required this.totalCount,
    this.nextOffset,
    this.hasMore = false,
  });
}

class FarmerProduceRepository {
  Future<ProducePaginatedResult> fetchFarmerProduce({
    bool favoritesOnly = true,
    String searchQuery = '',
    int offset = 0,
  }) async {
    final response = await supabase.rpc(
      'get_user_produce',
      params: {
        'p_is_favorite': favoritesOnly,
        'p_search': searchQuery,
        'p_offset': offset,
      },
    );

    final List data = response['data'] as List? ?? [];
    final int totalCount = response['total_count'] as int? ?? 0;

    final bool hasMore = response['has_more'] as bool? ?? false;
    final int? nextOffset = response['next_offset'] as int?;

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

    return ProducePaginatedResult(
      data: produceList,
      totalCount: totalCount,
      hasMore: hasMore,
      nextOffset: nextOffset,
    );
  }
}
