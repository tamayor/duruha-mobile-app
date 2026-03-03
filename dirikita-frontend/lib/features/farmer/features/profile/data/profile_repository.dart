import 'dart:io';
import 'package:duruha/supabase_config.dart';
import 'package:duruha/features/farmer/features/profile/domain/profile_model.dart';

/// Calls the unified `manage_profile` RPC on Supabase.
/// Handles both GET and UPDATE operations for farmers.
class FarmerProfileRepositoryImpl implements FarmerProfileRepository {
  @override
  Future<FarmerProfile> getFarmerProfile(String userId) async {
    try {
      final response = await supabase.rpc(
        'manage_profile',
        params: {'p_user_id': userId, 'p_mode': 'get'},
      );

      return FarmerProfile.fromJson(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      throw Exception('Failed to fetch farmer profile: $e');
    }
  }

  @override
  Future<String> uploadProfileImage(File file) async {
    // Mock implementation – replace with Supabase Storage upload
    await Future.delayed(const Duration(seconds: 2));
    return 'https://i.pravatar.cc/300?img=${DateTime.now().millisecond % 70}';
  }

  @override
  Future<void> updateProfile(FarmerProfile profile) async {
    try {
      final payload = {
        // Base user fields
        'name': profile.name,
        'email': profile.email,
        'phone': profile.phone,
        'barangay': profile.barangay,
        'city': profile.city,
        'province': profile.province,
        'postal_code': profile.postalCode,
        'landmark': profile.landmark,
        'image_url': profile.imageUrl,
        'dialect': profile.dialect,
        'operating_days': profile.operatingDays,
        'delivery_window': profile.deliveryWindow,
        if (profile.latitude != null) 'latitude': profile.latitude,
        if (profile.longitude != null) 'longitude': profile.longitude,

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
          'p_user_id': profile.id,
          'p_mode': 'update',
          'p_data': payload,
        },
      );
    } catch (e) {
      throw Exception('Failed to update farmer profile: $e');
    }
  }
}
