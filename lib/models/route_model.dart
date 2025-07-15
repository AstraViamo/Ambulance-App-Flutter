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
      if (estimatedArrival != null)
        'estimatedArrival': Timestamp.fromDate(estimatedArrival!),
      if (policeOfficerId != null) 'policeOfficerId': policeOfficerId,
      if (policeOfficerName != null) 'policeOfficerName': policeOfficerName,
      if (statusUpdatedAt != null)
        'statusUpdatedAt': Timestamp.fromDate(statusUpdatedAt!),
      if (statusNotes != null) 'statusNotes': statusNotes,
    };
  }

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()}m';
    } else {
      return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
    }
  }

  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String get formattedETA {
    if (estimatedArrival == null) return 'Unknown';

    final now = DateTime.now();
    final timeToArrival = estimatedArrival!.difference(now);

    if (timeToArrival.isNegative) {
      return 'Overdue by ${(-timeToArrival.inMinutes)}m';
    } else if (timeToArrival.inMinutes < 60) {
      return '${timeToArrival.inMinutes}m';
    } else {
      return '${timeToArrival.inHours}h ${timeToArrival.inMinutes % 60}m';
    }
  }

  bool get isHighPriority {
    return emergencyPriority == 'critical' || emergencyPriority == 'high';
  }

  AmbulanceRouteModel copyWith({
    RouteStatus? status,
    String? policeOfficerId,
    String? policeOfficerName,
    DateTime? statusUpdatedAt,
    String? statusNotes,
    DateTime? updatedAt,
  }) {
    return AmbulanceRouteModel(
      id: id,
      ambulanceId: ambulanceId,
      emergencyId: emergencyId,
      driverId: driverId,
      ambulanceLicensePlate: ambulanceLicensePlate,
      status: status ?? this.status,
      encodedPolyline: encodedPolyline,
      steps: steps,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      etaMinutes: etaMinutes,
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
      startAddress: startAddress,
      endAddress: endAddress,
      emergencyPriority: emergencyPriority,
      patientLocation: patientLocation,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      estimatedArrival: estimatedArrival,
      policeOfficerId: policeOfficerId ?? this.policeOfficerId,
      policeOfficerName: policeOfficerName ?? this.policeOfficerName,
      statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
      statusNotes: statusNotes ?? this.statusNotes,
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
