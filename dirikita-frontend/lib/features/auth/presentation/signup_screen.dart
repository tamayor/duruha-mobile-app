import 'package:flutter/material.dart';
import 'package:duruha/features/auth/data/auth_repository.dart';
import 'package:duruha/features/auth/domain/auth_models.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signup() async {
    // Basic Validation
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      DuruhaSnackBar.showError(context, "Please fill in all fields");
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      DuruhaSnackBar.showError(context, "Passwords do not match");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // API Payload Preparation
    final request = SignupRequest(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    debugPrint('🚀 [API PREP] Signup Payload: ${request.toJson()}');

    try {
      // Call Repository
      final authRepo = AuthRepository();
      final response = await authRepo.signup(request);

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Navigate to Onboarding
      Navigator.pushReplacementNamed(
        context,
        '/onboarding',
        arguments: response.user,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      DuruhaSnackBar.showError(context, "Signup failed. Please try again.");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access theme for colors if needed manually
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          // FORCE the color to be visible (Your Green Brand Color)
          color: theme.colorScheme.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Center(
                  child: Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.all(
                      16.0,
                    ), // Optional: padding inside the logo box if it's an icon
                    child: ClipRRect(
                      // If the image is the full background, remove padding and use match parent.
                      // Assuming logo.png might be transparent, padding looks nice.
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Join the Revolution",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 48),

                // 3. USE CUSTOM INPUTS
                DuruhaInput(
                  label: "Full Name",
                  icon: Icons.person_outline,
                  controller: _nameController,
                ),

                DuruhaInput(
                  label: "Email Address",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  controller: _emailController,
                ),

                DuruhaInput(
                  label: "Password",
                  icon: Icons.lock_outline,
                  isPassword: true,
                  controller: _passwordController,
                ),

                DuruhaInput(
                  label: "Confirm Password",
                  icon: Icons.lock_outline,
                  isPassword: true,
                  controller: _confirmPasswordController,
                ),

                const SizedBox(height: 32),
                DuruhaButton(
                  text: "Create Account",
                  isLoading: _isLoading,
                  onPressed: _signup,
                ),

                const SizedBox(height: 24),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        "Log In",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
