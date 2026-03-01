import 'package:flutter/material.dart';
import 'package:duruha/features/auth/data/auth_repository.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/auth/presentation/otp_verification_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendOtp() async {
    if (_emailController.text.isEmpty) {
      DuruhaSnackBar.showError(context, "Please enter your email");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authRepo = AuthRepository();
      await authRepo.sendOtp(_emailController.text.trim());

      if (!mounted) return;
      setState(() => _isLoading = false);

      DuruhaSnackBar.showSuccess(context, "Verification code sent!");

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              OtpVerificationScreen(email: _emailController.text.trim()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      DuruhaSnackBar.showError(
        context,
        e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
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

                DuruhaInput(
                  label: "Email Address",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  controller: _emailController,
                ),

                const SizedBox(height: 32),
                DuruhaButton(
                  text: "Send Verification Code",
                  isLoading: _isLoading,
                  onPressed: _sendOtp,
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
