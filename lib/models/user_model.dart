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
  final List<String>? permissions;
  final bool? isAvailable; // For drivers - their shift availability
  final DateTime? lastAvailabilityUpdate; // When driver toggled availability

  RoleSpecificData({
    this.hospitalId,
    this.licenseNumber,
    this.badgeNumber,
    this.department,
    this.assignedAmbulances,
    this.permissions,
    this.isAvailable,
    this.lastAvailabilityUpdate,
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (hospitalId != null) 'hospitalId': hospitalId,
      if (licenseNumber != null) 'licenseNumber': licenseNumber,
      if (badgeNumber != null) 'badgeNumber': badgeNumber,
      if (department != null) 'department': department,
      if (assignedAmbulances != null) 'assignedAmbulances': assignedAmbulances,
      if (permissions != null) 'permissions': permissions,
      if (isAvailable != null) 'isAvailable': isAvailable,
      if (lastAvailabilityUpdate != null)
        'lastAvailabilityUpdate': Timestamp.fromDate(lastAvailabilityUpdate!),
    };
  }

  // Factory methods for different roles
  factory RoleSpecificData.forHospitalAdmin({
    required String hospitalId,
    List<String>? permissions,
  }) {
    return RoleSpecificData(
      hospitalId: hospitalId,
      permissions: permissions ??
          [
            'manage_ambulances',
            'manage_staff',
            'view_reports',
            'assign_ambulances'
          ],
    );
  }

  factory RoleSpecificData.forHospitalStaff({
    required String hospitalId,
  }) {
    return RoleSpecificData(
      hospitalId: hospitalId,
      permissions: ['view_ambulances', 'assign_ambulances'],
    );
  }

  factory RoleSpecificData.forDriver({
    required String licenseNumber,
    List<String>? assignedAmbulances,
    bool isAvailable = false, // Default to off-duty
  }) {
    return RoleSpecificData(
      licenseNumber: licenseNumber,
      assignedAmbulances: assignedAmbulances ?? [],
      isAvailable: isAvailable,
      lastAvailabilityUpdate: DateTime.now(),
    );
  }

  factory RoleSpecificData.forPolice({
    required String badgeNumber,
    required String department,
  }) {
    return RoleSpecificData(
      badgeNumber: badgeNumber,
      department: department,
      permissions: ['view_routes', 'clear_traffic'],
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
