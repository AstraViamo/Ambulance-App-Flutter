// lib/screens/registration_screen.dart
import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import 'email_verification_screen.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  final UserRole selectedRole;

  const RegistrationScreen({
    Key? key,
    required this.selectedRole,
  }) : super(key: key);

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Role-specific controllers
  final _hospitalIdController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _badgeNumberController = TextEditingController();
  final _departmentController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _hospitalIdController.dispose();
    _licenseNumberController.dispose();
    _badgeNumberController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);
    final authError = ref.watch(authErrorProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Register as ${_getRoleTitle(widget.selectedRole)}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: _getRoleColor(widget.selectedRole),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getRoleColor(widget.selectedRole).withOpacity(0.1),
                        _getRoleColor(widget.selectedRole).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _getRoleIcon(widget.selectedRole),
                        size: 60,
                        color: _getRoleColor(widget.selectedRole),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Create Your Account',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _getRoleColor(widget.selectedRole),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Join as ${_getRoleTitle(widget.selectedRole)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Error message
                if (authError != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      authError,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),

                // Personal Information
                _buildSectionTitle('Personal Information'),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _firstNameController,
                        label: 'First Name',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'First name is required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _lastNameController,
                        label: 'Last Name',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Last name is required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                _buildTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!EmailValidator.validate(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Role-specific fields
                _buildRoleSpecificFields(),

                const SizedBox(height: 24),

                // Account Security
                _buildSectionTitle('Account Security'),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                _buildTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () => setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Register button
                ElevatedButton(
                  onPressed: isLoading ? null : _handleRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getRoleColor(widget.selectedRole),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),

                const SizedBox(height: 20),

                // Login link
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style: TextStyle(color: Colors.grey.shade600),
                      children: [
                        TextSpan(
                          text: 'Sign In',
                          style: TextStyle(
                            color: _getRoleColor(widget.selectedRole),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildRoleSpecificFields() {
    switch (widget.selectedRole) {
      case UserRole.hospitalAdmin:
      case UserRole.hospitalStaff:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Hospital Information'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _hospitalIdController,
              label: 'Hospital ID',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Hospital ID is required';
                }
                return null;
              },
            ),
          ],
        );

      case UserRole.ambulanceDriver:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Driver Information'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _licenseNumberController,
              label: 'Driver License Number',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'License number is required';
                }
                return null;
              },
            ),
          ],
        );

      case UserRole.police:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Police Information'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _badgeNumberController,
              label: 'Badge Number',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Badge number is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _departmentController,
              label: 'Department',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Department is required';
                }
                return null;
              },
            ),
          ],
        );
    }
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(authLoadingProvider.notifier).state = true;
    ref.read(authErrorProvider.notifier).state = null;

    try {
      final authService = ref.read(authServiceProvider);

      // Check if email is already registered
      final isEmailTaken =
          await authService.isEmailRegistered(_emailController.text.trim());
      if (isEmailTaken) {
        ref.read(authErrorProvider.notifier).state =
            'An account with this email already exists';
        return;
      }

      // Create role-specific data
      RoleSpecificData roleData = _createRoleSpecificData();

      // Create user model
      final userModel = UserModel(
        id: '', // Will be set by auth service
        email: _emailController.text.trim(),
        role: widget.selectedRole,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        roleSpecificData: roleData,
      );

      // Register user
      final userCredential = await authService.registerWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        userModel: userModel,
      );

      if (userCredential != null) {
        // Navigate to email verification screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => EmailVerificationScreen(
                email: _emailController.text.trim(),
                role: widget.selectedRole,
              ),
            ),
          );
        }
      }
    } catch (e) {
      ref.read(authErrorProvider.notifier).state = e.toString();
    } finally {
      ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  RoleSpecificData _createRoleSpecificData() {
    switch (widget.selectedRole) {
      case UserRole.hospitalAdmin:
        return RoleSpecificData.forHospitalAdmin(
          hospitalId: _hospitalIdController.text.trim(),
        );
      case UserRole.hospitalStaff:
        return RoleSpecificData.forHospitalStaff(
          hospitalId: _hospitalIdController.text.trim(),
        );
      case UserRole.ambulanceDriver:
        return RoleSpecificData.forDriver(
          licenseNumber: _licenseNumberController.text.trim(),
        );
      case UserRole.police:
        return RoleSpecificData.forPolice(
          badgeNumber: _badgeNumberController.text.trim(),
          department: _departmentController.text.trim(),
        );
    }
  }

  String _getRoleTitle(UserRole role) {
    switch (role) {
      case UserRole.hospitalAdmin:
        return 'Hospital Admin';
      case UserRole.hospitalStaff:
        return 'Hospital Staff';
      case UserRole.ambulanceDriver:
        return 'Ambulance Driver';
      case UserRole.police:
        return 'Police Officer';
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.hospitalAdmin:
        return Icons.admin_panel_settings;
      case UserRole.hospitalStaff:
        return Icons.medical_services;
      case UserRole.ambulanceDriver:
        return Icons.local_shipping;
      case UserRole.police:
        return Icons.local_police;
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
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
}
