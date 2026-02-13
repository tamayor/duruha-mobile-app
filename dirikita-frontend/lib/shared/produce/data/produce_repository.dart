import 'package:duruha/shared/produce/domain/produce_basic_info.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/supabase_config.dart';

class ProduceRepository {
  Future<List<Produce>> fetchProduce() async {
    final response = await supabase.from('produce_master_view').select();

    return (response as List).map((json) => Produce.fromJson(json)).toList();
  }

  // Compatibility Alias
  Future<List<Produce>> getAllProduce() => fetchProduce();

  Future<Produce?> fetchProduceById(String id) async {
    try {
      final response = await supabase
          .from('produce_master_view')
          .select()
          .eq('id', id)
          .maybeSingle(); // Returns null if not found, rather than throwing error
      if (response == null) return null;
      return Produce.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<List<ProduceBasicInfo>> fetchProduceBasicInfo(
    List<String> dialects,
  ) async {
    // If no dialects provided, just fetch English names
    // Or default to 'Tagalog' if empty list
    final targetDialects = dialects.isEmpty ? ['Tagalog'] : dialects;

    final response = await supabase
        .from('produce')
        .select('''
        id,
        image_url,
        english_name,
        scientific_name,
        produce_dialects (
          local_name,
          dialects!inner (
            dialect_name
          )
        )
      ''')
        .inFilter('produce_dialects.dialects.dialect_name', targetDialects);

    return (response as List).map((item) {
      final itemDialects = item['produce_dialects'] as List? ?? [];

      // Find best match based on priority of targetDialects
      String displayName = item['english_name'].toString();

      if (itemDialects.isNotEmpty) {
        for (final target in targetDialects) {
          final match = itemDialects.firstWhere(
            (d) =>
                d['dialects']['dialect_name'].toString().toLowerCase() ==
                target.toLowerCase(),
            orElse: () => null,
          );

          if (match != null) {
            displayName = match['local_name'].toString();
            break; // Found highest priority match
          }
        }
      }

      return ProduceBasicInfo.fromJson({
        'id': item['id'].toString(),
        'image_url': item['image_url'] ?? '',
        'english_name': item['english_name'].toString(),
        'local_name': displayName,
        'scientific_name': item['scientific_name'].toString(),
      });
    }).toList();
  }

  Future<void> updateProduceLocalName(
    String produceId,
    String dialectName,
    String localName,
  ) async {
    // 1. Get dialect ID
    final dialectResponse = await supabase
        .from('dialects')
        .select('id')
        .eq('dialect_name', dialectName)
        .maybeSingle();

    if (dialectResponse == null) {
      throw Exception('Dialect not found');
    }

    final dialectId = dialectResponse['id'];

    // 2. Upsert produce_dialect
    await supabase.from('produce_dialects').upsert({
      'produce_id': produceId,
      'dialect_id': dialectId,
      'local_name': localName,
    }, onConflict: 'produce_id, dialect_id');
  }

  Future<int> getVarietyCount(String produceId) async {
    final response = await supabase
        .from('produce_varieties')
        .select('variety_id')
        .eq('produce_id', produceId);

    return (response as List).length;
  }

  Future<void> addProduceVariety(Map<String, dynamic> varietyData) async {
    await supabase.from('produce_varieties').upsert(varietyData);
  }
}
