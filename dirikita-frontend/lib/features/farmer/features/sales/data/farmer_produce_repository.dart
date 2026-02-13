import 'package:duruha/features/farmer/features/sales/domain/farmer_selected_produce.dart';
import 'package:duruha/supabase_config.dart';

class FarmerProduceRepository {
  Future<List<FarmerSelectedProduce>> fetchFarmerSelectedProduce(
    //String farmerId,
    String dialect,
  ) async {
    final response = await supabase
        .from('produce')
        .select('''
        id,
        image_url,
        english_name,
        produce_dialects (
          local_name,
          dialects!inner (
            dialect_name
          )
        )
      ''')
        .eq('produce_dialects.dialects.dialect_name', dialect);

    return (response as List).map((item) {
      final dialects = item['produce_dialects'] as List? ?? [];
      final localName = dialects.isNotEmpty
          ? dialects[0]['local_name']?.toString() ??
                item['english_name'].toString()
          : item['english_name'].toString();

      return FarmerSelectedProduce.fromJson({
        'id': item['id'].toString(),
        'image_url': item['image_url'] ?? '',
        'english_name': item['english_name'].toString(),
        'local_name': localName,
        'total_30_days_demand': (item['total_30_days_demand'] ?? 0.0)
            .toDouble(),
      });
    }).toList();
  }
}
