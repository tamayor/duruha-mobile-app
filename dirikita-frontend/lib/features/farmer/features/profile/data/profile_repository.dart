import 'package:duruha/supabase_config.dart';
import 'package:duruha/features/farmer/features/profile/domain/profile_model.dart';

/// Calls the unified `manage_profile` RPC on Supabase.
/// Handles both GET and UPDATE operations for farmers.
class FarmerProfileRepositoryImpl implements FarmerProfileRepository {
  @override
  Future<FarmerProfile> getFarmerProfile() async {
    try {
      final response = await supabase.rpc(
        'manage_profile',
        params: {'p_mode': 'get'},
      );

      return FarmerProfile.fromJson(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      throw Exception('Failed to fetch farmer profile: $e');
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
  Future<void> updateProfile(FarmerProfile profile) async {
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
        'postal_code': profile.postalCode,
        'country': profile.country,
        'landmark': profile.landmark,
        'image_url': profile.imageUrl,
        'dialect': profile.dialect,
        'operating_days': profile.operatingDays,
        'delivery_window': profile.deliveryWindow,
        if (profile.latitude != null) 'latitude': profile.latitude,
        if (profile.longitude != null) 'longitude': profile.longitude,
        if (profile.addressId != null) 'address_id': profile.addressId,

        // Farmer-specific fields
        'farmer_id': profile.farmerId,
        'farmer_alias': profile.farmerAlias,
        'land_area': profile.landArea,
        'accessibility_type': profile.accessibilityType,
        'water_sources': profile.waterSources,
        'fav_produce': profile.farmerFavProduce.map((p) => p.id).toList(),
      };

      await supabase.rpc(
        'manage_profile',
        params: {
          'p_mode': 'update',
          'p_data': payload,
        },
      );
    } catch (e) {
      throw Exception('Failed to update farmer profile: $e');
    }
  }
}
