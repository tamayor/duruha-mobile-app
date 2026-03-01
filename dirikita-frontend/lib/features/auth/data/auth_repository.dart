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

      // 2. Query public.users table for the full profile
      final response = await supabase
          .from('users')
          .select('*, user_farmers(farmer_id), user_consumers(consumer_id)')
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) {
        throw Exception("User profile not found in database.");
      }

      final userData = Map<String, dynamic>.from(response);

      // Flatten joined IDs
      if (response['user_farmers'] != null &&
          (response['user_farmers'] as List).isNotEmpty) {
        userData['farmer_id'] = response['user_farmers'][0]['farmer_id'];
      }
      if (response['user_consumers'] != null &&
          (response['user_consumers'] as List).isNotEmpty) {
        userData['consumer_id'] = response['user_consumers'][0]['consumer_id'];
      }

      final userProfile = UserProfile.fromJson(userData);

      // Save Session Locally
      await SessionService.saveUser(userProfile);

      debugPrint("✅ [AUTH API] Login Success. User ID: ${userProfile.id}");

      return models.AuthResponse(
        token: authRes.session?.accessToken ?? "",
        user: userProfile,
      );
    } catch (e) {
      debugPrint("❌ [AUTH API] Login Error: $e");
      throw Exception("Login failed: ${e.toString()}");
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
      throw Exception("Failed to send OTP: ${e.toString()}");
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

      // Query public.users table for the profile
      final response = await supabase
          .from('users')
          .select('*, user_farmers(farmer_id), user_consumers(consumer_id)')
          .eq('id', user.id)
          .maybeSingle();

      Map<String, dynamic> userData;
      if (response == null) {
        // Create initial profile if it doesn't exist
        userData = {'id': user.id, 'email': email, 'name': email.split('@')[0]};
        await supabase.from('users').upsert(userData);
      } else {
        userData = Map<String, dynamic>.from(response);
      }

      // Flatten joined IDs if they exist
      if (response != null) {
        if (response['user_farmers'] != null &&
            (response['user_farmers'] as List).isNotEmpty) {
          userData['farmer_id'] = response['user_farmers'][0]['farmer_id'];
        }
        if (response['user_consumers'] != null &&
            (response['user_consumers'] as List).isNotEmpty) {
          userData['consumer_id'] =
              response['user_consumers'][0]['consumer_id'];
        }
      }

      final userProfile = UserProfile.fromJson(userData);
      await SessionService.saveUser(userProfile);

      debugPrint(
        "✅ [AUTH API] Verification Success. User ID: ${userProfile.id}",
      );

      return models.AuthResponse(
        token: authRes.session?.accessToken ?? "",
        user: userProfile,
      );
    } catch (e) {
      debugPrint("❌ [AUTH API] Verify OTP Error: $e");
      throw Exception("Verification failed: ${e.toString()}");
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
      throw Exception("Failed to send reset email: ${e.toString()}");
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
      throw Exception("Failed to update password: ${e.toString()}");
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
        'barangay': data['basicInfo']?['barangay'] ?? currentUser.barangay,
        'city': data['basicInfo']?['city'] ?? currentUser.city,
        'province': data['basicInfo']?['province'] ?? currentUser.province,
        'postal_code':
            data['basicInfo']?['postalCode'] ?? currentUser.postalCode,
        'landmark': data['basicInfo']?['landmark'] ?? currentUser.landmark,
        'dialect':
            (data['basicInfo']?['dialects'] as List?)?.cast<String>() ??
            currentUser.dialect,
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
      throw Exception("Failed to update profile: ${e.toString()}");
    }
  }

  Future<void> submitKyc(String userId, Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint("✅ [AUTH API] KYC Submitted (Mock/Direct DB placeholder)");
  }
}
