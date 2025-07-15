// lib/services/ambulance_assignment_service.dart
import 'dart:developer';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ambulance_model.dart';
import '../models/emergency_model.dart';
import '../models/route_model.dart';
import '../services/emergency_service.dart';
import '../services/notification_service.dart';
import '../services/route_service.dart';

class AmbulanceAssignmentService {
  static final AmbulanceAssignmentService _instance =
      AmbulanceAssignmentService._internal();
  factory AmbulanceAssignmentService() => _instance;
  AmbulanceAssignmentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EmergencyService _emergencyService = EmergencyService();
  final RouteService _routeService = RouteService();
  final NotificationService _notificationService = NotificationService();

  /// Calculate distance between two points using Haversine formula
  double calculateHaversineDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const double earthRadius = 6371000; // Earth's radius in meters

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final double distance = earthRadius * c;

    return distance; // Distance in meters
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Estimate travel time based on distance and average speed
  int estimateTravelTime(double distanceInMeters, {double avgSpeedKmh = 50}) {
    final double distanceInKm = distanceInMeters / 1000;
    final double timeInHours = distanceInKm / avgSpeedKmh;
    return (timeInHours * 60).round(); // Return time in minutes
  }

  /// Find the nearest available ambulance to a patient location
  Future<AmbulanceAssignmentResult?> findNearestAmbulance({
    required double patientLat,
    required double patientLon,
    required String hospitalId,
    EmergencyPriority priority = EmergencyPriority.medium,
  }) async {
    try {
      log('Finding nearest ambulance to patient at $patientLat, $patientLon');

      // Get all available ambulances for the hospital
      final ambulancesQuery = await _firestore
          .collection('ambulances')
          .where('hospitalId', isEqualTo: hospitalId)
          .where('status', isEqualTo: AmbulanceStatus.available.value)
          .where('isActive', isEqualTo: true)
          .where('currentDriverId', isNotEqualTo: null)
          .get();

      if (ambulancesQuery.docs.isEmpty) {
        log('No available ambulances found for hospital: $hospitalId');
        return null;
      }

      log('Found ${ambulancesQuery.docs.length} available ambulances');

      List<AmbulanceWithDistance> ambulancesWithDistance = [];

      // Calculate distance for each ambulance
      for (final doc in ambulancesQuery.docs) {
        final ambulanceData = doc.data();
        final latitude = ambulanceData['latitude']?.toDouble();
        final longitude = ambulanceData['longitude']?.toDouble();

        if (latitude != null && longitude != null) {
          final distance = calculateHaversineDistance(
            lat1: patientLat,
            lon1: patientLon,
            lat2: latitude,
            lon2: longitude,
          );

          final ambulance = AmbulanceModel.fromFirestore(doc);
          final estimatedTime = estimateTravelTime(distance);

          ambulancesWithDistance.add(AmbulanceWithDistance(
            ambulance: ambulance,
            distance: distance,
            estimatedArrivalTime: estimatedTime,
          ));

          log('Ambulance ${ambulance.licensePlate}: ${(distance / 1000).toStringAsFixed(2)}km, ${estimatedTime}min');
        }
      }

      if (ambulancesWithDistance.isEmpty) {
        log('No ambulances with valid location data found');
        return null;
      }

      // Sort by distance (closest first)
      ambulancesWithDistance.sort((a, b) => a.distance.compareTo(b.distance));

      // Apply priority-based selection
      final selectedAmbulance = _selectAmbulanceByPriority(
        ambulancesWithDistance,
        priority,
      );

      log('Selected ambulance: ${selectedAmbulance.ambulance.licensePlate} '
          'at ${(selectedAmbulance.distance / 1000).toStringAsFixed(2)}km');

      return AmbulanceAssignmentResult(
        ambulance: selectedAmbulance.ambulance,
        distance: selectedAmbulance.distance,
        estimatedArrivalTime: selectedAmbulance.estimatedArrivalTime,
        allCandidates: ambulancesWithDistance,
      );
    } catch (e) {
      log('Error finding nearest ambulance: $e');
      return null;
    }
  }

  AmbulanceWithDistance _selectAmbulanceByPriority(
    List<AmbulanceWithDistance> candidates,
    EmergencyPriority priority,
  ) {
    if (candidates.length == 1) return candidates.first;

    switch (priority) {
      case EmergencyPriority.critical:
        // For critical emergencies, always pick the absolute closest
        return candidates.first;

      case EmergencyPriority.high:
        // For high priority, pick from the closest 2 ambulances
        final topCandidates = candidates.take(2).toList();
        return topCandidates.first;

      case EmergencyPriority.medium:
      case EmergencyPriority.low:
        // For medium/low priority, consider load balancing
        // Pick from the closest 3 ambulances, preferring those with less recent assignments
        final topCandidates = candidates.take(3).toList();
        return topCandidates.first; // For now, just pick the closest
    }
  }

  /// Enhanced ambulance assignment with route calculation
  Future<bool> assignAmbulanceToEmergencyWithRoute({
    required String emergencyId,
    required String ambulanceId,
    required String driverId,
    required double distance,
    required int estimatedArrivalTime,
  }) async {
    try {
      log('Enhanced assignment: ambulance $ambulanceId to emergency $emergencyId');

      // Get emergency and ambulance details
      final emergencyDoc =
          await _firestore.collection('emergencies').doc(emergencyId).get();

      final ambulanceDoc =
          await _firestore.collection('ambulances').doc(ambulanceId).get();

      if (!emergencyDoc.exists || !ambulanceDoc.exists) {
        throw Exception('Emergency or ambulance not found');
      }

      final emergency = EmergencyModel.fromFirestore(emergencyDoc);
      final ambulance = AmbulanceModel.fromFirestore(ambulanceDoc);

      // Check if ambulance has location
      if (ambulance.latitude == null || ambulance.longitude == null) {
        throw Exception('Ambulance location not available');
      }

      final batch = _firestore.batch();

      // 1. Update emergency request
      final emergencyRef =
          _firestore.collection('emergencies').doc(emergencyId);
      batch.update(emergencyRef, {
        'status': EmergencyStatus.assigned.value,
        'assignedAmbulanceId': ambulanceId,
        'assignedDriverId': driverId,
        'assignedAt': FieldValue.serverTimestamp(),
        'estimatedDistance': distance,
        'estimatedArrivalTime': estimatedArrivalTime,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update ambulance status and last assignment time
      final ambulanceRef = _firestore.collection('ambulances').doc(ambulanceId);
      batch.update(ambulanceRef, {
        'status': AmbulanceStatus.onDuty.value,
        'lastAssignmentTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Create driver notification
      final driverNotificationRef =
          _firestore.collection('notifications').doc();
      batch.set(driverNotificationRef, {
        'type': 'emergency_assignment',
        'title': 'Emergency Assignment',
        'message': 'You have been assigned to a new emergency call',
        'recipientId': driverId,
        'emergencyRequestId': emergencyId,
        'ambulanceId': ambulanceId,
        'priority': emergency.priority.value,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'emergencyId': emergencyId,
          'distance': distance,
          'estimatedTime': estimatedArrivalTime,
          'patientLocation': emergency.patientAddressString,
          'priority': emergency.priority.value,
        },
      });

      await batch.commit();

      // 4. Calculate and create route (separate from batch for error handling)
      try {
        final route = await _routeService.calculateAmbulanceRoute(
          ambulanceId: ambulanceId,
          emergencyId: emergencyId,
          driverId: driverId,
          ambulanceLat: ambulance.latitude!,
          ambulanceLng: ambulance.longitude!,
          patientLat: emergency.patientLat,
          patientLng: emergency.patientLng,
          emergency: emergency,
          ambulance: ambulance,
        );

        if (route != null) {
          log('Route calculated successfully for emergency $emergencyId');

          // Update emergency with route ID
          await emergencyRef.update({
            'routeId': route.id,
            'calculatedETA': route.etaMinutes,
          });
        }
      } catch (routeError) {
        log('Route calculation failed but assignment succeeded: $routeError');
        // Assignment still succeeded even if route calculation failed
      }

      // 5. Send push notification to driver
      await _notificationService.sendNotificationToDriver(
        driverId: driverId,
        title: '🚨 Emergency Assignment',
        message:
            'New ${emergency.priority.displayName} emergency at ${emergency.patientAddressString}',
        data: {
          'type': 'emergency_assignment',
          'emergencyId': emergencyId,
          'ambulanceId': ambulanceId,
          'priority': emergency.priority.value,
        },
      );

      log('Enhanced ambulance assignment completed successfully');
      return true;
    } catch (e) {
      log('Enhanced ambulance assignment failed: $e');
      throw Exception('Failed to assign ambulance with route: $e');
    }
  }

  /// Auto-assign nearest ambulance with route calculation
  Future<bool> autoAssignNearestAmbulanceWithRoute({
    required String emergencyId,
    required String hospitalId,
  }) async {
    try {
      log('Auto-assigning nearest ambulance for emergency $emergencyId');

      // Get emergency details
      final emergencyDoc =
          await _firestore.collection('emergencies').doc(emergencyId).get();

      if (!emergencyDoc.exists) {
        throw Exception('Emergency not found');
      }

      final emergency = EmergencyModel.fromFirestore(emergencyDoc);

      // Find nearest available ambulance
      final assignmentResult = await findNearestAmbulance(
        patientLat: emergency.patientLat,
        patientLon: emergency.patientLng,
        hospitalId: hospitalId,
        priority: emergency.priority,
      );

      if (assignmentResult != null) {
        // Use the enhanced assignment method
        final success = await assignAmbulanceToEmergencyWithRoute(
          emergencyId: emergencyId,
          ambulanceId: assignmentResult.ambulance.id,
          driverId: assignmentResult.ambulance.currentDriverId!,
          distance: assignmentResult.distance,
          estimatedArrivalTime: assignmentResult.estimatedArrivalTime,
        );

        return success;
      }

      return false;
    } catch (e) {
      log('Auto-assignment with route failed: $e');
      throw Exception('Failed to auto-assign ambulance with route: $e');
    }
  }

  /// Original assignment method for backward compatibility
  Future<bool> assignAmbulanceToEmergency({
    required String emergencyRequestId,
    required String ambulanceId,
    required String driverId,
    required double distance,
    required int estimatedArrivalTime,
  }) async {
    try {
      log('Assigning ambulance $ambulanceId to emergency $emergencyRequestId');

      final batch = _firestore.batch();

      // Update emergency request
      final emergencyRef =
          _firestore.collection('emergencies').doc(emergencyRequestId);

      batch.update(emergencyRef, {
        'status': EmergencyStatus.assigned.value,
        'assignedAmbulanceId': ambulanceId,
        'assignedDriverId': driverId,
        'assignedAt': FieldValue.serverTimestamp(),
        'estimatedDistance': distance,
        'estimatedArrivalTime': estimatedArrivalTime,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update ambulance status
      final ambulanceRef = _firestore.collection('ambulances').doc(ambulanceId);
      batch.update(ambulanceRef, {
        'status': AmbulanceStatus.onDuty.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create assignment notification for driver
      final notificationRef = _firestore.collection('notifications').doc();
      batch.set(notificationRef, {
        'type': 'emergency_assignment',
        'title': 'Emergency Assignment',
        'message': 'You have been assigned to a new emergency call',
        'recipientId': driverId,
        'emergencyRequestId': emergencyRequestId,
        'ambulanceId': ambulanceId,
        'priority': 'high',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'emergencyId': emergencyRequestId,
          'distance': distance,
          'estimatedTime': estimatedArrivalTime,
        },
      });

      await batch.commit();

      // Send push notification to driver
      await _notificationService.sendNotificationToDriver(
        driverId: driverId,
        title: 'Emergency Assignment',
        message:
            'You have been assigned to a new emergency call. ETA: ${estimatedArrivalTime}min',
        data: {
          'type': 'emergency_assignment',
          'emergencyId': emergencyRequestId,
          'ambulanceId': ambulanceId,
        },
      );

      log('Successfully assigned ambulance to emergency');
      return true;
    } catch (e) {
      log('Error assigning ambulance to emergency: $e');
      return false;
    }
  }

  /// Find and assign the nearest ambulance automatically
  Future<AmbulanceAssignmentResult?> findAndAssignNearestAmbulance({
    required String emergencyRequestId,
    required double patientLat,
    required double patientLon,
    required String hospitalId,
    required EmergencyPriority priority,
  }) async {
    try {
      // Find nearest ambulance
      final result = await findNearestAmbulance(
        patientLat: patientLat,
        patientLon: patientLon,
        hospitalId: hospitalId,
        priority: priority,
      );

      if (result == null) {
        log('No ambulance found for assignment');
        return null;
      }

      // Assign the ambulance using enhanced method
      final success = await assignAmbulanceToEmergencyWithRoute(
        emergencyId: emergencyRequestId,
        ambulanceId: result.ambulance.id,
        driverId: result.ambulance.currentDriverId!,
        distance: result.distance,
        estimatedArrivalTime: result.estimatedArrivalTime,
      );

      if (success) {
        log('Successfully found and assigned nearest ambulance');
        return result;
      } else {
        log('Failed to assign ambulance');
        return null;
      }
    } catch (e) {
      log('Error in findAndAssignNearestAmbulance: $e');
      return null;
    }
  }

  /// Get all ambulances within a specific radius
  Future<List<AmbulanceWithDistance>> getAmbulancesInRadius({
    required double centerLat,
    required double centerLon,
    required double radiusInMeters,
    required String hospitalId,
    bool onlyAvailable = true,
  }) async {
    try {
      var query = _firestore
          .collection('ambulances')
          .where('hospitalId', isEqualTo: hospitalId)
          .where('isActive', isEqualTo: true);

      if (onlyAvailable) {
        query =
            query.where('status', isEqualTo: AmbulanceStatus.available.value);
      }

      final ambulancesQuery = await query.get();
      List<AmbulanceWithDistance> ambulancesInRadius = [];

      for (final doc in ambulancesQuery.docs) {
        final ambulanceData = doc.data();
        final latitude = ambulanceData['latitude']?.toDouble();
        final longitude = ambulanceData['longitude']?.toDouble();

        if (latitude != null && longitude != null) {
          final distance = calculateHaversineDistance(
            lat1: centerLat,
            lon1: centerLon,
            lat2: latitude,
            lon2: longitude,
          );

          if (distance <= radiusInMeters) {
            final ambulance = AmbulanceModel.fromFirestore(doc);
            final estimatedTime = estimateTravelTime(distance);

            ambulancesInRadius.add(AmbulanceWithDistance(
              ambulance: ambulance,
              distance: distance,
              estimatedArrivalTime: estimatedTime,
            ));
          }
        }
      }

      // Sort by distance
      ambulancesInRadius.sort((a, b) => a.distance.compareTo(b.distance));

      return ambulancesInRadius;
    } catch (e) {
      log('Error getting ambulances in radius: $e');
      return [];
    }
  }

  /// Complete emergency and route
  Future<void> completeEmergencyWithRoute({
    required String emergencyId,
    required String ambulanceId,
    String? notes,
  }) async {
    try {
      log('Completing emergency $emergencyId with route cleanup');

      final batch = _firestore.batch();

      // 1. Update emergency status
      final emergencyRef =
          _firestore.collection('emergencies').doc(emergencyId);
      batch.update(emergencyRef, {
        'status': EmergencyStatus.completed.value,
        'actualArrival': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (notes != null) 'completionNotes': notes,
      });

      // 2. Update ambulance status
      final ambulanceRef = _firestore.collection('ambulances').doc(ambulanceId);
      batch.update(ambulanceRef, {
        'status': AmbulanceStatus.available.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // 3. Complete associated route
      try {
        final route = await _routeService.getRouteForEmergency(emergencyId);
        if (route != null) {
          await _routeService.completeRoute(route.id);
        }
      } catch (routeError) {
        log('Error completing route: $routeError');
        // Don't fail the entire operation if route completion fails
      }

      log('Emergency and route completed successfully');
    } catch (e) {
      log('Error completing emergency with route: $e');
      throw Exception('Failed to complete emergency with route: $e');
    }
  }

  /// Cancel assignment and route
  Future<void> cancelAssignmentWithRoute({
    required String emergencyId,
    required String ambulanceId,
    String? reason,
  }) async {
    try {
      log('Canceling assignment for emergency $emergencyId');

      final batch = _firestore.batch();

      // 1. Update emergency status
      final emergencyRef =
          _firestore.collection('emergencies').doc(emergencyId);
      batch.update(emergencyRef, {
        'status': EmergencyStatus.pending.value,
        'assignedAmbulanceId': FieldValue.delete(),
        'assignedDriverId': FieldValue.delete(),
        'assignedAt': FieldValue.delete(),
        'routeId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (reason != null) 'cancellationReason': reason,
      });

      // 2. Update ambulance status
      final ambulanceRef = _firestore.collection('ambulances').doc(ambulanceId);
      batch.update(ambulanceRef, {
        'status': AmbulanceStatus.available.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // 3. Cancel associated route
      try {
        final route = await _routeService.getRouteForEmergency(emergencyId);
        if (route != null) {
          await _routeService.updateRouteStatus(
            routeId: route.id,
            newStatus: RouteStatus.completed,
            policeOfficerId: 'system',
            policeOfficerName: 'System',
            notes: 'Route cancelled due to assignment cancellation',
          );
        }
      } catch (routeError) {
        log('Error cancelling route: $routeError');
        // Don't fail the entire operation if route cancellation fails
      }

      log('Assignment and route cancelled successfully');
    } catch (e) {
      log('Error cancelling assignment with route: $e');
      throw Exception('Failed to cancel assignment with route: $e');
    }
  }

  /// Release ambulance from emergency
  Future<bool> releaseAmbulance(
      String ambulanceId, String emergencyRequestId) async {
    try {
      log('Releasing ambulance $ambulanceId from emergency $emergencyRequestId');

      final batch = _firestore.batch();

      // Update ambulance status to available
      final ambulanceRef = _firestore.collection('ambulances').doc(ambulanceId);
      batch.update(ambulanceRef, {
        'status': AmbulanceStatus.available.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update emergency status if not already completed
      if (emergencyRequestId.isNotEmpty) {
        final emergencyRef =
            _firestore.collection('emergencies').doc(emergencyRequestId);

        final emergencyDoc = await emergencyRef.get();
        if (emergencyDoc.exists) {
          final data = emergencyDoc.data() as Map<String, dynamic>;
          final currentStatus =
              EmergencyStatus.fromString(data['status'] ?? '');

          if (currentStatus != EmergencyStatus.completed) {
            batch.update(emergencyRef, {
              'status': EmergencyStatus.completed.value,
              'completedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      await batch.commit();
      log('Released ambulance $ambulanceId from emergency $emergencyRequestId');
      return true;
    } catch (e) {
      log('Error releasing ambulance: $e');
      return false;
    }
  }

  /// Get emergency with route information
  Future<Map<String, dynamic>?> getEmergencyWithRoute(
      String emergencyId) async {
    try {
      final emergencyDoc =
          await _firestore.collection('emergencies').doc(emergencyId).get();

      if (!emergencyDoc.exists) return null;

      final emergency = EmergencyModel.fromFirestore(emergencyDoc);
      final result = <String, dynamic>{
        'emergency': emergency,
        'route': null,
        'ambulance': null,
      };

      // Get route if exists
      if (emergency.assignedAmbulanceId != null) {
        final route = await _routeService.getRouteForEmergency(emergencyId);
        if (route != null) {
          result['route'] = route;
        }

        // Get ambulance details
        final ambulanceDoc = await _firestore
            .collection('ambulances')
            .doc(emergency.assignedAmbulanceId!)
            .get();

        if (ambulanceDoc.exists) {
          result['ambulance'] = AmbulanceModel.fromFirestore(ambulanceDoc);
        }
      }

      return result;
    } catch (e) {
      log('Error getting emergency with route: $e');
      return null;
    }
  }
}

class AmbulanceWithDistance {
  final AmbulanceModel ambulance;
  final double distance; // in meters
  final int estimatedArrivalTime; // in minutes

  AmbulanceWithDistance({
    required this.ambulance,
    required this.distance,
    required this.estimatedArrivalTime,
  });

  double get distanceInKm => distance / 1000;

  String get distanceFormatted {
    if (distanceInKm < 1) {
      return '${distance.round()}m';
    } else {
      return '${distanceInKm.toStringAsFixed(1)}km';
    }
  }

  String get estimatedTimeFormatted {
    if (estimatedArrivalTime < 60) {
      return '${estimatedArrivalTime}min';
    } else {
      final hours = estimatedArrivalTime ~/ 60;
      final minutes = estimatedArrivalTime % 60;
      return '${hours}h ${minutes}m';
    }
  }
}

class AmbulanceAssignmentResult {
  final AmbulanceModel ambulance;
  final double distance;
  final int estimatedArrivalTime;
  final List<AmbulanceWithDistance> allCandidates;

  AmbulanceAssignmentResult({
    required this.ambulance,
    required this.distance,
    required this.estimatedArrivalTime,
    required this.allCandidates,
  });

  double get distanceInKm => distance / 1000;

  String get summary =>
      'Assigned ${ambulance.licensePlate} - ${(distanceInKm).toStringAsFixed(1)}km away, ETA: ${estimatedArrivalTime}min';
}
