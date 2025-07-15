// lib/widgets/permissions_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/permissions_providers.dart';
import '../utils/permissions_utility.dart';

// Widget to check permissions before showing content
class PermissionGate extends ConsumerWidget {
  final Permission permission;
  final Widget child;
  final Widget? fallback;
  final String deniedMessage;

  const PermissionGate({
    Key? key,
    required this.permission,
    required this.child,
    this.fallback,
    this.deniedMessage = 'You do not have permission to access this feature',
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermission = ref.watch(hasPermissionProvider(permission));

    if (!hasPermission) {
      return fallback ?? const SizedBox.shrink();
    }

    return child;
  }
}

// Menu item with permission check
class PermissionMenuItem extends ConsumerWidget {
  final Permission permission;
  final Widget child;
  final VoidCallback? onTap;

  const PermissionMenuItem({
    Key? key,
    required this.permission,
    required this.child,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermission = ref.watch(hasPermissionProvider(permission));

    if (!hasPermission) {
      return const SizedBox.shrink();
    }

    return child;
  }
}

// Comprehensive permissions management screen
class PermissionsManagementScreen extends ConsumerStatefulWidget {
  final UserModel user;

  const PermissionsManagementScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  ConsumerState<PermissionsManagementScreen> createState() =>
      _PermissionsManagementScreenState();
}

class _PermissionsManagementScreenState
    extends ConsumerState<PermissionsManagementScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final canManagePermissions =
        ref.watch(hasPermissionProvider(Permission.managePermissions));

    if (!canManagePermissions) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
        ),
        body: const Center(
          child: Text('You do not have permission to access this page'),
        ),
      );
    }

    final permissionsByCategory = PermissionsUtility.getPermissionsByCategory();
    final categories = ['All', ...permissionsByCategory.keys];

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Permissions - ${widget.user.fullName}'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _resetToDefaults(),
            tooltip: 'Reset to Role Defaults',
          ),
        ],
      ),
      body: Column(
        children: [
          // User info card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.fullName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Role: ${_getRoleDisplayName(widget.user.role)}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Permissions: ${widget.user.roleSpecificData.permissions.length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Search and filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search permissions...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedCategory,
                  items: categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value ?? 'All';
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Permissions list
          Expanded(
            child: _buildPermissionsList(permissionsByCategory),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsList(
      Map<String, List<Permission>> permissionsByCategory) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _selectedCategory == 'All' ? permissionsByCategory.length : 1,
      itemBuilder: (context, index) {
        if (_selectedCategory == 'All') {
          final category = permissionsByCategory.keys.elementAt(index);
          final permissions = permissionsByCategory[category]!;
          return _buildCategorySection(category, permissions);
        } else {
          final permissions = permissionsByCategory[_selectedCategory]!;
          return _buildCategorySection(_selectedCategory, permissions);
        }
      },
    );
  }

  Widget _buildCategorySection(String category, List<Permission> permissions) {
    final filteredPermissions = permissions.where((permission) {
      if (_searchQuery.isEmpty) return true;
      final description =
          PermissionsUtility.getPermissionDescription(permission).toLowerCase();
      return description.contains(_searchQuery) ||
          permission.value.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filteredPermissions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(
          category,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text('${filteredPermissions.length} permissions'),
        children: filteredPermissions.map((permission) {
          final hasPermission =
              widget.user.roleSpecificData.hasPermission(permission.value);
          return ListTile(
            title:
                Text(PermissionsUtility.getPermissionDescription(permission)),
            subtitle: Text(permission.value),
            trailing: Switch(
              value: hasPermission,
              onChanged: (value) => _togglePermission(permission, value),
            ),
            leading: Icon(
              hasPermission ? Icons.check_circle : Icons.radio_button_unchecked,
              color: hasPermission ? Colors.green : Colors.grey,
            ),
          );
        }).toList(),
      ),
    );
  }

  void _togglePermission(Permission permission, bool enabled) async {
    try {
      final permissionsService = ref.read(permissionsServiceProvider);

      if (enabled) {
        await permissionsService.addPermissionToUser(
            widget.user.id, permission);
      } else {
        await permissionsService.removePermissionFromUser(
            widget.user.id, permission);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enabled
                ? 'Permission granted successfully'
                : 'Permission revoked successfully'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update permission: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  void _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Permissions'),
        content: const Text(
            'This will reset all permissions to the default values for this user\'s role. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final permissionsService = ref.read(permissionsServiceProvider);
        await permissionsService.resetToRoleDefaults(
            widget.user.id, widget.user.role);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permissions reset to defaults successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reset permissions: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _getRoleDisplayName(UserRole role) {
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
}

// Permission summary widget for user profiles
class PermissionSummaryWidget extends ConsumerWidget {
  final UserModel user;
  final bool showDetails;

  const PermissionSummaryWidget({
    Key? key,
    required this.user,
    this.showDetails = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = user.roleSpecificData.permissions;
    final permissionsByCategory = PermissionsUtility.getPermissionsByCategory();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Permissions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${permissions.length} total',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (showDetails) ...[
              ...permissionsByCategory.entries.map((entry) {
                final categoryPermissions = entry.value
                    .where((p) => permissions.contains(p.value))
                    .length;
                final totalInCategory = entry.value.length;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(entry.key),
                      ),
                      Text('$categoryPermissions/$totalInCategory'),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: LinearProgressIndicator(
                          value: categoryPermissions / totalInCategory,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            categoryPermissions == totalInCategory
                                ? Colors.green
                                : Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ] else ...[
              // Quick overview
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (PermissionsUtility.canAccessEmergencyManagement(user))
                    Chip(
                      label: const Text('Emergency Mgmt'),
                      backgroundColor: Colors.red.shade100,
                    ),
                  if (PermissionsUtility.canManageHospitalOperations(user))
                    Chip(
                      label: const Text('Hospital Ops'),
                      backgroundColor: Colors.blue.shade100,
                    ),
                  if (PermissionsUtility.canAccessDriverFeatures(user))
                    Chip(
                      label: const Text('Driver Tools'),
                      backgroundColor: Colors.orange.shade100,
                    ),
                  if (PermissionsUtility.canAccessPoliceFeatures(user))
                    Chip(
                      label: const Text('Police Tools'),
                      backgroundColor: Colors.indigo.shade100,
                    ),
                  if (PermissionsUtility.canViewSensitiveData(user))
                    Chip(
                      label: const Text('Admin Access'),
                      backgroundColor: Colors.purple.shade100,
                    ),
                ],
              ),
            ],
            if (!showDetails && permissions.isNotEmpty) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          PermissionsManagementScreen(user: user),
                    ),
                  );
                },
                child: const Text('View Details'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Additional provider needed for hasAllPermissionsProvider
final hasAllPermissionsProvider =
    Provider.family<bool, List<Permission>>((ref, permissions) {
  final currentUser = ref.watch(currentUserProvider);
  return currentUser.when(
    data: (user) => user?.hasAllPermissions(permissions) ?? false,
    loading: () => false,
    error: (_, __) => false,
  );
});
