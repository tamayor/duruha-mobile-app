import 'package:flutter/material.dart';
import 'package:duruha/features/auth/data/auth_repository.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';

class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.isEmpty || confirm.isEmpty) {
      DuruhaSnackBar.showError(context, "Please fill in all fields");
      return;
    }

    if (password != confirm) {
      DuruhaSnackBar.showError(context, "Passwords do not match");
      return;
    }

    if (password.length < 6) {
      DuruhaSnackBar.showError(
        context,
        "Password must be at least 6 characters",
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authRepo = AuthRepository();
      await authRepo.updatePassword(password);

      if (!mounted) return;
      setState(() => _isLoading = false);

      DuruhaSnackBar.showSuccess(
        context,
        "Password updated successfully! Please log in with your new password.",
      );

      // Go back to login screen. We pop until we reach a screen that is not auth related
      // or just pop back to the root if Login is the root.
      // Since we pushed Signup -> OTP -> NewPassword, we should probably go back to the beginning.
      Navigator.of(context).popUntil((route) => route.isFirst);
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
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: theme.colorScheme.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Create New Password",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Please enter and confirm your new password below.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),
              DuruhaInput(
                label: "New Password",
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                controller: _passwordController,
              ),
              DuruhaInput(
                label: "Confirm Password",
                icon: Icons.lock_reset_rounded,
                isPassword: true,
                controller: _confirmController,
              ),
              const SizedBox(height: 32),
              DuruhaButton(
                text: "Update Password",
                isLoading: _isLoading,
                onPressed: _updatePassword,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
