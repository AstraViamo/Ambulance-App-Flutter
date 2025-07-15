// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  hospitalAdmin('hospital_admin'),
  hospitalStaff('hospital_staff'),
  ambulanceDriver('ambulance_driver'),
  police('police');

  const UserRole(this.value);
  final String value;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere((role) => role.value == value);
  }
}

// Comprehensive permissions enum for the entire system
enum Permission {
  // Emergency Management
  createEmergency('create_emergency'),
  viewEmergencies('view_emergencies'),
  editEmergency('edit_emergency'),
  deleteEmergency('delete_emergency'),
  assignEmergencyPriority('assign_emergency_priority'),
  closeEmergency('close_emergency'),
  exportEmergencyData('export_emergency_data'),

  // Ambulance Management
  viewAmbulances('view_ambulances'),
  manageAmbulances('manage_ambulances'),
  assignAmbulances('assign_ambulances'),
  trackAmbulanceLocation('track_ambulance_location'),
  updateAmbulanceStatus('update_ambulance_status'),
  maintenanceScheduling('maintenance_scheduling'),

  // Driver Management
  manageDrivers('manage_drivers'),
  viewDrivers('view_drivers'),
  assignDriverToAmbulance('assign_driver_to_ambulance'),
  viewDriverPerformance('view_driver_performance'),
  manageDriverSchedule('manage_driver_schedule'),
  toggleDriverAvailability('toggle_driver_availability'),
  updateDriverLocation('update_driver_location'),

  // Staff Management
  manageStaff('manage_staff'),
  viewStaff('view_staff'),
  assignStaffRoles('assign_staff_roles'),
  manageStaffPermissions('manage_staff_permissions'),
  viewStaffPerformance('view_staff_performance'),

  // Route Management
  viewRoutes('view_routes'),
  createRoutes('create_routes'),
  optimizeRoutes('optimize_routes'),
  clearTrafficRoutes('clear_traffic_routes'),
  manageTrafficSignals('manage_traffic_signals'),
  coordinateWithPolice('coordinate_with_police'),

  // Location & Mapping
  accessLiveMap('access_live_map'),
  trackRealTimeLocation('track_real_time_location'),
  viewLocationHistory('view_location_history'),
  manageGeofences('manage_geofences'),

  // Reports & Analytics
  viewReports('view_reports'),
  generateReports('generate_reports'),
  viewAnalytics('view_analytics'),
  exportData('export_data'),
  viewPerformanceMetrics('view_performance_metrics'),
  createCustomReports('create_custom_reports'),

  // Communication
  sendNotifications('send_notifications'),
  receivePushNotifications('receive_push_notifications'),
  accessMessaging('access_messaging'),
  emergencyBroadcast('emergency_broadcast'),

  // System Administration
  manageSystemSettings('manage_system_settings'),
  manageUserAccounts('manage_user_accounts'),
  viewSystemLogs('view_system_logs'),
  managePermissions('manage_permissions'),
  systemBackup('system_backup'),

  // Hospital Specific
  manageHospitalSettings('manage_hospital_settings'),
  viewHospitalResources('view_hospital_resources'),
  manageInventory('manage_inventory'),
  coordinateWithOtherHospitals('coordinate_with_other_hospitals'),

  // Police Specific
  accessPoliceDatabase('access_police_database'),
  manageTrafficIncidents('manage_traffic_incidents'),
  coordinateEmergencyResponse('coordinate_emergency_response'),
  accessEmergencyProtocols('access_emergency_protocols'),

  // Driver Specific
  acceptEmergencyRequests('accept_emergency_requests'),
  updateTripStatus('update_trip_status'),
  accessNavigationTools('access_navigation_tools'),
  reportIncidents('report_incidents'),
  accessDriverResources('access_driver_resources'),

  // Audit & Compliance
  viewAuditLogs('view_audit_logs'),
  manageCompliance('manage_compliance'),
  accessSecuritySettings('access_security_settings');

  const Permission(this.value);
  final String value;

  static Permission fromString(String value) {
    return Permission.values
        .firstWhere((permission) => permission.value == value);
  }
}

class UserModel {
  final String id;
  final String email;
  final UserRole role;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? profileImageUrl;
  final RoleSpecificData roleSpecificData;

  UserModel({
    required this.id,
    required this.email,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.profileImageUrl,
    required this.roleSpecificData,
  });

  // Convert from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      role: UserRole.fromString(data['role'] ?? ''),
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      profileImageUrl: data['profileImageUrl'],
      roleSpecificData: RoleSpecificData.fromMap(
        data['roleSpecificData'] ?? {},
        UserRole.fromString(data['role']),
      ),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'role': role.value,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'profileImageUrl': profileImageUrl,
      'roleSpecificData': roleSpecificData.toMap(),
    };
  }

  // Helper getters
  String get fullName => '$firstName $lastName';
  bool get isHospitalUser =>
      role == UserRole.hospitalAdmin || role == UserRole.hospitalStaff;
  bool get isDriver => role == UserRole.ambulanceDriver;
  bool get isPolice => role == UserRole.police;

  // Permission checking methods
  bool hasPermission(Permission permission) {
    return roleSpecificData.permissions.contains(permission.value);
  }

  bool hasAnyPermission(List<Permission> permissions) {
    return permissions.any((permission) => hasPermission(permission));
  }

  bool hasAllPermissions(List<Permission> permissions) {
    return permissions.every((permission) => hasPermission(permission));
  }

  // Role-based permission groups
  bool get canManageEmergencies => hasAnyPermission([
        Permission.createEmergency,
        Permission.editEmergency,
        Permission.assignEmergencyPriority,
      ]);

  bool get canManageAmbulances => hasAnyPermission([
        Permission.manageAmbulances,
        Permission.assignAmbulances,
        Permission.updateAmbulanceStatus,
      ]);

  bool get canViewReports => hasAnyPermission([
        Permission.viewReports,
        Permission.viewAnalytics,
        Permission.viewPerformanceMetrics,
      ]);

  bool get isSystemAdmin => hasPermission(Permission.manageSystemSettings);

  // Driver-specific helpers
  bool get isAvailable => roleSpecificData.isAvailable ?? false;
  bool get hasAssignedAmbulances =>
      roleSpecificData.assignedAmbulances?.isNotEmpty ?? false;
  int get assignedAmbulanceCount =>
      roleSpecificData.assignedAmbulances?.length ?? 0;

  // Copy with method for updates
  UserModel copyWith({
    String? email,
    UserRole? role,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    bool? isActive,
    DateTime? updatedAt,
    String? profileImageUrl,
    RoleSpecificData? roleSpecificData,
    required String id,
  }) {
    return UserModel(
      id: id,
      email: email ?? this.email,
      role: role ?? this.role,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      roleSpecificData: roleSpecificData ?? this.roleSpecificData,
    );
  }
}

class RoleSpecificData {
  final String? hospitalId;
  final String? licenseNumber;
  final String? badgeNumber;
  final String? department;
  final List<String>? assignedAmbulances;
  final List<String> permissions; // Made non-nullable and required
  final bool? isAvailable; // For drivers - their shift availability
  final DateTime? lastAvailabilityUpdate; // When driver toggled availability
  final Map<String, dynamic>? customData; // For future extensibility

  RoleSpecificData({
    this.hospitalId,
    this.licenseNumber,
    this.badgeNumber,
    this.department,
    this.assignedAmbulances,
    required this.permissions, // Now required
    this.isAvailable,
    this.lastAvailabilityUpdate,
    this.customData,
  });

  factory RoleSpecificData.fromMap(Map<String, dynamic> map, UserRole role) {
    return RoleSpecificData(
      hospitalId: map['hospitalId'],
      licenseNumber: map['licenseNumber'],
      badgeNumber: map['badgeNumber'],
      department: map['department'],
      assignedAmbulances: List<String>.from(map['assignedAmbulances'] ?? []),
      permissions: List<String>.from(map['permissions'] ?? []),
      isAvailable: map['isAvailable'],
      lastAvailabilityUpdate: map['lastAvailabilityUpdate'] != null
          ? (map['lastAvailabilityUpdate'] as Timestamp).toDate()
          : null,
      customData: map['customData'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (hospitalId != null) 'hospitalId': hospitalId,
      if (licenseNumber != null) 'licenseNumber': licenseNumber,
      if (badgeNumber != null) 'badgeNumber': badgeNumber,
      if (department != null) 'department': department,
      if (assignedAmbulances != null) 'assignedAmbulances': assignedAmbulances,
      'permissions': permissions, // Always include permissions
      if (isAvailable != null) 'isAvailable': isAvailable,
      if (lastAvailabilityUpdate != null)
        'lastAvailabilityUpdate': Timestamp.fromDate(lastAvailabilityUpdate!),
      if (customData != null) 'customData': customData,
    };
  }

  // Factory methods for different roles with comprehensive permissions
  factory RoleSpecificData.forHospitalAdmin({
    required String hospitalId,
    List<String>? customPermissions,
  }) {
    final defaultPermissions = [
      // Emergency Management - Full Access
      Permission.createEmergency.value,
      Permission.viewEmergencies.value,
      Permission.editEmergency.value,
      Permission.deleteEmergency.value,
      Permission.assignEmergencyPriority.value,
      Permission.closeEmergency.value,
      Permission.exportEmergencyData.value,

      // Ambulance Management - Full Access
      Permission.viewAmbulances.value,
      Permission.manageAmbulances.value,
      Permission.assignAmbulances.value,
      Permission.trackAmbulanceLocation.value,
      Permission.updateAmbulanceStatus.value,
      Permission.maintenanceScheduling.value,

      // Staff Management - Full Access
      Permission.manageStaff.value,
      Permission.viewStaff.value,
      Permission.assignStaffRoles.value,
      Permission.manageStaffPermissions.value,
      Permission.viewStaffPerformance.value,

      // Driver Management - Full Access
      Permission.manageDrivers.value,
      Permission.viewDrivers.value,
      Permission.assignDriverToAmbulance.value,
      Permission.viewDriverPerformance.value,
      Permission.manageDriverSchedule.value,

      // Reports & Analytics - Full Access
      Permission.viewReports.value,
      Permission.generateReports.value,
      Permission.viewAnalytics.value,
      Permission.exportData.value,
      Permission.viewPerformanceMetrics.value,
      Permission.createCustomReports.value,

      // Communication
      Permission.sendNotifications.value,
      Permission.receivePushNotifications.value,
      Permission.accessMessaging.value,
      Permission.emergencyBroadcast.value,

      // Hospital Specific - Full Access
      Permission.manageHospitalSettings.value,
      Permission.viewHospitalResources.value,
      Permission.manageInventory.value,
      Permission.coordinateWithOtherHospitals.value,

      // Location & Mapping
      Permission.accessLiveMap.value,
      Permission.trackRealTimeLocation.value,
      Permission.viewLocationHistory.value,
      Permission.manageGeofences.value,

      // Route Management
      Permission.viewRoutes.value,
      Permission.createRoutes.value,
      Permission.optimizeRoutes.value,
      Permission.coordinateWithPolice.value,

      // System Administration - Limited
      Permission.viewSystemLogs.value,
      Permission.managePermissions.value,

      // Audit & Compliance
      Permission.viewAuditLogs.value,
      Permission.manageCompliance.value,
    ];

    return RoleSpecificData(
      hospitalId: hospitalId,
      permissions: customPermissions ?? defaultPermissions,
    );
  }

  factory RoleSpecificData.forHospitalStaff({
    required String hospitalId,
    List<String>? customPermissions,
  }) {
    final defaultPermissions = [
      // Emergency Management - Limited
      Permission.createEmergency.value,
      Permission.viewEmergencies.value,
      Permission.editEmergency.value,
      Permission.assignEmergencyPriority.value,
      Permission.closeEmergency.value,

      // Ambulance Management - Limited
      Permission.viewAmbulances.value,
      Permission.assignAmbulances.value,
      Permission.trackAmbulanceLocation.value,
      Permission.updateAmbulanceStatus.value,

      // Driver Management - View Only
      Permission.viewDrivers.value,
      Permission.assignDriverToAmbulance.value,

      // Communication
      Permission.sendNotifications.value,
      Permission.receivePushNotifications.value,
      Permission.accessMessaging.value,

      // Hospital Specific - Limited
      Permission.viewHospitalResources.value,
      Permission.coordinateWithOtherHospitals.value,

      // Location & Mapping
      Permission.accessLiveMap.value,
      Permission.trackRealTimeLocation.value,
      Permission.viewLocationHistory.value,

      // Route Management - View Only
      Permission.viewRoutes.value,
      Permission.coordinateWithPolice.value,

      // Reports - Limited
      Permission.viewReports.value,
      Permission.viewPerformanceMetrics.value,
    ];

    return RoleSpecificData(
      hospitalId: hospitalId,
      permissions: customPermissions ?? defaultPermissions,
    );
  }

  factory RoleSpecificData.forDriver({
    required String licenseNumber,
    List<String>? assignedAmbulances,
    bool isAvailable = false,
    List<String>? customPermissions,
  }) {
    final defaultPermissions = [
      // Emergency Management - Driver Specific
      Permission.viewEmergencies.value,
      Permission.acceptEmergencyRequests.value,
      Permission.updateTripStatus.value,

      // Ambulance Management - Own Vehicle
      Permission.updateAmbulanceStatus.value,
      Permission.trackAmbulanceLocation.value,

      // Driver Specific - Full Access
      Permission.toggleDriverAvailability.value,
      Permission.updateDriverLocation.value,
      Permission.accessNavigationTools.value,
      Permission.reportIncidents.value,
      Permission.accessDriverResources.value,

      // Communication
      Permission.receivePushNotifications.value,
      Permission.accessMessaging.value,

      // Location & Mapping
      Permission.accessLiveMap.value,
      Permission.trackRealTimeLocation.value,

      // Route Management - Driver View
      Permission.viewRoutes.value,
      Permission.coordinateWithPolice.value,

      // Reports - Limited
      Permission.viewPerformanceMetrics.value,
    ];

    return RoleSpecificData(
      licenseNumber: licenseNumber,
      assignedAmbulances: assignedAmbulances ?? [],
      isAvailable: isAvailable,
      lastAvailabilityUpdate: DateTime.now(),
      permissions: customPermissions ?? defaultPermissions,
    );
  }

  factory RoleSpecificData.forPolice({
    required String badgeNumber,
    required String department,
    List<String>? customPermissions,
  }) {
    final defaultPermissions = [
      // Emergency Management - Coordination
      Permission.viewEmergencies.value,
      Permission.coordinateEmergencyResponse.value,

      // Route Management - Full Access
      Permission.viewRoutes.value,
      Permission.createRoutes.value,
      Permission.optimizeRoutes.value,
      Permission.clearTrafficRoutes.value,
      Permission.manageTrafficSignals.value,
      Permission.coordinateWithPolice.value,

      // Police Specific - Full Access
      Permission.accessPoliceDatabase.value,
      Permission.manageTrafficIncidents.value,
      Permission.accessEmergencyProtocols.value,

      // Communication
      Permission.sendNotifications.value,
      Permission.receivePushNotifications.value,
      Permission.accessMessaging.value,
      Permission.emergencyBroadcast.value,

      // Location & Mapping
      Permission.accessLiveMap.value,
      Permission.trackRealTimeLocation.value,
      Permission.viewLocationHistory.value,
      Permission.manageGeofences.value,

      // Ambulance Tracking - Read Only
      Permission.viewAmbulances.value,
      Permission.trackAmbulanceLocation.value,

      // Reports - Traffic & Emergency Related
      Permission.viewReports.value,
      Permission.generateReports.value,
      Permission.viewPerformanceMetrics.value,

      // Incident Management
      Permission.reportIncidents.value,

      // Audit for police actions
      Permission.viewAuditLogs.value,
    ];

    return RoleSpecificData(
      badgeNumber: badgeNumber,
      department: department,
      permissions: customPermissions ?? defaultPermissions,
    );
  }

  // Helper methods
  bool get hasHospitalAccess => hospitalId != null && hospitalId!.isNotEmpty;
  bool get hasDriverLicense =>
      licenseNumber != null && licenseNumber!.isNotEmpty;
  bool get hasPoliceCredentials =>
      badgeNumber != null &&
      badgeNumber!.isNotEmpty &&
      department != null &&
      department!.isNotEmpty;

  // Permission checking helper
  bool hasPermission(String permission) {
    return permissions.contains(permission);
  }

  // Driver-specific helpers
  bool get isOnShift => isAvailable ?? false;
  String get availabilityStatus =>
      (isAvailable ?? false) ? 'On Shift' : 'Off Shift';

  String get lastAvailabilityUpdateFormatted {
    if (lastAvailabilityUpdate == null) return 'Never updated';

    final now = DateTime.now();
    final difference = now.difference(lastAvailabilityUpdate!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
