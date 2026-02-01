import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:duruha/features/auth/domain/auth_models.dart';
import 'package:duruha/shared/user/domain/user_models.dart';
import 'package:duruha/core/services/session_service.dart';

class AuthRepository {
  // Simulate API delay
  final Duration _delay = const Duration(seconds: 2);

  Future<AuthResponse> login(LoginRequest request) async {
    debugPrint("🚀 [AUTH API] Login Request: ${request.toJson()}");
    await Future.delayed(_delay);

    // Mock Response
    // Determine Mock User based on request credentials (simple simulation)
    // If phone starts with '0917' -> Farmer, else Consumer (just for demo)

    final bool isFarmerMock =
        request.email.contains("farmer") || request.email.startsWith("0917");

    final UserProfile mockUser = UserProfile(
      id: "user_${DateTime.now().millisecondsSinceEpoch}",
      joinedAt: DateTime.now().toIso8601String(),
      name: isFarmerMock ? "Juan Farmer" : "Maria Consumer",
      phone: request.email,
      barangay: "San Isidro",
      city: "Davao City",
      province: "Davao del Sur",
      postalCode: "8000",
      landmark: "Near Chapel",
      role: isFarmerMock ? UserRole.farmer : UserRole.consumer,
      dialect: "Cebuano",
      // Farmer
      farmAlias: isFarmerMock ? "Happy Farm" : null,
      landArea: isFarmerMock ? 2.5 : null,
      waterSources: isFarmerMock ? ["River", "Rain"] : null,
      // Consumer
      consumerSegment: !isFarmerMock ? "Household" : null,
      cookingFrequency: !isFarmerMock ? "Daily" : null,
    );

    debugPrint("✅ [AUTH API] Login Success. Token: mock_jwt_token_123");

    // Save Session
    await SessionService.saveUser(mockUser);

    return AuthResponse(token: "mock_jwt_token_123", user: mockUser);
  }

  Future<AuthResponse> signup(SignupRequest request) async {
    debugPrint("🚀 [AUTH API] Signup Request: ${jsonEncode(request.toJson())}");
    await Future.delayed(_delay);

    // Create User Object from Request
    final UserProfile newUser = UserProfile(
      id: "new_user_${DateTime.now().millisecondsSinceEpoch}",
      joinedAt: DateTime.now().toIso8601String(),
      name: request.fullName,
      phone: request.email, // Using email as primary contact
      barangay: "",
      city: "",
      province: "",
      landmark: "",
      postalCode: "",
      role: UserRole.consumer, // Default, likely updated in Onboarding
      dialect: "Cebuano",

      // Farmer
      farmAlias: null,
      landArea: null,
      accessibilityType: null,
      waterSources: null,
      // Consumer
      consumerSegment: null,
      segmentSize: null,
      cookingFrequency: null,
      qualityPreferences: null,
    );

    debugPrint("✅ [AUTH API] Signup Success. User Created: ${newUser.id}");

    // Save Session
    await SessionService.saveUser(newUser);

    return AuthResponse(token: "mock_jwt_token_new_user", user: newUser);
  }

  Future<void> logout() async {
    debugPrint("🚀 [AUTH API] Logging out...");
    await SessionService.clearSession();
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint("✅ [AUTH API] Logout Success");
  }

  // --- Profile & Onboarding ---

  /// Simulates updating the user profile (e.g., after onboarding steps)
  Future<UserProfile> updateProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    await Future.delayed(const Duration(milliseconds: 800)); // Sim network

    // In a real app, we'd merge 'data' into the user record on the backend.
    // Here, we'll fetch the stored user and locally update it to return a fresh object.
    final currentUser = await SessionService.getSavedUser();
    if (currentUser == null) {
      throw Exception("No user session found to update.");
    }

    // Map the untyped data to the UserProfile model
    // This is a simplified merge. In production, use meaningful specific DTOs.
    final updatedUser = UserProfile(
      id: userId,
      name: data['basicInfo']?['name'] ?? currentUser.name,
      phone: data['basicInfo']?['phone'] ?? currentUser.phone,
      role: (data['role'] == 'Farmer') ? UserRole.farmer : UserRole.consumer,
      barangay: data['basicInfo']?['barangay'] ?? currentUser.barangay,
      city: data['basicInfo']?['city'] ?? currentUser.city,
      province: data['basicInfo']?['province'] ?? currentUser.province,
      postalCode: data['basicInfo']?['postalCode'] ?? currentUser.postalCode,
      landmark: data['basicInfo']?['landmark'] ?? currentUser.landmark,
      joinedAt: currentUser.joinedAt, // Keep original
      dialect:
          (data['basicInfo']?['dialects'] as List?)?.first ??
          currentUser.dialect,
    );

    // Persist the updated profile
    await SessionService.saveUser(updatedUser);

    debugPrint("✅ [AUTH API] Profile Updated: ${updatedUser.name}");
    return updatedUser;
  }

  /// Simulates submitting KYC or extra onboarding data
  Future<void> submitKyc(String userId, Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    if (userId.isEmpty) throw Exception("Invalid User ID");
    debugPrint(
      "✅ [AUTH API] KYC/Onboarding Data Received for $userId. Content: ${data.keys.toList()}",
    );
  }
}
