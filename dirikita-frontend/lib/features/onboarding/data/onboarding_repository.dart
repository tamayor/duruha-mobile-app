import 'package:duruha/shared/user/domain/user_models.dart';
import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/supabase_config.dart';

class OnboardingRepository {
  Future<UserProfile> onboarding(
    String userId,
    Map<String, dynamic> data,
  ) async {
    //debugPrint("🚀 [ONBOARDING REPO] Processing user: $userId");

    try {
      final roleStr = (data['role'] as String?)?.toUpperCase();
      String? farmerId;
      String? consumerId;

      if (roleStr == 'FARMER') {
        farmerId = await _generateFarmerId();
      } else if (roleStr == 'CONSUMER') {
        consumerId = await _generateConsumerId();
      }

      // 1. Prepare Base User Data
      final baseUpdates = <String, dynamic>{
        'role': roleStr,
        'name': data['basicInfo']?['name'],
        'phone': data['basicInfo']?['phone'],
        'barangay': data['basicInfo']?['barangay'],
        'city': data['basicInfo']?['city'],
        'province': data['basicInfo']?['province'],
        'postal_code': data['basicInfo']?['postalCode'],
        'landmark': data['basicInfo']?['landmark'],
        'dialect': data['basicInfo']?['dialects'],
        'payment_methods': data['basicInfo']?['paymentMethods'],
        'operating_days': data['basicInfo']?['operatingDays'],
        'delivery_window': data['basicInfo']?['deliveryWindow'],
        'location':
            data['basicInfo']?['latitude'] != null &&
                data['basicInfo']?['longitude'] != null
            ? 'POINT(${data['basicInfo']['longitude']} ${data['basicInfo']['latitude']})'
            : null,
      };

      // 2. Update Base Users Table
      final userResponse = await supabase
          .from('users')
          .update(baseUpdates)
          .eq('id', userId)
          .select()
          .single();

      // 3. Handle Role-Specific Extensions
      if (roleStr == 'FARMER') {
        final farmerData = data['farmerProfile'] as Map<String, dynamic>? ?? {};

        await supabase.from('user_farmers').upsert({
          'user_id': userId,
          'farmer_id': farmerId,
          'farmer_alias': farmerData['alias'],
          'land_area': double.tryParse(
            farmerData['landArea']?.toString() ?? '',
          ),
          'accessibility_type': farmerData['accessibility'],
          'water_sources': farmerData['waterSources'],
          'fav_produce': farmerData['pledges'],
        });
      } else if (roleStr == 'CONSUMER') {
        final consumerData =
            data['consumerProfile'] as Map<String, dynamic>? ?? {};

        await supabase.from('user_consumers').upsert({
          'user_id': userId,
          'consumer_id': consumerId,
          'consumer_segment': consumerData['segment'],
          'cooking_frequency': consumerData['cookingFreq'],
          'quality_preferences': consumerData['qualityPrefs'],
          'fav_produce': consumerData['demands'],
        });
      }

      // 4. Return Final Profile
      final userData = Map<String, dynamic>.from(userResponse);
      if (roleStr == 'FARMER') {
        userData['farmer_id'] = farmerId;
      } else if (roleStr == 'CONSUMER') {
        userData['consumer_id'] = consumerId;
      }

      final updatedUser = UserProfile.fromJson(userData);
      await SessionService.saveUser(updatedUser);

      return updatedUser;
    } catch (e) {
      //debugPrint("❌ [ONBOARDING REPO] Error: $e");
      throw Exception("Failed to complete onboarding: ${e.toString()}");
    }
  }

  // --- Helpers ---

  Future<String> _generateFarmerId() async {
    try {
      final response = await supabase
          .from('user_farmers')
          .select('farmer_id')
          .order('farmer_id', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return 'farmer_000001';

      final lastId = response['farmer_id'] as String;
      // Format: farmer_000001
      final parts = lastId.split('_');
      if (parts.length < 2) return 'farmer_000001';

      final lastNum = int.tryParse(parts[1]) ?? 0;
      final nextNum = lastNum + 1;
      return 'farmer_${nextNum.toString().padLeft(6, '0')}';
    } catch (e) {
      //debugPrint("⚠️ [ONBOARDING REPO] Error generating farmer_id: $e");
      return 'farmer_000001'; // Fallback
    }
  }

  Future<String> _generateConsumerId() async {
    try {
      final response = await supabase
          .from('user_consumers')
          .select('consumer_id')
          .order('consumer_id', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return 'consumer_000001';

      final lastId = response['consumer_id'] as String;
      // Format: consumer_000001
      final parts = lastId.split('_');
      if (parts.length < 2) return 'consumer_000001';

      final lastNum = int.tryParse(parts[1]) ?? 0;
      final nextNum = lastNum + 1;
      return 'consumer_${nextNum.toString().padLeft(6, '0')}';
    } catch (e) {
      //debugPrint("⚠️ [ONBOARDING REPO] Error generating consumer_id: $e");
      return 'consumer_000001'; // Fallback
    }
  }
}
