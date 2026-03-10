import 'package:duruha/features/farmer/features/main/domain/find_orders_model.dart';
import 'package:duruha/supabase_config.dart';

class FindOrdersRepository {
  Future<FindOrdersResult> findOrders({
    String mode = 'near_me',
    double radiusKm = 10,
    int page = 1,
    int pageSize = 10,
  }) async {
    final dynamic response = await supabase.rpc(
      'find_orders',
      params: {
        'p_mode': mode,
        'p_radius_km': radiusKm,
        'p_page': page,
        'p_page_size': pageSize,
      },
    );

    if (response == null) {
      throw Exception('find_orders returned null');
    }

    // Supabase may return a LinkedHashMap or Map — normalise recursively
    final Map<String, dynamic> json = _deepCast(response);
    return FindOrdersResult.fromJson(json);
  }

  Future<bool> submitPledges({
    required String orderId,
    required List<Map<String, dynamic>> pledges,
  }) async {
    try {
      // ignore: avoid_print
      print('🚀 [PLEDGE REQUEST] Payload: orderId=$orderId, pledges=$pledges');

      await supabase.rpc(
        'create_farmer_pledges',
        params: {'p_order_id': orderId, 'p_pledges': pledges},
      );
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('❌ [API ERROR] create_farmer_pledges: $e');
      return false;
    }
  }

  /// Recursively converts all Maps to Map<String, dynamic>
  static Map<String, dynamic> _deepCast(dynamic value) {
    if (value is Map) {
      return value.map(
        (k, v) => MapEntry(
          k.toString(),
          v is Map
              ? _deepCast(v)
              : v is List
              ? _deepCastList(v)
              : v,
        ),
      );
    }
    throw Exception('Expected a Map, got ${value.runtimeType}');
  }

  static List<dynamic> _deepCastList(List<dynamic> list) {
    return list.map((e) {
      if (e is Map) return _deepCast(e);
      if (e is List) return _deepCastList(e);
      return e;
    }).toList();
  }
}
