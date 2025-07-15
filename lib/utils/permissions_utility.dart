// lib/utils/permissions_utility.dart
import '../models/user_model.dart';

class PermissionsUtility {
  // Permission Groups for easy management
  static const List<Permission> emergencyManagementPermissions = [
    Permission.createEmergency,
    Permission.viewEmergencies,
    Permission.editEmergency,
    Permission.deleteEmergency,
    Permission.assignEmergencyPriority,
    Permission.closeEmergency,
    Permission.exportEmergencyData,
  ];

  static const List<Permission> ambulanceManagementPermissions = [
    Permission.viewAmbulances,
    Permission.manageAmbulances,
    Permission.assignAmbulances,
    Permission.trackAmbulanceLocation,
    Permission.updateAmbulanceStatus,
    Permission.maintenanceScheduling,
  ];

  static const List<Permission> staffManagementPermissions = [
    Permission.manageStaff,
    Permission.viewStaff,
    Permission.assignStaffRoles,
    Permission.manageStaffPermissions,
    Permission.viewStaffPerformance,
  ];

  static const List<Permission> reportsAndAnalyticsPermissions = [
    Permission.viewReports,
    Permission.generateReports,
    Permission.viewAnalytics,
    Permission.exportData,
    Permission.viewPerformanceMetrics,
    Permission.createCustomReports,
  ];

  static const List<Permission> systemAdminPermissions = [
    Permission.manageSystemSettings,
    Permission.manageUserAccounts,
    Permission.viewSystemLogs,
    Permission.managePermissions,
    Permission.systemBackup,
  ];

  // Quick permission checks for common scenarios
  static bool canAccessEmergencyManagement(UserModel user) {
    return user.hasAnyPermission(emergencyManagementPermissions);
  }

  static bool canManageHospitalOperations(UserModel user) {
    return user.hasAnyPermission([
      ...emergencyManagementPermissions,
      ...ambulanceManagementPermissions,
      ...staffManagementPermissions,
    ]);
  }

  static bool canAccessDriverFeatures(UserModel user) {
    return user.hasAnyPermission([
      Permission.acceptEmergencyRequests,
      Permission.updateTripStatus,
      Permission.toggleDriverAvailability,
      Permission.updateDriverLocation,
      Permission.accessNavigationTools,
    ]);
  }

  static bool canAccessPoliceFeatures(UserModel user) {
    return user.hasAnyPermission([
      Permission.clearTrafficRoutes,
      Permission.manageTrafficSignals,
      Permission.accessPoliceDatabase,
      Permission.manageTrafficIncidents,
    ]);
  }

  static bool canViewSensitiveData(UserModel user) {
    return user.hasAnyPermission([
      Permission.viewSystemLogs,
      Permission.viewAuditLogs,
      Permission.manageUserAccounts,
      Permission.accessSecuritySettings,
    ]);
  }

  // Get human-readable permission descriptions
  static String getPermissionDescription(Permission permission) {
    switch (permission) {
      case Permission.createEmergency:
        return 'Create new emergency incidents';
      case Permission.viewEmergencies:
        return 'View emergency incidents';
      case Permission.editEmergency:
        return 'Edit emergency details';
      case Permission.deleteEmergency:
        return 'Delete emergency records';
      case Permission.assignEmergencyPriority:
        return 'Set emergency priority levels';
      case Permission.closeEmergency:
        return 'Close completed emergencies';
      case Permission.exportEmergencyData:
        return 'Export emergency data';

      case Permission.viewAmbulances:
        return 'View ambulance fleet';
      case Permission.manageAmbulances:
        return 'Manage ambulance fleet';
      case Permission.assignAmbulances:
        return 'Assign ambulances to emergencies';
      case Permission.trackAmbulanceLocation:
        return 'Track ambulance locations';
      case Permission.updateAmbulanceStatus:
        return 'Update ambulance status';
      case Permission.maintenanceScheduling:
        return 'Schedule ambulance maintenance';

      case Permission.manageDrivers:
        return 'Manage ambulance drivers';
      case Permission.viewDrivers:
        return 'View driver information';
      case Permission.assignDriverToAmbulance:
        return 'Assign drivers to vehicles';
      case Permission.viewDriverPerformance:
        return 'View driver performance metrics';
      case Permission.manageDriverSchedule:
        return 'Manage driver schedules';
      case Permission.toggleDriverAvailability:
        return 'Toggle availability status';
      case Permission.updateDriverLocation:
        return 'Update current location';

      case Permission.manageStaff:
        return 'Manage hospital staff';
      case Permission.viewStaff:
        return 'View staff information';
      case Permission.assignStaffRoles:
        return 'Assign staff roles';
      case Permission.manageStaffPermissions:
        return 'Manage staff permissions';
      case Permission.viewStaffPerformance:
        return 'View staff performance';

      case Permission.viewRoutes:
        return 'View emergency routes';
      case Permission.createRoutes:
        return 'Create new routes';
      case Permission.optimizeRoutes:
        return 'Optimize route planning';
      case Permission.clearTrafficRoutes:
        return 'Clear traffic on routes';
      case Permission.manageTrafficSignals:
        return 'Manage traffic signals';
      case Permission.coordinateWithPolice:
        return 'Coordinate with police';

      case Permission.accessLiveMap:
        return 'Access live map view';
      case Permission.trackRealTimeLocation:
        return 'Track real-time locations';
      case Permission.viewLocationHistory:
        return 'View location history';
      case Permission.manageGeofences:
        return 'Manage geographic boundaries';

      case Permission.viewReports:
        return 'View system reports';
      case Permission.generateReports:
        return 'Generate custom reports';
      case Permission.viewAnalytics:
        return 'View analytics dashboard';
      case Permission.exportData:
        return 'Export system data';
      case Permission.viewPerformanceMetrics:
        return 'View performance metrics';
      case Permission.createCustomReports:
        return 'Create custom reports';

      case Permission.sendNotifications:
        return 'Send notifications';
      case Permission.receivePushNotifications:
        return 'Receive push notifications';
      case Permission.accessMessaging:
        return 'Access messaging system';
      case Permission.emergencyBroadcast:
        return 'Send emergency broadcasts';

      case Permission.manageSystemSettings:
        return 'Manage system settings';
      case Permission.manageUserAccounts:
        return 'Manage user accounts';
      case Permission.viewSystemLogs:
        return 'View system logs';
      case Permission.managePermissions:
        return 'Manage user permissions';
      case Permission.systemBackup:
        return 'Perform system backups';

      case Permission.manageHospitalSettings:
        return 'Manage hospital settings';
      case Permission.viewHospitalResources:
        return 'View hospital resources';
      case Permission.manageInventory:
        return 'Manage medical inventory';
      case Permission.coordinateWithOtherHospitals:
        return 'Coordinate with other hospitals';

      case Permission.accessPoliceDatabase:
        return 'Access police database';
      case Permission.manageTrafficIncidents:
        return 'Manage traffic incidents';
      case Permission.coordinateEmergencyResponse:
        return 'Coordinate emergency response';
      case Permission.accessEmergencyProtocols:
        return 'Access emergency protocols';

      case Permission.acceptEmergencyRequests:
        return 'Accept emergency requests';
      case Permission.updateTripStatus:
        return 'Update trip status';
      case Permission.accessNavigationTools:
        return 'Access navigation tools';
      case Permission.reportIncidents:
        return 'Report incidents';
      case Permission.accessDriverResources:
        return 'Access driver resources';

      case Permission.viewAuditLogs:
        return 'View audit logs';
      case Permission.manageCompliance:
        return 'Manage compliance';
      case Permission.accessSecuritySettings:
        return 'Access security settings';
    }
  }

  // Get permissions by category
  static Map<String, List<Permission>> getPermissionsByCategory() {
    return {
      'Emergency Management': emergencyManagementPermissions,
      'Ambulance Management': ambulanceManagementPermissions,
      'Staff Management': staffManagementPermissions,
      'Driver Management': [
        Permission.manageDrivers,
        Permission.viewDrivers,
        Permission.assignDriverToAmbulance,
        Permission.viewDriverPerformance,
        Permission.manageDriverSchedule,
        Permission.toggleDriverAvailability,
        Permission.updateDriverLocation,
      ],
      'Route Management': [
        Permission.viewRoutes,
        Permission.createRoutes,
        Permission.optimizeRoutes,
        Permission.clearTrafficRoutes,
        Permission.manageTrafficSignals,
        Permission.coordinateWithPolice,
      ],
      'Location & Mapping': [
        Permission.accessLiveMap,
        Permission.trackRealTimeLocation,
        Permission.viewLocationHistory,
        Permission.manageGeofences,
      ],
      'Reports & Analytics': reportsAndAnalyticsPermissions,
      'Communication': [
        Permission.sendNotifications,
        Permission.receivePushNotifications,
        Permission.accessMessaging,
        Permission.emergencyBroadcast,
      ],
      'System Administration': systemAdminPermissions,
      'Hospital Specific': [
        Permission.manageHospitalSettings,
        Permission.viewHospitalResources,
        Permission.manageInventory,
        Permission.coordinateWithOtherHospitals,
      ],
      'Police Specific': [
        Permission.accessPoliceDatabase,
        Permission.manageTrafficIncidents,
        Permission.coordinateEmergencyResponse,
        Permission.accessEmergencyProtocols,
      ],
      'Driver Specific': [
        Permission.acceptEmergencyRequests,
        Permission.updateTripStatus,
        Permission.accessNavigationTools,
        Permission.reportIncidents,
        Permission.accessDriverResources,
      ],
      'Audit & Compliance': [
        Permission.viewAuditLogs,
        Permission.manageCompliance,
        Permission.accessSecuritySettings,
      ],
    };
  }

  // Check if user can access a specific screen/feature
  static bool canAccessScreen(UserModel user, String screenName) {
    switch (screenName.toLowerCase()) {
      case 'emergency_creation':
        return user.hasPermission(Permission.createEmergency);
      case 'emergency_list':
        return user.hasPermission(Permission.viewEmergencies);
      case 'ambulance_management':
        return user.hasAnyPermission(ambulanceManagementPermissions);
      case 'driver_dashboard':
        return canAccessDriverFeatures(user);
      case 'police_dashboard':
        return canAccessPoliceFeatures(user);
      case 'hospital_dashboard':
        return canManageHospitalOperations(user);
      case 'live_map':
        return user.hasPermission(Permission.accessLiveMap);
      case 'reports':
        return user.hasAnyPermission(reportsAndAnalyticsPermissions);
      case 'system_settings':
        return user.hasAnyPermission(systemAdminPermissions);
      case 'staff_management':
        return user.hasAnyPermission(staffManagementPermissions);
      default:
        return false;
    }
  }

  // Get available menu items based on user permissions
  static List<MenuItem> getAvailableMenuItems(UserModel user) {
    List<MenuItem> items = [];

    if (user.hasPermission(Permission.viewEmergencies)) {
      items.add(MenuItem(
        title: 'Emergencies',
        icon: 'emergency',
        route: '/emergencies',
        permission: Permission.viewEmergencies,
      ));
    }

    if (user.hasAnyPermission(ambulanceManagementPermissions)) {
      items.add(MenuItem(
        title: 'Ambulances',
        icon: 'ambulance',
        route: '/ambulances',
        permission: Permission.viewAmbulances,
      ));
    }

    if (user.hasPermission(Permission.accessLiveMap)) {
      items.add(MenuItem(
        title: 'Live Map',
        icon: 'map',
        route: '/live-map',
        permission: Permission.accessLiveMap,
      ));
    }

    if (user.hasAnyPermission(reportsAndAnalyticsPermissions)) {
      items.add(MenuItem(
        title: 'Reports',
        icon: 'reports',
        route: '/reports',
        permission: Permission.viewReports,
      ));
    }

    if (user.hasAnyPermission(staffManagementPermissions)) {
      items.add(MenuItem(
        title: 'Staff Management',
        icon: 'people',
        route: '/staff',
        permission: Permission.manageStaff,
      ));
    }

    if (canAccessDriverFeatures(user)) {
      items.add(MenuItem(
        title: 'Driver Tools',
        icon: 'drive',
        route: '/driver',
        permission: Permission.acceptEmergencyRequests,
      ));
    }

    if (canAccessPoliceFeatures(user)) {
      items.add(MenuItem(
        title: 'Traffic Control',
        icon: 'traffic',
        route: '/police',
        permission: Permission.clearTrafficRoutes,
      ));
    }

    if (user.hasAnyPermission(systemAdminPermissions)) {
      items.add(MenuItem(
        title: 'System Settings',
        icon: 'settings',
        route: '/settings',
        permission: Permission.manageSystemSettings,
      ));
    }

    return items;
  }

  // Validate if user can perform an action
  static PermissionResult validateAction(UserModel user, String action,
      {Map<String, dynamic>? context}) {
    switch (action.toLowerCase()) {
      case 'create_emergency':
        if (!user.hasPermission(Permission.createEmergency)) {
          return PermissionResult.denied(
              'You do not have permission to create emergencies');
        }
        return PermissionResult.allowed();

      case 'edit_emergency':
        if (!user.hasPermission(Permission.editEmergency)) {
          return PermissionResult.denied(
              'You do not have permission to edit emergencies');
        }
        return PermissionResult.allowed();

      case 'delete_emergency':
        if (!user.hasPermission(Permission.deleteEmergency)) {
          return PermissionResult.denied(
              'You do not have permission to delete emergencies');
        }
        return PermissionResult.allowed();

      case 'assign_ambulance':
        if (!user.hasPermission(Permission.assignAmbulances)) {
          return PermissionResult.denied(
              'You do not have permission to assign ambulances');
        }
        return PermissionResult.allowed();

      case 'update_ambulance_status':
        if (!user.hasPermission(Permission.updateAmbulanceStatus)) {
          return PermissionResult.denied(
              'You do not have permission to update ambulance status');
        }
        return PermissionResult.allowed();

      case 'manage_staff':
        if (!user.hasPermission(Permission.manageStaff)) {
          return PermissionResult.denied(
              'You do not have permission to manage staff');
        }
        return PermissionResult.allowed();

      case 'view_reports':
        if (!user.hasPermission(Permission.viewReports)) {
          return PermissionResult.denied(
              'You do not have permission to view reports');
        }
        return PermissionResult.allowed();

      case 'clear_traffic':
        if (!user.hasPermission(Permission.clearTrafficRoutes)) {
          return PermissionResult.denied(
              'You do not have permission to clear traffic');
        }
        return PermissionResult.allowed();

      case 'toggle_availability':
        if (!user.hasPermission(Permission.toggleDriverAvailability)) {
          return PermissionResult.denied(
              'You do not have permission to toggle availability');
        }
        if (!user.isDriver) {
          return PermissionResult.denied(
              'Only drivers can toggle their availability');
        }
        return PermissionResult.allowed();

      default:
        return PermissionResult.denied('Unknown action: $action');
    }
  }

  // Get default permissions for a role (useful for role changes or permission resets)
  static List<String> getDefaultPermissionsForRole(UserRole role) {
    switch (role) {
      case UserRole.hospitalAdmin:
        return RoleSpecificData.forHospitalAdmin(hospitalId: '').permissions;
      case UserRole.hospitalStaff:
        return RoleSpecificData.forHospitalStaff(hospitalId: '').permissions;
      case UserRole.ambulanceDriver:
        return RoleSpecificData.forDriver(licenseNumber: '').permissions;
      case UserRole.police:
        return RoleSpecificData.forPolice(badgeNumber: '', department: '')
            .permissions;
    }
  }

  // Check if permission upgrade is needed (when new permissions are added)
  static List<String> getMissingPermissions(UserModel user) {
    final defaultPermissions = getDefaultPermissionsForRole(user.role);
    final currentPermissions = user.roleSpecificData.permissions;

    return defaultPermissions
        .where((permission) => !currentPermissions.contains(permission))
        .toList();
  }

  // Merge new permissions with existing ones
  static List<String> mergePermissions(
      List<String> existing, List<String> newPermissions) {
    final merged = Set<String>.from(existing);
    merged.addAll(newPermissions);
    return merged.toList();
  }
}

// Supporting classes
class MenuItem {
  final String title;
  final String icon;
  final String route;
  final Permission permission;

  MenuItem({
    required this.title,
    required this.icon,
    required this.route,
    required this.permission,
  });
}

class PermissionResult {
  final bool isAllowed;
  final String? message;

  PermissionResult._(this.isAllowed, this.message);

  factory PermissionResult.allowed([String? message]) {
    return PermissionResult._(true, message);
  }

  factory PermissionResult.denied(String message) {
    return PermissionResult._(false, message);
  }
}
