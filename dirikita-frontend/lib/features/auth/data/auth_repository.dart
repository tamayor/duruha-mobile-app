import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:duruha/features/auth/domain/auth_models.dart';
import 'package:duruha/shared/user/domain/user_models.dart';

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
      landmark: "",
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
    return AuthResponse(token: "mock_jwt_token_new_user", user: newUser);
  }

  Future<void> logout() async {
    debugPrint("🚀 [AUTH API] Logging out...");
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint("✅ [AUTH API] Logout Success");
  }
}
