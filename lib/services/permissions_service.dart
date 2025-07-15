// lib/services/permissions_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../utils/permissions_utility.dart';

class PermissionsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Update user permissions
  Future<void> updateUserPermissions(
      String userId, List<String> permissions) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'roleSpecificData.permissions': permissions,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw 'Failed to update user permissions: $e';
    }
  }

  // Add specific permission to user
  Future<void> addPermissionToUser(String userId, Permission permission) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'roleSpecificData.permissions':
            FieldValue.arrayUnion([permission.value]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw 'Failed to add permission: $e';
    }
  }

  // Remove specific permission from user
  Future<void> removePermissionFromUser(
      String userId, Permission permission) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'roleSpecificData.permissions':
            FieldValue.arrayRemove([permission.value]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw 'Failed to remove permission: $e';
    }
  }

  // Grant permission group to user
  Future<void> grantPermissionGroup(
      String userId, List<Permission> permissions) async {
    try {
      final permissionValues = permissions.map((p) => p.value).toList();
      await _firestore.collection('users').doc(userId).update({
        'roleSpecificData.permissions': FieldValue.arrayUnion(permissionValues),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw 'Failed to grant permission group: $e';
    }
  }

  // Revoke permission group from user
  Future<void> revokePermissionGroup(
      String userId, List<Permission> permissions) async {
    try {
      final permissionValues = permissions.map((p) => p.value).toList();
      await _firestore.collection('users').doc(userId).update({
        'roleSpecificData.permissions':
            FieldValue.arrayRemove(permissionValues),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw 'Failed to revoke permission group: $e';
    }
  }

  // Reset user permissions to role defaults
  Future<void> resetToRoleDefaults(String userId, UserRole role) async {
    try {
      final defaultPermissions =
          PermissionsUtility.getDefaultPermissionsForRole(role);
      await updateUserPermissions(userId, defaultPermissions);
    } catch (e) {
      throw 'Failed to reset permissions: $e';
    }
  }

  // Upgrade user permissions (add missing default permissions)
  Future<void> upgradeUserPermissions(UserModel user) async {
    try {
      final missingPermissions = PermissionsUtility.getMissingPermissions(user);
      if (missingPermissions.isNotEmpty) {
        final updatedPermissions = PermissionsUtility.mergePermissions(
          user.roleSpecificData.permissions,
          missingPermissions,
        );
        await updateUserPermissions(user.id, updatedPermissions);
      }
    } catch (e) {
      throw 'Failed to upgrade permissions: $e';
    }
  }

  // Get users by permission
  Future<List<UserModel>> getUsersByPermission(Permission permission) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('roleSpecificData.permissions',
              arrayContains: permission.value)
          .where('isActive', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw 'Failed to get users by permission: $e';
    }
  }

  // Get users by role
  Future<List<UserModel>> getUsersByRole(UserRole role) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role.value)
          .where('isActive', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw 'Failed to get users by role: $e';
    }
  }

  // Validate permission action
  PermissionResult validatePermission(UserModel user, String action,
      {Map<String, dynamic>? context}) {
    return PermissionsUtility.validateAction(user, action, context: context);
  }

  // Get available menu items for user
  List<MenuItem> getMenuItems(UserModel user) {
    return PermissionsUtility.getAvailableMenuItems(user);
  }

  // Check if user can access screen
  bool canAccessScreen(UserModel user, String screenName) {
    return PermissionsUtility.canAccessScreen(user, screenName);
  }

  // Audit permission usage
  Future<void> logPermissionUsage(
      String userId, Permission permission, String action) async {
    try {
      await _firestore.collection('permission_audit').add({
        'userId': userId,
        'permission': permission.value,
        'action': action,
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'success': true,
      });
    } catch (e) {
      // Log audit failure but don't throw - this shouldn't block user actions
      print('Failed to log permission usage: $e');
    }
  }

  // Audit permission denial
  Future<void> logPermissionDenial(String userId, Permission permission,
      String action, String reason) async {
    try {
      await _firestore.collection('permission_audit').add({
        'userId': userId,
        'permission': permission.value,
        'action': action,
        'reason': reason,
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'success': false,
      });
    } catch (e) {
      print('Failed to log permission denial: $e');
    }
  }

  // Get permission usage statistics
  Future<Map<String, dynamic>> getPermissionStatistics(
      String hospitalId) async {
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      final querySnapshot = await _firestore
          .collection('permission_audit')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(weekAgo))
          .get();

      final usageMap = <String, int>{};
      int totalActions = 0;
      int deniedActions = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final permission = data['permission'] as String;
        final success = data['success'] as bool;

        usageMap[permission] = (usageMap[permission] ?? 0) + 1;
        totalActions++;
        if (!success) deniedActions++;
      }

      return {
        'totalActions': totalActions,
        'deniedActions': deniedActions,
        'successRate': totalActions > 0
            ? (totalActions - deniedActions) / totalActions
            : 0.0,
        'permissionUsage': usageMap,
        'period': 'Last 7 days',
      };
    } catch (e) {
      throw 'Failed to get permission statistics: $e';
    }
  }
}
