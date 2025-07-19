// lib/models/route_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum RouteStatus {
  active('active'),
  cleared('cleared'),
  timeout('timeout'),
  completed('completed');

  const RouteStatus(this.value);
  final String value;

  static RouteStatus fromString(String value) {
    return RouteStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => RouteStatus.active,
    );
  }

  String get displayName {
    switch (this) {
      case RouteStatus.active:
        return 'Active';
      case RouteStatus.cleared:
        return 'Traffic Cleared';
      case RouteStatus.timeout:
        return 'Timeout';
      case RouteStatus.completed:
        return 'Completed';
    }
  }

  int get colorValue {
    switch (this) {
      case RouteStatus.active:
        return 0xFF2196F3; // Blue
      case RouteStatus.cleared:
        return 0xFF4CAF50; // Green
      case RouteStatus.timeout:
        return 0xFFFF9800; // Orange
      case RouteStatus.completed:
        return 0xFF9E9E9E; // Grey
    }
  }

  /// Check if this status can transition to the new status
  bool canTransitionTo(RouteStatus newStatus) {
    switch (this) {
      case RouteStatus.active:
        return newStatus == RouteStatus.cleared ||
            newStatus == RouteStatus.timeout ||
            newStatus == RouteStatus.completed;
      case RouteStatus.cleared:
        return newStatus == RouteStatus.completed ||
            newStatus == RouteStatus.timeout;
      case RouteStatus.timeout:
        return newStatus == RouteStatus.active ||
            newStatus == RouteStatus.completed;
      case RouteStatus.completed:
        return false; // Terminal status
    }
  }

  /// Get valid next statuses from current status
  List<RouteStatus> get validNextStatuses {
    switch (this) {
      case RouteStatus.active:
        return [
          RouteStatus.cleared,
          RouteStatus.timeout,
          RouteStatus.completed
        ];
      case RouteStatus.cleared:
        return [RouteStatus.completed, RouteStatus.timeout];
      case RouteStatus.timeout:
        return [RouteStatus.active, RouteStatus.completed];
      case RouteStatus.completed:
        return []; // Terminal status
    }
  }

  /// Check if route is considered "active" for hospital dashboard
  /// (active routes are those not yet completed)
  bool get isActiveForHospital {
    return this == RouteStatus.active || this == RouteStatus.cleared;
  }

  /// Check if route is pending for police (needs clearance)
  bool get isPendingForPolice {
    return this == RouteStatus.active;
  }

  /// Check if route is active for police (cleared but not completed)
  bool get isActiveForPolice {
    return this == RouteStatus.cleared;
  }

  /// Check if route is completed
  bool get isCompleted {
    return this == RouteStatus.completed;
  }
}

class AmbulanceRouteModel {
  final String id;
  final String ambulanceId;
  final String emergencyId;
  final String driverId;
  final String ambulanceLicensePlate;
  final RouteStatus status;
  final String encodedPolyline;
  final List<RouteStep> steps;
  final double distanceMeters;
  final int durationSeconds;
  final int etaMinutes;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final String startAddress;
  final String endAddress;
  final String emergencyPriority;
  final String patientLocation;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? estimatedArrival;

  // Police management fields
  final String? policeOfficerId;
  final String? policeOfficerName;
  final DateTime? statusUpdatedAt;
  final String? statusNotes;

  // Additional tracking fields for better status management
  final DateTime? clearedAt;
  final DateTime? completedAt;
  final String? completionReason;

  AmbulanceRouteModel({
    required this.id,
    required this.ambulanceId,
    required this.emergencyId,
    required this.driverId,
    required this.ambulanceLicensePlate,
    required this.status,
    required this.encodedPolyline,
    required this.steps,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.etaMinutes,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    required this.startAddress,
    required this.endAddress,
    required this.emergencyPriority,
    required this.patientLocation,
    required this.createdAt,
    required this.updatedAt,
    this.estimatedArrival,
    this.policeOfficerId,
    this.policeOfficerName,
    this.statusUpdatedAt,
    this.statusNotes,
    this.clearedAt,
    this.completedAt,
    this.completionReason,
  });

  factory AmbulanceRouteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AmbulanceRouteModel(
      id: doc.id,
      ambulanceId: data['ambulanceId'] ?? '',
      emergencyId: data['emergencyId'] ?? '',
      driverId: data['driverId'] ?? '',
      ambulanceLicensePlate: data['ambulanceLicensePlate'] ?? '',
      status: RouteStatus.fromString(data['status'] ?? 'active'),
      encodedPolyline: data['encodedPolyline'] ?? '',
      steps: (data['steps'] as List<dynamic>?)
              ?.map((step) => RouteStep.fromMap(step))
              .toList() ??
          [],
      distanceMeters: data['distanceMeters']?.toDouble() ?? 0.0,
      durationSeconds: data['durationSeconds']?.toInt() ?? 0,
      etaMinutes: data['etaMinutes']?.toInt() ?? 0,
      startLat: data['startLat']?.toDouble() ?? 0.0,
      startLng: data['startLng']?.toDouble() ?? 0.0,
      endLat: data['endLat']?.toDouble() ?? 0.0,
      endLng: data['endLng']?.toDouble() ?? 0.0,
      startAddress: data['startAddress'] ?? '',
      endAddress: data['endAddress'] ?? '',
      emergencyPriority: data['emergencyPriority'] ?? 'medium',
      patientLocation: data['patientLocation'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      estimatedArrival: (data['estimatedArrival'] as Timestamp?)?.toDate(),
      policeOfficerId: data['policeOfficerId'],
      policeOfficerName: data['policeOfficerName'],
      statusUpdatedAt: (data['statusUpdatedAt'] as Timestamp?)?.toDate(),
      statusNotes: data['statusNotes'],
      clearedAt: (data['clearedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      completionReason: data['completionReason'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ambulanceId': ambulanceId,
      'emergencyId': emergencyId,
      'driverId': driverId,
      'ambulanceLicensePlate': ambulanceLicensePlate,
      'status': status.value,
      'encodedPolyline': encodedPolyline,
      'steps': steps.map((step) => step.toMap()).toList(),
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'etaMinutes': etaMinutes,
      'startLat': startLat,
      'startLng': startLng,
      'endLat': endLat,
      'endLng': endLng,
      'startAddress': startAddress,
      'endAddress': endAddress,
      'emergencyPriority': emergencyPriority,
      'patientLocation': patientLocation,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'estimatedArrival': estimatedArrival != null
          ? Timestamp.fromDate(estimatedArrival!)
          : null,
      'policeOfficerId': policeOfficerId,
      'policeOfficerName': policeOfficerName,
      'statusUpdatedAt':
          statusUpdatedAt != null ? Timestamp.fromDate(statusUpdatedAt!) : null,
      'statusNotes': statusNotes,
      'clearedAt': clearedAt != null ? Timestamp.fromDate(clearedAt!) : null,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'completionReason': completionReason,
    };
  }

  // Helper getters for UI display
  bool get isHighPriority =>
      emergencyPriority == 'critical' || emergencyPriority == 'high';

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toInt()}m';
    } else {
      return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
    }
  }

  String get formattedDuration {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) {
      return '${minutes}min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}min';
    }
  }

  String get formattedETA {
    return '${etaMinutes}min';
  }

  /// Get status description based on role perspective
  String getStatusDescription(String userRole) {
    switch (userRole) {
      case 'police':
        switch (status) {
          case RouteStatus.active:
            return 'Pending Clearance';
          case RouteStatus.cleared:
            return 'Traffic Cleared';
          case RouteStatus.timeout:
            return 'Clearance Timeout';
          case RouteStatus.completed:
            return 'Route Completed';
        }
      case 'hospital_admin':
      case 'hospital_staff':
        switch (status) {
          case RouteStatus.active:
            return 'En Route (Traffic)';
          case RouteStatus.cleared:
            return 'En Route (Clear)';
          case RouteStatus.timeout:
            return 'Delayed';
          case RouteStatus.completed:
            return 'Arrived';
        }
      default:
        return status.displayName;
    }
  }

  /// Validate status transition
  bool canTransitionTo(RouteStatus newStatus) {
    return status.canTransitionTo(newStatus);
  }

  /// Get route history summary for display
  Map<String, dynamic> get historyInfo {
    return {
      'emergency': {
        'id': emergencyId,
        'priority': emergencyPriority,
        'location': patientLocation,
      },
      'driver': {
        'id': driverId,
        'ambulance': ambulanceLicensePlate,
      },
      'police': policeOfficerId != null
          ? {
              'officerId': policeOfficerId,
              'officerName': policeOfficerName,
              'clearedAt': clearedAt,
              'notes': statusNotes,
            }
          : null,
      'timeline': {
        'created': createdAt,
        'cleared': clearedAt,
        'completed': completedAt,
      },
      'completion': {
        'reason': completionReason,
        'duration': completedAt != null
            ? completedAt!.difference(createdAt).inMinutes
            : null,
      }
    };
  }

  AmbulanceRouteModel copyWith({
    String? id,
    String? ambulanceId,
    String? emergencyId,
    String? driverId,
    String? ambulanceLicensePlate,
    RouteStatus? status,
    String? encodedPolyline,
    List<RouteStep>? steps,
    double? distanceMeters,
    int? durationSeconds,
    int? etaMinutes,
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
    String? startAddress,
    String? endAddress,
    String? emergencyPriority,
    String? patientLocation,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? estimatedArrival,
    String? policeOfficerId,
    String? policeOfficerName,
    DateTime? statusUpdatedAt,
    String? statusNotes,
    DateTime? clearedAt,
    DateTime? completedAt,
    String? completionReason,
  }) {
    return AmbulanceRouteModel(
      id: id ?? this.id,
      ambulanceId: ambulanceId ?? this.ambulanceId,
      emergencyId: emergencyId ?? this.emergencyId,
      driverId: driverId ?? this.driverId,
      ambulanceLicensePlate:
          ambulanceLicensePlate ?? this.ambulanceLicensePlate,
      status: status ?? this.status,
      encodedPolyline: encodedPolyline ?? this.encodedPolyline,
      steps: steps ?? this.steps,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      startLat: startLat ?? this.startLat,
      startLng: startLng ?? this.startLng,
      endLat: endLat ?? this.endLat,
      endLng: endLng ?? this.endLng,
      startAddress: startAddress ?? this.startAddress,
      endAddress: endAddress ?? this.endAddress,
      emergencyPriority: emergencyPriority ?? this.emergencyPriority,
      patientLocation: patientLocation ?? this.patientLocation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      policeOfficerId: policeOfficerId ?? this.policeOfficerId,
      policeOfficerName: policeOfficerName ?? this.policeOfficerName,
      statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
      statusNotes: statusNotes ?? this.statusNotes,
      clearedAt: clearedAt ?? this.clearedAt,
      completedAt: completedAt ?? this.completedAt,
      completionReason: completionReason ?? this.completionReason,
    );
  }
}

class RouteStep {
  final String instruction;
  final double distanceMeters;
  final int durationSeconds;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final String maneuver;

  RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    required this.maneuver,
  });

  factory RouteStep.fromMap(Map<String, dynamic> data) {
    return RouteStep(
      instruction: data['instruction'] ?? '',
      distanceMeters: data['distanceMeters']?.toDouble() ?? 0.0,
      durationSeconds: data['durationSeconds']?.toInt() ?? 0,
      startLat: data['startLat']?.toDouble() ?? 0.0,
      startLng: data['startLng']?.toDouble() ?? 0.0,
      endLat: data['endLat']?.toDouble() ?? 0.0,
      endLng: data['endLng']?.toDouble() ?? 0.0,
      maneuver: data['maneuver'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'instruction': instruction,
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'startLat': startLat,
      'startLng': startLng,
      'endLat': endLat,
      'endLng': endLng,
      'maneuver': maneuver,
    };
  }
}
