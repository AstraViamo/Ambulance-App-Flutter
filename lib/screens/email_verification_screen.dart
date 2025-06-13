// lib/screens/email_verification_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  final UserRole role;

  const EmailVerificationScreen({
    Key? key,
    required this.email,
    required this.role,
  }) : super(key: key);

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  Timer? _timer;
  bool _isResendingEmail = false;
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    _startEmailVerificationCheck();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startEmailVerificationCheck() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _checkEmailVerification();
    });
  }

  Future<void> _checkEmailVerification() async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.reloadUser();

      final user = authService.currentUser;
      if (user != null && user.emailVerified) {
        _timer?.cancel();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => LoginScreen(
                initialEmail: widget.email,
                showSuccessMessage: true,
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Handle error silently during periodic checks
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_resendCooldown > 0) return;

    setState(() {
      _isResendingEmail = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendEmailVerification();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Verification email sent successfully'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }

      // Start cooldown
      setState(() {
        _resendCooldown = 60;
      });

      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_resendCooldown > 0) {
          setState(() {
            _resendCooldown--;
          });
        } else {
          timer.cancel();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending email: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      setState(() {
        _isResendingEmail = false;
      });
    }
  }

  Color _getRoleColor() {
    switch (widget.role) {
      case UserRole.hospitalAdmin:
        return Colors.blue.shade700;
      case UserRole.hospitalStaff:
        return Colors.green.shade700;
      case UserRole.ambulanceDriver:
        return Colors.orange.shade700;
      case UserRole.police:
        return Colors.indigo.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Verify Your Email',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: _getRoleColor(),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Email icon with animation
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: _getRoleColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: Icon(
                        Icons.email_outlined,
                        size: 60,
                        color: _getRoleColor(),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Title
                    Text(
                      'Check Your Email',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _getRoleColor(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Description
                    Text(
                      'We\'ve sent a verification link to:',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    // Email address
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        widget.email,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _getRoleColor(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade700,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Click the verification link in your email to activate your account. You can then sign in to access your dashboard.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade700,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Checking status
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.green.shade700),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Checking verification status...',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom actions
              Column(
                children: [
                  // Resend email button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: (_isResendingEmail || _resendCooldown > 0)
                          ? null
                          : _resendVerificationEmail,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _getRoleColor()),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isResendingEmail
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    _getRoleColor()),
                              ),
                            )
                          : Text(
                              _resendCooldown > 0
                                  ? 'Resend Email (${_resendCooldown}s)'
                                  : 'Resend Verification Email',
                              style: TextStyle(
                                color: _getRoleColor(),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sign in button (for if they already verified)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LoginScreen(
                              initialEmail: widget.email,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getRoleColor(),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Already Verified? Sign In',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Help text
                  Text(
                    'Check your spam folder if you don\'t see the email',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
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
