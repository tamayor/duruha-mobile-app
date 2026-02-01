import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duruha/shared/user/domain/user_models.dart';

class SessionService {
  static const String _userKey = 'current_user_profile';
  static const String _lastActiveKey = 'last_active_timestamp';

  // Save user profile to local storage
  static Future<void> saveUser(UserProfile user) async {
    final prefs = await SharedPreferences.getInstance();
    // Assuming we want to store the basic info.
    // Usually, we'd have a toJson() method in UserProfile.
    final userData = {
      'id': user.id,
      'name': user.name,
      'phone': user.phone,
      'role': user.role.name,
      'barangay': user.barangay,
      'city': user.city,
      'landmark': user.landmark,
      'joinedAt': user.joinedAt,
      'dialect': user.dialect,
    };
    await prefs.setString(_userKey, jsonEncode(userData));
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
    final prefs = await SharedPreferences.getInstance();
    final lastActiveStr = prefs.getString(_lastActiveKey);

    if (lastActiveStr != null) {
      final lastActive = DateTime.parse(lastActiveStr);
      final difference = DateTime.now().difference(lastActive);

      if (difference.inDays >= 7) {
        await clearSession();
        return true;
      }
    } else if (await isLoggedIn()) {
      // If logged in but no timestamp, set it now to start tracking
      await updateLastActive();
    }
    return false;
  }

  // Retrieve user data from local storage as a UserProfile (partial)
  static Future<UserProfile?> getSavedUser() async {
    final data = await getUserData();
    if (data == null) return null;

    return UserProfile(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] == 'farmer' ? UserRole.farmer : UserRole.consumer,
      barangay: data['barangay'] ?? '',
      city: data['city'] ?? '',
      province: data['province'] ?? '',
      postalCode: data['postalCode'] ?? '',
      landmark: data['landmark'] ?? '',
      joinedAt: data['joinedAt'] ?? '',
      dialect: data['dialect'] ?? 'Cebuano',
    );
  }

  static Future<String?> getUserId() async {
    final data = await getUserData();
    return data?['id'];
  }

  static Future<String?> getUserName() async {
    final data = await getUserData();
    return data?['name'];
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

  // Clear session (logout)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_userKey);
  }
}
