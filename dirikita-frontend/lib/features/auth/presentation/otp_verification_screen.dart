import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duruha/features/auth/data/auth_repository.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/auth/presentation/new_password_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final bool isRecovery;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.isRecovery = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();
  bool _isLoading = false;
  int _resendTimer = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendTimer = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer == 0) {
        timer.cancel();
      } else {
        setState(() => _resendTimer--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 8) {
      DuruhaSnackBar.showError(context, "Please enter the full 8-digit code");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authRepo = AuthRepository();
      final response = await authRepo.verifyOtp(
        widget.email,
        otp,
        type: widget.isRecovery ? OtpType.recovery : OtpType.email,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (widget.isRecovery) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const NewPasswordScreen()),
        );
        return;
      }

      DuruhaSnackBar.showSuccess(
        context,
        "Welcome back, ${response.user.name}!",
      );

      // Navigate to onboarding or home based on profile completion
      Navigator.pushReplacementNamed(
        context,
        '/onboarding',
        arguments: response.user,
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

  Future<void> _resendOtp() async {
    if (_resendTimer > 0) return;

    setState(() => _isLoading = true);
    try {
      final authRepo = AuthRepository();
      await authRepo.sendOtp(widget.email);
      if (!mounted) return;
      setState(() => _isLoading = false);
      DuruhaSnackBar.showSuccess(
        context,
        "Verification code resent to ${widget.email}",
      );
      _startTimer();
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Verify your email",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We've sent an 8-digit code to ${widget.email}. Please enter it below to verify your account.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),
              DuruhaInput(
                label: "Verification Code",
                icon: Icons.lock_outline_rounded,
                controller: _otpController,
                keyboardType: TextInputType.number,
                hintText: "Enter 8-digit code",
                onChanged: (value) {
                  if (value.length == 8) {
                    _verifyOtp();
                  }
                },
              ),
              const SizedBox(height: 48),
              DuruhaButton(
                text: "Verify Code",
                isLoading: _isLoading,
                onPressed: _verifyOtp,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  GestureDetector(
                    onTap: _resendOtp,
                    child: Text(
                      _resendTimer > 0
                          ? "Resend in ${_resendTimer}s"
                          : "Resend Code",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _resendTimer > 0
                            ? theme.colorScheme.outline
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
