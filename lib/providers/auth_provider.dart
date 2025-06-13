// lib/providers/auth_providers.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Auth state provider
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Current user data provider
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) async {
      if (user != null) {
        final authService = ref.read(authServiceProvider);
        return await authService.getUserData(user.uid);
      }
      return null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// Loading state provider for auth operations
final authLoadingProvider = StateProvider<bool>((ref) => false);

// Error state provider for auth operations
final authErrorProvider = StateProvider<String?>((ref) => null);

// Email verification provider
final emailVerificationProvider = StateProvider<bool>((ref) => false);

// Selected role provider (for registration flow)
final selectedRoleProvider = StateProvider<UserRole?>((ref) => null);
