// lib/providers/permissions_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/permissions_service.dart';
import '../utils/permissions_utility.dart';
import 'auth_provider.dart';

// Permissions service provider
final permissionsServiceProvider = Provider<PermissionsService>((ref) {
  return PermissionsService();
});

// Current user permissions provider
final currentUserPermissionsProvider = Provider<List<String>>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  return currentUser.when(
    data: (user) => user?.roleSpecificData.permissions ?? [],
    loading: () => [],
    error: (_, __) => [],
  );
});

// Check if current user has specific permission
final hasPermissionProvider =
    Provider.family<bool, Permission>((ref, permission) {
  final currentUser = ref.watch(currentUserProvider);
  return currentUser.when(
    data: (user) => user?.hasPermission(permission) ?? false,
    loading: () => false,
    error: (_, __) => false,
  );
});

// Check if current user has any of the specified permissions
final hasAnyPermissionProvider =
    Provider.family<bool, List<Permission>>((ref, permissions) {
  final currentUser = ref.watch(currentUserProvider);
  return currentUser.when(
    data: (user) => user?.hasAnyPermission(permissions) ?? false,
    loading: () => false,
    error: (_, __) => false,
  );
});

// Check if current user can access a specific screen
final canAccessScreenProvider =
    Provider.family<bool, String>((ref, screenName) {
  final currentUser = ref.watch(currentUserProvider);
  final permissionsService = ref.watch(permissionsServiceProvider);

  return currentUser.when(
    data: (user) => user != null
        ? permissionsService.canAccessScreen(user, screenName)
        : false,
    loading: () => false,
    error: (_, __) => false,
  );
});

// Available menu items for current user
final availableMenuItemsProvider = Provider<List<MenuItem>>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  final permissionsService = ref.watch(permissionsServiceProvider);

  return currentUser.when(
    data: (user) => user != null ? permissionsService.getMenuItems(user) : [],
    loading: () => [],
    error: (_, __) => [],
  );
});

// Permission validation provider
final validateActionProvider =
    Provider.family<PermissionResult, PermissionActionRequest>((ref, request) {
  final currentUser = ref.watch(currentUserProvider);
  final permissionsService = ref.watch(permissionsServiceProvider);

  return currentUser.when(
    data: (user) => user != null
        ? permissionsService.validatePermission(user, request.action,
            context: request.context)
        : PermissionResult.denied('User not authenticated'),
    loading: () => PermissionResult.denied('Loading user data'),
    error: (_, __) => PermissionResult.denied('Error loading user data'),
  );
});

// Users by permission provider
final usersByPermissionProvider =
    FutureProvider.family<List<UserModel>, Permission>((ref, permission) async {
  final permissionsService = ref.watch(permissionsServiceProvider);
  return await permissionsService.getUsersByPermission(permission);
});

// Users by role provider
final usersByRoleProvider =
    FutureProvider.family<List<UserModel>, UserRole>((ref, role) async {
  final permissionsService = ref.watch(permissionsServiceProvider);
  return await permissionsService.getUsersByRole(role);
});

// Permission statistics provider
final permissionStatisticsProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, hospitalId) async {
  final permissionsService = ref.watch(permissionsServiceProvider);
  return await permissionsService.getPermissionStatistics(hospitalId);
});

// Check if user can manage emergencies
final canManageEmergenciesProvider = Provider<bool>((ref) {
  return ref.watch(hasAnyPermissionProvider(
      PermissionsUtility.emergencyManagementPermissions));
});

// Check if user can manage ambulances
final canManageAmbulancesProvider = Provider<bool>((ref) {
  return ref.watch(hasAnyPermissionProvider(
      PermissionsUtility.ambulanceManagementPermissions));
});

// Check if user can manage staff
final canManageStaffProvider = Provider<bool>((ref) {
  return ref.watch(
      hasAnyPermissionProvider(PermissionsUtility.staffManagementPermissions));
});

// Check if user can view reports
final canViewReportsProvider = Provider<bool>((ref) {
  return ref.watch(hasAnyPermissionProvider(
      PermissionsUtility.reportsAndAnalyticsPermissions));
});

// Check if user has system admin permissions
final isSystemAdminProvider = Provider<bool>((ref) {
  return ref.watch(
      hasAnyPermissionProvider(PermissionsUtility.systemAdminPermissions));
});

// Supporting classes for providers
class PermissionActionRequest {
  final String action;
  final Map<String, dynamic>? context;

  PermissionActionRequest(this.action, {this.context});
}

// Notifier for managing user permissions (for admin users)
class UserPermissionsNotifier extends StateNotifier<AsyncValue<List<String>>> {
  UserPermissionsNotifier(this._permissionsService, this._userId)
      : super(const AsyncValue.loading()) {
    _loadPermissions();
  }

  final PermissionsService _permissionsService;
  final String _userId;

  Future<void> _loadPermissions() async {
    try {
      // This would need to be implemented to get user permissions from Firestore
      // For now, we'll use the permissions service to validate
      state = const AsyncValue.data([]);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> addPermission(Permission permission) async {
    try {
      await _permissionsService.addPermissionToUser(_userId, permission);
      await _loadPermissions();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> removePermission(Permission permission) async {
    try {
      await _permissionsService.removePermissionFromUser(_userId, permission);
      await _loadPermissions();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> updatePermissions(List<String> permissions) async {
    try {
      await _permissionsService.updateUserPermissions(_userId, permissions);
      await _loadPermissions();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> resetToDefaults(UserRole role) async {
    try {
      await _permissionsService.resetToRoleDefaults(_userId, role);
      await _loadPermissions();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

// Provider for managing specific user permissions
final userPermissionsProvider = StateNotifierProvider.family<
    UserPermissionsNotifier, AsyncValue<List<String>>, String>((ref, userId) {
  final permissionsService = ref.watch(permissionsServiceProvider);
  return UserPermissionsNotifier(permissionsService, userId);
});
