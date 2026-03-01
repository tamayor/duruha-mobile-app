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

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class SignupRequest {
  final String email;
  final String password;
  final String confirmPassword;

  SignupRequest({
    required this.email,
    required this.password,
    required this.confirmPassword,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'confirm_password': confirmPassword,
  };
}

class OtpRequest {
  final String email;
  OtpRequest({required this.email});
  Map<String, dynamic> toJson() => {'email': email};
}

class VerifyOtpRequest {
  final String email;
  final String token;
  VerifyOtpRequest({required this.email, required this.token});
  Map<String, dynamic> toJson() => {'email': email, 'token': token};
}
