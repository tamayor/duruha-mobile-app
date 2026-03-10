import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:duruha/supabase_config.dart';
import 'package:duruha/features/farmer/features/manage/pledges/domain/pledge_model.dart';

class ManagePledgeRepository {
  Future<({List<FarmerPledgeGroup> pledges, int totalCount})> fetchPledges({
    required String farmerId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      debugPrint('🔍 [PLEDGE REPO] Fetching for farmer: $farmerId');
      final response = await supabase.rpc(
        'get_farmer_pledges',
        params: {'p_farmer_id': farmerId, 'p_limit': limit, 'p_offset': offset},
      );

      debugPrint('✅ [PLEDGE REPO] Raw Response Type: ${response.runtimeType}');

      Map<String, dynamic>? data;
      if (response is Map) {
        data = Map<String, dynamic>.from(response);
      } else if (response is String) {
        data = Map<String, dynamic>.from(jsonDecode(response));
      }

      if (data == null) {
        debugPrint('⚠️ [PLEDGE REPO] Data is null or invalid format');
        return (pledges: <FarmerPledgeGroup>[], totalCount: 0);
      }

      final pledgesRaw = data['pledges'] as List? ?? [];
      final pagination = data['pagination'] as Map<String, dynamic>? ?? {};
      final totalCount = pagination['count'] as int? ?? 0;

      debugPrint('📊 [PLEDGE REPO] Parsing ${pledgesRaw.length} groups');

      final pledges = pledgesRaw
          .map((e) => FarmerPledgeGroup.fromJson(e as Map<String, dynamic>))
          .toList();

      return (pledges: pledges, totalCount: totalCount);
    } catch (e, st) {
      debugPrint('❌ [API ERROR] fetchPledges: $e\n$st');
      return (pledges: <FarmerPledgeGroup>[], totalCount: 0);
    }
  }
}
