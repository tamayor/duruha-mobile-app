import 'package:flutter/foundation.dart';
import 'package:duruha/features/auth/domain/auth_models.dart' as models;
import 'package:duruha/shared/user/domain/user_models.dart';
import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  // Login directly against the 'users' table (Bypassing Supabase Auth)
  // Native Supabase Login
  Future<models.AuthResponse> login(models.LoginRequest request) async {
    debugPrint("🚀 [AUTH API] Supabase Login Request: ${request.email}");

    try {
      // 1. Sign in with Supabase Auth
      final authRes = await supabase.auth.signInWithPassword(
        email: request.email,
        password: request.password,
      );

      final user = authRes.user;
      if (user == null) {
        throw Exception("Auth failed: No user found in response.");
      }

      // 2. Fetch and Sync Profile (Centralized)
      final userProfile = await SessionService.syncProfile(user.id);

      if (userProfile == null) {
        throw Exception("User profile not found in database.");
      }

      debugPrint("✅ [AUTH API] Login Success. User ID: ${userProfile.id}");

      return models.AuthResponse(
        token: authRes.session?.accessToken ?? "",
        user: userProfile,
      );
    } catch (e) {
      debugPrint("❌ [AUTH API] Login Error: $e");
      throw _handleException(e, "Login failed");
    }
  }

  // Signup directly into the 'users' table (Bypassing Supabase Auth)
  // Native Supabase Signup
  Future<void> sendOtp(String email) async {
    debugPrint("🚀 [AUTH API] Send OTP Request: $email");
    try {
      await supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true, // Allow signup via OTP
      );
      debugPrint("✅ [AUTH API] OTP Sent to: $email");
    } catch (e) {
      debugPrint("❌ [AUTH API] Send OTP Error: $e");
      throw _handleException(e, "Failed to send OTP");
    }
  }

  Future<models.AuthResponse> verifyOtp(
    String email,
    String token, {
    OtpType type = OtpType.email,
  }) async {
    debugPrint("🚀 [AUTH API] Verify OTP Request ($type): $email");
    try {
      final authRes = await supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: type,
      );

      final user = authRes.user;
      if (user == null) {
        throw Exception("Verification failed: No user found.");
      }

      // Sync Profile (Centralized)
      final userProfile = await SessionService.syncProfile(user.id);
      if (userProfile == null) {
        throw Exception("Verification failed: Profile not found.");
      }

      debugPrint(
        "✅ [AUTH API] Verification Success. User ID: ${userProfile.id}",
      );

      return models.AuthResponse(
        token: authRes.session?.accessToken ?? "",
        user: userProfile,
      );
    } catch (e) {
      debugPrint("❌ [AUTH API] Verify OTP Error: $e");
      throw _handleException(e, "Verification failed");
    }
  }

  Future<void> resetPassword(String email) async {
    debugPrint("🚀 [AUTH API] Reset Password Request: $email");
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? null : 'io.supabase.flutter://reset-callback/',
      );
      debugPrint("✅ [AUTH API] Password Reset Email Sent to: $email");
    } catch (e) {
      debugPrint("❌ [AUTH API] Reset Password Error: $e");
      throw _handleException(e, "Failed to send reset email");
    }
  }

  Future<void> logout() async {
    debugPrint("🚀 [AUTH API] Logging out...");
    // Clear Supabase session if it exists
    try {
      await supabase.auth.signOut();
    } catch (e) {
      debugPrint("⚠️ [AUTH API] Supabase Auth signOut failed: $e");
    }
    // Clear local session
    await SessionService.clearSession();
    debugPrint("✅ [AUTH API] Logout Success");
  }

  Future<void> updatePassword(String newPassword) async {
    debugPrint("🚀 [AUTH API] Update Password Request");
    try {
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
      debugPrint("✅ [AUTH API] Password Updated Successfully");
    } catch (e) {
      debugPrint("❌ [AUTH API] Update Password Error: $e");
      throw _handleException(e, "Failed to update password");
    }
  }

  // --- Profile & Onboarding ---

  Future<UserProfile> updateProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    debugPrint("🚀 [AUTH API] Update Profile: $userId");

    try {
      final currentUser = await SessionService.getSavedUser();
      if (currentUser == null) {
        throw Exception("No user session found.");
      }

      final updatedFields = {
        'name': data['basicInfo']?['name'] ?? currentUser.name,
        'phone': data['basicInfo']?['phone'] ?? currentUser.phone,
        'city': data['basicInfo']?['city'] ?? currentUser.city,
        'province': data['basicInfo']?['province'] ?? currentUser.province,
        'postal_code':
            data['basicInfo']?['postalCode'] ?? currentUser.postalCode,
        'landmark': data['basicInfo']?['landmark'] ?? currentUser.landmark,
        'dialect':
            (data['basicInfo']?['dialects'] as List?)?.cast<String>() ??
            currentUser.dialect,
        'address_id': data['addressId'] ?? currentUser.addressId,
      };

      // Update in Supabase users table
      final response = await supabase
          .from('users')
          .update(updatedFields)
          .eq('id', userId)
          .select()
          .single();

      final updatedUser = UserProfile.fromJson(response);
      await SessionService.saveUser(updatedUser);

      return updatedUser;
    } catch (e) {
      debugPrint("❌ [AUTH API] Update Profile Error: $e");
      throw _handleException(e, "Failed to update profile");
    }
  }

  Exception _handleException(dynamic e, String fallbackPrefix) {
    if (e is AuthException) {
      return Exception(e.message);
    }
    if (e is PostgrestException) {
      return Exception(e.message);
    }
    return Exception("$fallbackPrefix: ${e.toString()}");
  }

  Future<void> submitKyc(String userId, Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint("✅ [AUTH API] KYC Submitted (Mock/Direct DB placeholder)");
  }
}
