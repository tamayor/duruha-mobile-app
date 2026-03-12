import 'dart:io';
import 'package:duruha/supabase_config.dart';
import 'package:duruha/features/consumer/features/profile/domain/profile_model.dart';

/// Calls the unified `manage_profile` RPC on Supabase.
/// Handles both GET and UPDATE operations for consumers.
class ConsumerProfileRepositoryImpl implements ConsumerProfileRepository {
  @override
  Future<ConsumerProfile> getConsumerProfile() async {
    try {
      final response = await supabase.rpc(
        'manage_profile',
        params: {'p_mode': 'get'},
      );

      return ConsumerProfile.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    } catch (e) {
      throw Exception('Failed to fetch consumer profile: $e');
    }
  }

  @override
  Future<String?> deleteAddress(String addressId) async {
    try {
      final response = await supabase.rpc(
        'manage_profile',
        params: {
          'p_mode': 'delete_address',
          'p_data': {'address_id': addressId},
        },
      );
      final result = Map<String, dynamic>.from(response as Map);
      return result['new_active_address_id'] as String?;
    } catch (e) {
      throw Exception('Failed to delete address: $e');
    }
  }

  @override
  Future<void> updateProfile(ConsumerProfile profile) async {
    try {
      final payload = {
        // Base user fields
        'name': profile.name,
        'email': profile.email,
        'phone': profile.phone,
        'address_line_1': profile.addressLine1,
        'address_line_2': profile.addressLine2,
        'city': profile.city,
        'province': profile.province,
        'region': profile.region,
        'country': profile.country,
        'postal_code': profile.postalCode,
        'landmark': profile.landmark,
        'image_url': profile.imageUrl,
        'dialect': profile.dialect,
        if (profile.latitude != null) 'latitude': profile.latitude,
        if (profile.longitude != null) 'longitude': profile.longitude,
        'address_id': profile.addressId,

        // Consumer-specific fields
        'consumer_id': profile.consumerId,
        'consumer_segment': profile.consumerSegment,
        'cooking_frequency': profile.cookingFrequency,
        'quality_preferences': profile.qualityPreferences,
        'fav_produce': profile.consumerFavProduce.map((p) => p.id).toList(),
      };

      await supabase.rpc(
        'manage_profile',
        params: {'p_mode': 'update', 'p_data': payload},
      );
    } catch (e) {
      throw Exception('Failed to update consumer profile: $e');
    }
  }
}
