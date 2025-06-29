// lib/screens/improved_auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/location_providers.dart';
import 'login_screen.dart';
import 'role_dashboards.dart';

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          // User not logged in - ensure tracking is stopped and show login screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ensureTrackingStopped();
          });
          return const LoginScreen();
        } else if (!user.emailVerified) {
          // User logged in but email not verified - sign them out and show login
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await _signOutAndCleanup();
          });
          return const LoginScreen();
        } else {
          // User logged in and email verified - show appropriate dashboard
          return FutureBuilder<UserModel?>(
            future: ref.read(authServiceProvider).getUserData(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingScreen();
              }

              if (snapshot.hasError || !snapshot.hasData) {
                // Error loading user data - sign out and show login
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  await _signOutAndCleanup();
                });
                return const LoginScreen();
              }

              final userData = snapshot.data!;
              return _buildDashboard(userData.role);
            },
          );
        }
      },
      loading: () => _buildLoadingScreen(),
      error: (error, stack) {
        // Auth error - ensure cleanup and show login
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensureTrackingStopped();
        });
        return const LoginScreen();
      },
    );
  }

  Future<void> _signOutAndCleanup() async {
    try {
      // Stop location tracking first
      await _ensureTrackingStopped();

      // Then sign out
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
    } catch (e) {
      debugPrint('Error during signout cleanup: $e');
    }
  }

  Future<void> _ensureTrackingStopped() async {
    try {
      // Stop any active location tracking
      final trackingNotifier = ref.read(trackingStateProvider.notifier);
      final trackingState = ref.read(trackingStateProvider);

      if (trackingState.isTracking) {
        await trackingNotifier.stopTracking();
        debugPrint('Location tracking stopped during auth state change');
      }
    } catch (e) {
      debugPrint('Error stopping location tracking: $e');
    }
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.red.shade700,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red.shade700,
              Colors.red.shade900,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.local_hospital,
                size: 40,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(UserRole role) {
    switch (role) {
      case UserRole.hospitalAdmin:
        return const HospitalAdminDashboard();
      case UserRole.hospitalStaff:
        return const HospitalStaffDashboard();
      case UserRole.ambulanceDriver:
        return const AmbulanceDriverDashboard();
      case UserRole.police:
        return const PoliceDashboard();
    }
  }
}
