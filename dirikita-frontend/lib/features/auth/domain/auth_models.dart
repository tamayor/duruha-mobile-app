import 'package:duruha/shared/user/domain/user_models.dart';

class AuthResponse {
  final String token;
  final UserProfile user;

  AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'],
      // Assuming user json structure matches UserProfile
      // We might need a fromJson in UserProfile, but for now passing mock object manually in Repository
      user: json['user'],
    );
  }
}

class LoginRequest {
  final String email; // Using phone/email as identifier
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'identifier': email, 'password': password};
}

class SignupRequest {
  final String fullName;
  final String email;
  final String password;
  final String confirmPassword;

  SignupRequest({
    required this.fullName,
    required this.email,
    required this.password,
    required this.confirmPassword,
  });

  Map<String, dynamic> toJson() => {
    'full_name': fullName,
    'email': email,
    'password': password,
    'confirm_password': confirmPassword,
  };
}
