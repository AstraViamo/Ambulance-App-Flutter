// lib/models/ambulance_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum AmbulanceStatus {
  available('available'),
  onDuty('on_duty'),
  maintenance('maintenance'),
  offline('offline');

  const AmbulanceStatus(this.value);
  final String value;

  static AmbulanceStatus fromString(String value) {
    return AmbulanceStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => AmbulanceStatus.offline,
    );
  }

  String get displayName {
    switch (this) {
      case AmbulanceStatus.available:
        return 'Available';
      case AmbulanceStatus.onDuty:
        return 'On Duty';
      case AmbulanceStatus.maintenance:
        return 'Maintenance';
      case AmbulanceStatus.offline:
        return 'Offline';
    }
  }

  // Get color for status display
  static int getStatusColor(AmbulanceStatus status) {
    switch (status) {
      case AmbulanceStatus.available:
        return 0xFF4CAF50; // Green
      case AmbulanceStatus.onDuty:
        return 0xFF2196F3; // Blue
      case AmbulanceStatus.maintenance:
        return 0xFFFF9800; // Orange
      case AmbulanceStatus.offline:
        return 0xFF9E9E9E; // Grey
    }
  }
}

class AmbulanceModel {
  final String id;
  final String licensePlate;
  final String model;
  final AmbulanceStatus status;
  final String? currentDriverId;
  final String hospitalId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? latitude;
  final double? longitude;
  final DateTime? lastLocationUpdate;

  AmbulanceModel({
    required this.id,
    required this.licensePlate,
    required this.model,
    required this.status,
    this.currentDriverId,
    required this.hospitalId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
    this.lastLocationUpdate,
  });

  // Convert from Firestore document
  factory AmbulanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AmbulanceModel(
      id: doc.id,
      licensePlate: data['licensePlate'] ?? '',
      model: data['model'] ?? '',
      status: AmbulanceStatus.fromString(data['status'] ?? 'offline'),
      currentDriverId: data['currentDriverId'],
      hospitalId: data['hospitalId'] ?? '',
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      lastLocationUpdate: (data['lastLocationUpdate'] as Timestamp?)?.toDate(),
    );
  }

  // Convert from raw data with ID (for use with driver service data)
  factory AmbulanceModel.fromMap(String id, Map<String, dynamic> data) {
    return AmbulanceModel(
      id: id,
      licensePlate: data['licensePlate'] ?? '',
      model: data['model'] ?? '',
      status: AmbulanceStatus.fromString(data['status'] ?? 'offline'),
      currentDriverId: data['currentDriverId'],
      hospitalId: data['hospitalId'] ?? '',
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      lastLocationUpdate: (data['lastLocationUpdate'] as Timestamp?)?.toDate(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'licensePlate': licensePlate,
      'model': model,
      'status': status.value,
      'currentDriverId': currentDriverId,
      'hospitalId': hospitalId,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (lastLocationUpdate != null)
        'lastLocationUpdate': Timestamp.fromDate(lastLocationUpdate!),
    };
  }

  // Copy with method for updates
  AmbulanceModel copyWith({
    String? licensePlate,
    String? model,
    AmbulanceStatus? status,
    String? currentDriverId,
    String? hospitalId,
    bool? isActive,
    DateTime? updatedAt,
    double? latitude,
    double? longitude,
    DateTime? lastLocationUpdate,
  }) {
    return AmbulanceModel(
      id: id,
      licensePlate: licensePlate ?? this.licensePlate,
      model: model ?? this.model,
      status: status ?? this.status,
      currentDriverId: currentDriverId ?? this.currentDriverId,
      hospitalId: hospitalId ?? this.hospitalId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
    );
  }

  // Helper getters
  bool get isAvailable => status == AmbulanceStatus.available && isActive;
  bool get hasDriver => currentDriverId != null && currentDriverId!.isNotEmpty;
  bool get hasLocation => latitude != null && longitude != null;

  String get statusDisplayName => status.displayName;

  // Get formatted last location update
  String get lastLocationUpdateFormatted {
    if (lastLocationUpdate == null) return 'No location data';

    final now = DateTime.now();
    final difference = now.difference(lastLocationUpdate!);

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

  @override
  String toString() {
    return 'AmbulanceModel(id: $id, licensePlate: $licensePlate, model: $model, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AmbulanceModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
