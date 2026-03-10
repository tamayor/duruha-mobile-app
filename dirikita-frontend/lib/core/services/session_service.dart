import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:duruha/shared/user/domain/user_models.dart';
import 'package:duruha/supabase_config.dart';

class SessionService {
  static const String _userKey = 'current_user_profile';
  static const String _lastActiveKey = 'last_active_timestamp';

  // Save user profile to local storage
  static Future<void> saveUser(UserProfile user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    await updateLastActive();
  }

  // Update last active timestamp to current time
  static Future<void> updateLastActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastActiveKey, DateTime.now().toIso8601String());
  }

  // Check if session has expired (7 days inactivity)
  // Returns true if session was cleared
  static Future<bool> clearIfExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastActiveStr = prefs.getString(_lastActiveKey);

      if (lastActiveStr != null) {
        final lastActive = DateTime.parse(lastActiveStr);
        final difference = DateTime.now().difference(lastActive);

        if (difference.inDays >= 7) {
          await clearSession();
          return true;
        } else {
          // Heartbeat: Update last active if not expired
          await updateLastActive();
        }
      } else if (await isLoggedIn()) {
        // If logged in but no timestamp, set it now to start tracking
        await updateLastActive();
      }
    } catch (e) {
      debugPrint("❌ [SESSION] Error checking expiry: $e");
      // If timestamp is corrupted, better to keep the session and reset the timestamp
      await updateLastActive();
    }
    return false;
  }

  // Retrieve user data from local storage as a UserProfile
  static Future<UserProfile?> getSavedUser() async {
    final data = await getUserData();
    if (data == null) {
      // If local data is missing but session exists, try to re-sync
      final session = supabase.auth.currentSession;
      if (session != null) {
        debugPrint(
          "🔄 [SESSION] Local profile missing but session exists. Syncing...",
        );
        return await syncProfile(session.user.id);
      }
      return null;
    }
    return UserProfile.fromJson(data);
  }

  static Future<UserProfile?> syncProfile(String userId) async {
    try {
      final authUser = supabase.auth.currentUser;
      if (authUser == null) return null;

      // 1. Try fetching by ID first (preferred)
      var response = await supabase
          .from('users')
          .select('*, user_farmers(farmer_id), user_consumers(consumer_id)')
          .eq('id', userId)
          .maybeSingle();

      // 2. Fallback: Try fetching by email and LINK if found
      if (response == null && authUser.email != null) {
        debugPrint(
          "🔄 [SESSION] Profile not found by ID. Trying email: ${authUser.email}",
        );
        response = await supabase
            .from('users')
            .select('*, user_farmers(farmer_id), user_consumers(consumer_id)')
            .eq('email', authUser.email!)
            .maybeSingle();

        if (response != null) {
          debugPrint(
            "🔗 [SESSION] Found profile by email. Linking ID ${authUser.id} to ${authUser.email}",
          );
          await supabase
              .from('users')
              .update({'id': authUser.id})
              .eq('email', authUser.email!);

          // Refresh response with updated ID
          response['id'] = authUser.id;
        }
      }

      if (response == null) {
        debugPrint("⚠️ [SESSION] No profile found in DB for ID or email.");
        return null;
      }

      final userData = Map<String, dynamic>.from(response);

      // Flatten joined IDs - handle lists safely
      if (response['user_farmers'] != null) {
        final farmers = response['user_farmers'] as List;
        if (farmers.length > 1) {
          debugPrint(
            "⚠️ [SESSION] Multiple farmer profiles found for user $userId: $farmers",
          );
        }
        if (farmers.isNotEmpty) {
          userData['farmer_id'] = farmers[0]['farmer_id'];
        }
      }
      if (response['user_consumers'] != null) {
        final consumers = response['user_consumers'] as List;
        if (consumers.length > 1) {
          debugPrint(
            "⚠️ [SESSION] Multiple consumer profiles found for user $userId: $consumers",
          );
        }
        if (consumers.isNotEmpty) {
          userData['consumer_id'] = consumers[0]['consumer_id'];
        }
      }

      final profile = UserProfile.fromJson(userData);
      await saveUser(profile);
      return profile;
    } catch (e) {
      debugPrint("❌ [SESSION] Error syncing profile: $e");
      return null;
    }
  }

  static Future<String?> getUserId() async {
    final data = await getUserData();
    return data?['id'];
  }

  /// Updates only address_id in the cached profile without a full re-sync.
  static Future<void> saveAddressId(String? addressId) async {
    final data = await getUserData();
    if (data == null) return;
    final updated = Map<String, dynamic>.from(data);
    updated['address_id'] = addressId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(updated));
  }

  static Future<String?> getRoleId() async {
    final data = await getUserData();
    if (data == null) return null;
    final role = data['role']?.toString().toUpperCase();
    final roleId = role == 'FARMER' ? data['farmer_id'] : data['consumer_id'];

    if (roleId != null) return roleId as String;

    // If missing, try to sync from DB
    return await syncRoleId();
  }

  /// Fetches the farmer_id or consumer_id from Supabase based on user_id
  /// and updates the local session.
  static Future<String?> syncRoleId() async {
    try {
      final data = await getUserData();
      if (data == null) return null;

      final userId = data['id'];
      final role = data['role']?.toString().toUpperCase();
      if (userId == null || role == null) return null;

      String? roleId;
      if (role == 'FARMER') {
        final res = await supabase
            .from('user_farmers')
            .select('farmer_id')
            .eq('user_id', userId);
        final list = res as List;
        if (list.length > 1) {
          debugPrint(
            "⚠️ [SESSION] Multiple farmer profiles found for user $userId: $list",
          );
        }
        if (list.isNotEmpty) {
          roleId = list[0]['farmer_id'];
        }
      } else if (role == 'CONSUMER') {
        final res = await supabase
            .from('user_consumers')
            .select('consumer_id')
            .eq('user_id', userId);
        final list = res as List;
        if (list.length > 1) {
          debugPrint(
            "⚠️ [SESSION] Multiple consumer profiles found for user $userId: $list",
          );
        }
        if (list.isNotEmpty) {
          roleId = list[0]['consumer_id'];
        }
      }

      if (roleId != null) {
        debugPrint("🔄 [SESSION] Synced roleId: $roleId for user: $userId");
        final updatedData = Map<String, dynamic>.from(data);
        if (role == 'FARMER') {
          updatedData['farmer_id'] = roleId;
        } else {
          updatedData['consumer_id'] = roleId;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(updatedData));
      } else {
        debugPrint(
          "⚠️ [SESSION] No roleId found for user: $userId and role: $role",
        );
      }

      return roleId;
    } catch (e) {
      debugPrint("❌ [SESSION] Error syncing roleId: $e");
      return null;
    }
  }

  static Future<String?> getUserName() async {
    final data = await getUserData();
    return data?['name'];
  }

  static Future<List<String>> getUserDialects() async {
    final data = await getUserData();
    final dialects = data?['dialect'];
    if (dialects is List) {
      return dialects.map((e) => e.toString()).toList();
    }
    return [];
  }

  // Retrieve user data from local storage
  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return jsonDecode(userJson) as Map<String, dynamic>;
    }
    return null;
  }

  // Clear session (local profile)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  // Check if user is logged in via Supabase Auth
  static Future<bool> isLoggedIn() async {
    return supabase.auth.currentSession != null;
  }

  static const String _isFavoriteKey = 'is_favorites_only';

  // Save favorite preference
  static Future<void> saveFavoritePreference(bool isFavorite) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isFavoriteKey, isFavorite);
  }

  // Get favorite preference
  static Future<bool> getFavoritePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFavoriteKey) ?? false;
  }

  static const String _salesModeKey = 'is_pledge_mode';

  // Save sales mode preference (Pledge vs Offer)
  static Future<void> saveModePreference(bool isPledge) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_salesModeKey, isPledge);
  }

  // Get sales mode preference
  static Future<bool> getModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_salesModeKey) ?? true; // Default to true (Pledge)
  }

  static const String _themeKey = 'app_theme_mode';

  // Save theme preference
  static Future<void> saveThemePreference(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.toString());
  }

  // Get theme preference
  static Future<ThemeMode> getThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(_themeKey);
    if (themeStr == 'ThemeMode.dark') return ThemeMode.dark;
    if (themeStr == 'ThemeMode.light') return ThemeMode.light;
    return ThemeMode.system;
  }
}
