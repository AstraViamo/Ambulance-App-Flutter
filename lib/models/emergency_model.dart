// lib/models/emergency_model.dart
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';

enum EmergencyPriority {
  low('low'),
  medium('medium'),
  high('high'),
  critical('critical');

  const EmergencyPriority(this.value);
  final String value;

  static EmergencyPriority fromString(String value) {
    return EmergencyPriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => EmergencyPriority.medium,
    );
  }

  String get displayName {
    switch (this) {
      case EmergencyPriority.low:
        return 'Low';
      case EmergencyPriority.medium:
        return 'Medium';
      case EmergencyPriority.high:
        return 'High';
      case EmergencyPriority.critical:
        return 'Critical';
    }
  }

  int get colorValue {
    switch (this) {
      case EmergencyPriority.low:
        return 0xFF4CAF50; // Green
      case EmergencyPriority.medium:
        return 0xFFFF9800; // Orange
      case EmergencyPriority.high:
        return 0xFFFF5722; // Deep Orange
      case EmergencyPriority.critical:
        return 0xFFF44336; // Red
    }
  }

  int get urgencyLevel {
    switch (this) {
      case EmergencyPriority.low:
        return 1;
      case EmergencyPriority.medium:
        return 2;
      case EmergencyPriority.high:
        return 3;
      case EmergencyPriority.critical:
        return 4;
    }
  }
}

enum EmergencyStatus {
  pending('pending'),
  assigned('assigned'),
  enRoute('en_route'),
  arrived('arrived'),
  completed('completed'),
  cancelled('cancelled');

  const EmergencyStatus(this.value);
  final String value;

  static EmergencyStatus fromString(String value) {
    return EmergencyStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => EmergencyStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case EmergencyStatus.pending:
        return 'Pending';
      case EmergencyStatus.assigned:
        return 'Assigned';
      case EmergencyStatus.enRoute:
        return 'En Route';
      case EmergencyStatus.arrived:
        return 'Arrived';
      case EmergencyStatus.completed:
        return 'Completed';
      case EmergencyStatus.cancelled:
        return 'Cancelled';
    }
  }

  int get colorValue {
    switch (this) {
      case EmergencyStatus.pending:
        return 0xFFFFC107; // Amber
      case EmergencyStatus.assigned:
        return 0xFF2196F3; // Blue
      case EmergencyStatus.enRoute:
        return 0xFF9C27B0; // Purple
      case EmergencyStatus.arrived:
        return 0xFFFF9800; // Orange
      case EmergencyStatus.completed:
        return 0xFF4CAF50; // Green
      case EmergencyStatus.cancelled:
        return 0xFF757575; // Grey
    }
  }
}

class EmergencyModel {
  final String id;
  final String callerName;
  final String callerPhone;
  final String description;
  final EmergencyPriority priority;
  final EmergencyStatus status;
  final String patientAddressString;
  final double patientLat;
  final double patientLng;
  final String hospitalId;
  final String createdBy; // User ID who created the emergency
  final DateTime createdAt;
  final DateTime updatedAt;

  // Assignment details
  final String? assignedAmbulanceId;
  final String? assignedDriverId;
  final DateTime? assignedAt;
  final DateTime? estimatedArrival;
  final DateTime? actualArrival;

  // Additional metadata
  final Map<String, dynamic>? additionalInfo;
  final List<String>? attachments; // URLs to images/documents
  final String? notes;

  EmergencyModel({
    required this.id,
    required this.callerName,
    required this.callerPhone,
    required this.description,
    required this.priority,
    required this.status,
    required this.patientAddressString,
    required this.patientLat,
    required this.patientLng,
    required this.hospitalId,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.assignedAmbulanceId,
    this.assignedDriverId,
    this.assignedAt,
    this.estimatedArrival,
    this.actualArrival,
    this.additionalInfo,
    this.attachments,
    this.notes,
  });

  // Convert from Firestore document
  factory EmergencyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return EmergencyModel(
      id: doc.id,
      callerName: data['callerName'] ?? '',
      callerPhone: data['callerPhone'] ?? '',
      description: data['description'] ?? '',
      priority: EmergencyPriority.fromString(data['priority'] ?? 'medium'),
      status: EmergencyStatus.fromString(data['status'] ?? 'pending'),
      patientAddressString: data['patientAddressString'] ?? '',
      patientLat: data['patientLat']?.toDouble() ?? 0.0,
      patientLng: data['patientLng']?.toDouble() ?? 0.0,
      hospitalId: data['hospitalId'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assignedAmbulanceId: data['assignedAmbulanceId'],
      assignedDriverId: data['assignedDriverId'],
      assignedAt: (data['assignedAt'] as Timestamp?)?.toDate(),
      estimatedArrival: (data['estimatedArrival'] as Timestamp?)?.toDate(),
      actualArrival: (data['actualArrival'] as Timestamp?)?.toDate(),
      additionalInfo: data['additionalInfo'] as Map<String, dynamic>?,
      attachments: data['attachments'] != null
          ? List<String>.from(data['attachments'])
          : null,
      notes: data['notes'],
    );
  }

  // Convert from raw data with ID
  factory EmergencyModel.fromMap(String id, Map<String, dynamic> data) {
    return EmergencyModel(
      id: id,
      callerName: data['callerName'] ?? '',
      callerPhone: data['callerPhone'] ?? '',
      description: data['description'] ?? '',
      priority: EmergencyPriority.fromString(data['priority'] ?? 'medium'),
      status: EmergencyStatus.fromString(data['status'] ?? 'pending'),
      patientAddressString: data['patientAddressString'] ?? '',
      patientLat: data['patientLat']?.toDouble() ?? 0.0,
      patientLng: data['patientLng']?.toDouble() ?? 0.0,
      hospitalId: data['hospitalId'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assignedAmbulanceId: data['assignedAmbulanceId'],
      assignedDriverId: data['assignedDriverId'],
      assignedAt: (data['assignedAt'] as Timestamp?)?.toDate(),
      estimatedArrival: (data['estimatedArrival'] as Timestamp?)?.toDate(),
      actualArrival: (data['actualArrival'] as Timestamp?)?.toDate(),
      additionalInfo: data['additionalInfo'] as Map<String, dynamic>?,
      attachments: data['attachments'] != null
          ? List<String>.from(data['attachments'])
          : null,
      notes: data['notes'],
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'callerName': callerName,
      'callerPhone': callerPhone,
      'description': description,
      'priority': priority.value,
      'status': status.value,
      'patientAddressString': patientAddressString,
      'patientLat': patientLat,
      'patientLng': patientLng,
      'hospitalId': hospitalId,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (assignedAmbulanceId != null)
        'assignedAmbulanceId': assignedAmbulanceId,
      if (assignedDriverId != null) 'assignedDriverId': assignedDriverId,
      if (assignedAt != null) 'assignedAt': Timestamp.fromDate(assignedAt!),
      if (estimatedArrival != null)
        'estimatedArrival': Timestamp.fromDate(estimatedArrival!),
      if (actualArrival != null)
        'actualArrival': Timestamp.fromDate(actualArrival!),
      if (additionalInfo != null) 'additionalInfo': additionalInfo,
      if (attachments != null) 'attachments': attachments,
      if (notes != null) 'notes': notes,
    };
  }

  // Copy with method for updates
  EmergencyModel copyWith({
    String? callerName,
    String? callerPhone,
    String? description,
    EmergencyPriority? priority,
    EmergencyStatus? status,
    String? patientAddressString,
    double? patientLat,
    double? patientLng,
    String? hospitalId,
    String? createdBy,
    DateTime? updatedAt,
    String? assignedAmbulanceId,
    String? assignedDriverId,
    DateTime? assignedAt,
    DateTime? estimatedArrival,
    DateTime? actualArrival,
    Map<String, dynamic>? additionalInfo,
    List<String>? attachments,
    String? notes,
  }) {
    return EmergencyModel(
      id: id,
      callerName: callerName ?? this.callerName,
      callerPhone: callerPhone ?? this.callerPhone,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      patientAddressString: patientAddressString ?? this.patientAddressString,
      patientLat: patientLat ?? this.patientLat,
      patientLng: patientLng ?? this.patientLng,
      hospitalId: hospitalId ?? this.hospitalId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      assignedAmbulanceId: assignedAmbulanceId ?? this.assignedAmbulanceId,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      assignedAt: assignedAt ?? this.assignedAt,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      actualArrival: actualArrival ?? this.actualArrival,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      attachments: attachments ?? this.attachments,
      notes: notes ?? this.notes,
    );
  }

  // Helper getters

  bool get isAssigned => assignedAmbulanceId != null;
  bool get isPending => status == EmergencyStatus.pending;
  bool get isCompleted => status == EmergencyStatus.completed;
  bool get isCancelled => status == EmergencyStatus.cancelled;
  bool get isEnRoute => status == EmergencyStatus.enRoute;
  bool get hasArrived => status == EmergencyStatus.arrived;

  bool get isActive =>
      status != EmergencyStatus.completed &&
      status != EmergencyStatus.cancelled;
  bool get isCritical => priority == EmergencyPriority.critical;
  bool get isHighPriority =>
      priority == EmergencyPriority.high ||
      priority == EmergencyPriority.critical;

  String get priorityDisplayName => priority.displayName;
  String get statusDisplayName => status.displayName;

  Color get priorityColor => Color(priority.colorValue);
  Color get statusColor => Color(status.colorValue);

  /// Get formatted creation date and time
  String get formattedCreatedAt {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final emergencyDate =
        DateTime(createdAt.year, createdAt.month, createdAt.day);

    if (emergencyDate.isAtSameMomentAs(today)) {
      // Today - show time only
      return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    } else if (emergencyDate
        .isAtSameMomentAs(today.subtract(const Duration(days: 1)))) {
      // Yesterday
      return 'Yesterday ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    } else {
      // Older - show date
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  Duration? get responseTime {
    if (assignedAt == null) return null;
    return assignedAt!.difference(createdAt);
  }

  /// Get total resolution time (from creation to completion)
  Duration? get totalTime {
    if (actualArrival == null) return null;
    return actualArrival!.difference(createdAt);
  }

  /// Get formatted response time
  String? get formattedResponseTime {
    final response = responseTime;
    if (response == null) return null;

    if (response.inHours > 0) {
      return '${response.inHours}h ${response.inMinutes % 60}m';
    } else {
      return '${response.inMinutes}m';
    }
  }

  // Get formatted time since creation
  String get timeSinceCreated {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Get estimated response time if assigned
  String? get estimatedResponseTime {
    if (estimatedArrival == null) return null;

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

  /// Get emergency urgency indicator for sorting and display
  int get urgencyScore {
    int priorityScore = priority.urgencyLevel * 10;

    // Add bonus for time sensitivity
    final hoursSinceCreated = DateTime.now().difference(createdAt).inHours;
    int timeBonus = (hoursSinceCreated * 0.5).round();

    return priorityScore + timeBonus;
  }

  /// Check if emergency is overdue (past estimated arrival time)
  bool get isOverdue {
    if (estimatedArrival == null || isCompleted || isCancelled) return false;
    return DateTime.now().isAfter(estimatedArrival!);
  }

  /// Get patient location summary
  String get locationSummary {
    if (patientAddressString.length <= 50) {
      return patientAddressString;
    }
    return '${patientAddressString.substring(0, 47)}...';
  }

  /// Get caller information summary
  String get callerSummary => '$callerName ($callerPhone)';

  /// Get emergency priority badge text
  String get priorityBadge {
    switch (priority) {
      case EmergencyPriority.critical:
        return '🚨 CRITICAL';
      case EmergencyPriority.high:
        return '⚠️ HIGH';
      case EmergencyPriority.medium:
        return '📋 MEDIUM';
      case EmergencyPriority.low:
        return '📝 LOW';
    }
  }

  /// Get emergency description summary (truncated if too long)
  String get descriptionSummary {
    if (description.length <= 100) {
      return description;
    }
    return '${description.substring(0, 97)}...';
  }

  /// Check if emergency needs immediate attention
  bool get needsImmediateAttention {
    return (priority == EmergencyPriority.critical ||
            priority == EmergencyPriority.high) &&
        isActive &&
        !isAssigned;
  }

  /// Get coordinates as a formatted string
  String get coordinatesString =>
      '${patientLat.toStringAsFixed(6)}, ${patientLng.toStringAsFixed(6)}';

  @override
  String toString() {
    return 'EmergencyModel(id: $id, callerName: $callerName, priority: $priority, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmergencyModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Place suggestion model for Google Places Autocomplete
class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final List<String> types;

  PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    required this.types,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: json['structured_formatting']?['main_text'] ?? '',
      secondaryText: json['structured_formatting']?['secondary_text'] ?? '',
      types: List<String>.from(json['types'] ?? []),
    );
  }
}

// Place details model for location coordinates
class PlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final Map<String, dynamic>? additionalInfo;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.additionalInfo,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry']?['location'];

    return PlaceDetails(
      placeId: json['place_id'] ?? '',
      name: json['name'] ?? '',
      formattedAddress: json['formatted_address'] ?? '',
      latitude: geometry?['lat']?.toDouble() ?? 0.0,
      longitude: geometry?['lng']?.toDouble() ?? 0.0,
      additionalInfo: json,
    );
  }
}
