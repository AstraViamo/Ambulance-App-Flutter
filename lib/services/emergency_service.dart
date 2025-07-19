// lib/services/enhanced_emergency_service.dart
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ambulance_model.dart';
import '../models/emergency_model.dart';
import '../models/route_model.dart';
import '../services/notification_service.dart';
import '../services/route_service.dart';

class EmergencyService {
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RouteService _routeService = RouteService();
  final NotificationService _notificationService = NotificationService();

  // ==========================================================================
  // ENHANCED EMERGENCY COMPLETION WITH ROUTE INTEGRATION
  // ==========================================================================

  /// Complete emergency with comprehensive route and status management
  Future<void> completeEmergencyWithRouteIntegration({
    required String emergencyId,
    required String ambulanceId,
    required String driverId,
    required String completedBy,
    required String completedByName,
    String? completionNotes,
    String? routeCompletionReason,
    bool isDriverInitiated = false,
  }) async {
    try {
      log('Completing emergency $emergencyId with enhanced route integration');

      // Start a transaction to ensure data consistency
      await _firestore.runTransaction((transaction) async {
        // 1. Get current emergency and route data
        final emergencyRef =
            _firestore.collection('emergencies').doc(emergencyId);
        final emergencyDoc = await transaction.get(emergencyRef);

        if (!emergencyDoc.exists) {
          throw Exception('Emergency not found');
        }

        final emergency = EmergencyModel.fromFirestore(emergencyDoc);
        AmbulanceRouteModel? route;

        // Get associated route
        try {
          route = await _routeService.getRouteForEmergency(emergencyId);
        } catch (e) {
          log('No route found for emergency $emergencyId: $e');
        }

        // 2. Update emergency status
        final emergencyUpdateData = <String, dynamic>{
          'status': EmergencyStatus.completed.value,
          'actualArrival': FieldValue.serverTimestamp(),
          'completedAt': FieldValue.serverTimestamp(),
          'completedBy': completedBy,
          'completedByName': completedByName,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (completionNotes != null) {
          emergencyUpdateData['completionNotes'] = completionNotes;
        }

        if (isDriverInitiated) {
          emergencyUpdateData['completionSource'] = 'driver';
        } else {
          emergencyUpdateData['completionSource'] = 'hospital';
        }

        transaction.update(emergencyRef, emergencyUpdateData);

        // 3. Update ambulance status to available
        final ambulanceRef =
            _firestore.collection('ambulances').doc(ambulanceId);
        transaction.update(ambulanceRef, {
          'status': AmbulanceStatus.available.value,
          'currentDriverId': driverId, // Maintain driver assignment
          'lastCompletedEmergency': emergencyId,
          'lastCompletedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 4. Complete the route if it exists and isn't already completed
        if (route != null && route.status != RouteStatus.completed) {
          final routeRef = _firestore.collection('routes').doc(route.id);

          final routeUpdateData = <String, dynamic>{
            'status': RouteStatus.completed.value,
            'completedAt': FieldValue.serverTimestamp(),
            'completedBy': completedBy,
            'completedByName': completedByName,
            'updatedAt': FieldValue.serverTimestamp(),
          };

          if (routeCompletionReason != null) {
            routeUpdateData['completionReason'] = routeCompletionReason;
          } else {
            routeUpdateData['completionReason'] = isDriverInitiated
                ? 'Driver arrived at emergency location'
                : 'Emergency response completed by hospital staff';
          }

          transaction.update(routeRef, routeUpdateData);
        }

        // 5. Create completion audit record
        final auditRef = _firestore.collection('audit_trail').doc();
        transaction.set(auditRef, {
          'type': 'emergency_completion',
          'emergencyId': emergencyId,
          'ambulanceId': ambulanceId,
          'driverId': driverId,
          'routeId': route?.id,
          'completedBy': completedBy,
          'completedByName': completedByName,
          'completionSource': isDriverInitiated ? 'driver' : 'hospital',
          'completionNotes': completionNotes,
          'routeCompletionReason': routeCompletionReason,
          'timestamp': FieldValue.serverTimestamp(),
          'hospitalId': emergency.hospitalId,
        });
      });

      // 6. Send notifications after transaction completes
      await _sendCompletionNotifications(
        emergencyId: emergencyId,
        ambulanceId: ambulanceId,
        driverId: driverId,
        route: route,
        completedBy: completedByName,
        isDriverInitiated: isDriverInitiated,
      );

      log('Emergency and route completion successful');
    } catch (e) {
      log('Error in enhanced emergency completion: $e');
      throw Exception(
          'Failed to complete emergency with route integration: $e');
    }
  }

  /// Send completion notifications to all stakeholders
  Future<void> _sendCompletionNotifications({
    required String emergencyId,
    required String ambulanceId,
    required String driverId,
    required AmbulanceRouteModel? route,
    required String completedBy,
    required bool isDriverInitiated,
  }) async {
    try {
      // Get emergency details for hospital identification
      final emergencyDoc =
          await _firestore.collection('emergencies').doc(emergencyId).get();
      if (!emergencyDoc.exists) return;

      final emergency = EmergencyModel.fromFirestore(emergencyDoc);

      // Notify hospital staff
      await _notificationService.sendRouteNotificationToHospital(
        route: route!,
        type: 'route_completed',
        hospitalId: emergency.hospitalId,
        completionReason: isDriverInitiated
            ? 'Completed by driver arrival'
            : 'Completed by hospital staff',
        driverName: completedBy,
      );

      // Notify driver if completion was initiated by hospital
      if (!isDriverInitiated) {
        await _notificationService.sendRouteCompletionToDriver(
          driverId: driverId,
          route: route,
          completionReason: 'Emergency completed by hospital staff',
        );
      }

      // Notify police (for their records)
      if (route.policeOfficerId != null) {
        await _notificationService.sendNotificationToDriver(
          driverId: route.policeOfficerId!,
          title: '🏁 Emergency Route Completed',
          message: 'Route you assisted with has been completed successfully',
          type: 'route_completed',
          data: {
            'routeId': route.id,
            'emergencyId': emergencyId,
            'completedBy': completedBy,
          },
        );
      }
    } catch (e) {
      log('Error sending completion notifications: $e');
      // Don't throw - notifications failing shouldn't fail the completion
    }
  }

  // ==========================================================================
  // ENHANCED ASSIGNMENT WITH ROUTE CREATION
  // ==========================================================================

  /// Assign ambulance with automatic route creation and status tracking
  Future<bool> assignAmbulanceWithRouteCreation({
    required String emergencyId,
    required String ambulanceId,
    required String driverId,
    required double distance,
    required int estimatedArrivalTime,
  }) async {
    try {
      log('Enhanced assignment with route creation for emergency $emergencyId');

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

      // Validate ambulance location
      if (ambulance.latitude == null || ambulance.longitude == null) {
        throw Exception('Ambulance location not available');
      }

      // Start transaction for assignment
      await _firestore.runTransaction((transaction) async {
        // 1. Update emergency
        final emergencyRef =
            _firestore.collection('emergencies').doc(emergencyId);
        transaction.update(emergencyRef, {
          'status': EmergencyStatus.assigned.value,
          'assignedAmbulanceId': ambulanceId,
          'assignedDriverId': driverId,
          'assignedAt': FieldValue.serverTimestamp(),
          'estimatedDistance': distance,
          'estimatedArrivalTime': estimatedArrivalTime,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 2. Update ambulance status
        final ambulanceRef =
            _firestore.collection('ambulances').doc(ambulanceId);
        transaction.update(ambulanceRef, {
          'status': AmbulanceStatus.onDuty.value,
          'lastAssignmentTime': FieldValue.serverTimestamp(),
          'currentEmergencyId': emergencyId,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 3. Create assignment audit record
        final auditRef = _firestore.collection('audit_trail').doc();
        transaction.set(auditRef, {
          'type': 'emergency_assignment',
          'emergencyId': emergencyId,
          'ambulanceId': ambulanceId,
          'driverId': driverId,
          'distance': distance,
          'estimatedArrivalTime': estimatedArrivalTime,
          'timestamp': FieldValue.serverTimestamp(),
          'hospitalId': emergency.hospitalId,
        });
      });

      // 4. Create route after assignment (separate to avoid transaction timeout)
      AmbulanceRouteModel? route;
      try {
        route = await _routeService.calculateAmbulanceRoute(
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
          // Update emergency with route information
          await _firestore.collection('emergencies').doc(emergencyId).update({
            'routeId': route.id,
            'calculatedETA': route.etaMinutes,
            'routeDistance': route.distanceMeters,
            'routeDuration': route.durationSeconds,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          log('Route created successfully: ${route.id}');
        }
      } catch (routeError) {
        log('Route creation failed but assignment succeeded: $routeError');
        // Assignment can succeed even if route creation fails
      }

      // 5. Send notifications
      await _sendAssignmentNotifications(
        emergency: emergency,
        ambulance: ambulance,
        driverId: driverId,
        route: route,
      );

      log('Enhanced assignment completed successfully');
      return true;
    } catch (e) {
      log('Enhanced assignment failed: $e');
      throw Exception('Failed to assign ambulance with route creation: $e');
    }
  }

  /// Send assignment notifications to relevant parties
  Future<void> _sendAssignmentNotifications({
    required EmergencyModel emergency,
    required AmbulanceModel ambulance,
    required String driverId,
    required AmbulanceRouteModel? route,
  }) async {
    try {
      // Notify driver
      await _notificationService.sendNotificationToDriver(
        driverId: driverId,
        title: '🚨 Emergency Assignment',
        message:
            'New ${emergency.priority.displayName} emergency at ${emergency.location}',
        type: 'emergency_assignment',
        data: {
          'emergencyId': emergency.id,
          'ambulanceId': ambulance.id,
          'routeId': route?.id,
          'priority': emergency.priority.value,
          'patientLocation': emergency.location,
          'eta': route?.etaMinutes.toString(),
        },
        priority: emergency.priority == EmergencyPriority.critical
            ? 'critical'
            : 'high',
      );

      // Notify police if high priority and route exists
      if (route != null && emergency.priority.urgencyLevel >= 3) {
        await _notificationService.sendRouteNotificationToPolice(
          route: route,
          type: 'new_route',
        );
      }

      // Notify hospital staff
      await _notificationService.sendRouteNotificationToHospital(
        route: route!,
        type: 'emergency_assigned',
        hospitalId: emergency.hospitalId,
        driverName: ambulance.currentDriverId,
      );
    } catch (e) {
      log('Error sending assignment notifications: $e');
      // Don't throw - notifications failing shouldn't fail the assignment
    }
  }

  // ==========================================================================
  // ENHANCED CANCELLATION WITH ROUTE CLEANUP
  // ==========================================================================

  /// Cancel emergency assignment with comprehensive cleanup
  Future<void> cancelAssignmentWithCleanup({
    required String emergencyId,
    required String ambulanceId,
    required String cancelledBy,
    required String cancelledByName,
    String? cancellationReason,
  }) async {
    try {
      log('Cancelling assignment for emergency $emergencyId with cleanup');

      // Get current data
      final emergencyDoc =
          await _firestore.collection('emergencies').doc(emergencyId).get();
      if (!emergencyDoc.exists) {
        throw Exception('Emergency not found');
      }

      final emergency = EmergencyModel.fromFirestore(emergencyDoc);
      AmbulanceRouteModel? route;

      // Get associated route
      try {
        route = await _routeService.getRouteForEmergency(emergencyId);
      } catch (e) {
        log('No route found for emergency $emergencyId');
      }

      // Start transaction for cancellation
      await _firestore.runTransaction((transaction) async {
        // 1. Update emergency status
        final emergencyRef =
            _firestore.collection('emergencies').doc(emergencyId);
        transaction.update(emergencyRef, {
          'status': EmergencyStatus.pending.value,
          'assignedAmbulanceId': FieldValue.delete(),
          'assignedDriverId': FieldValue.delete(),
          'assignedAt': FieldValue.delete(),
          'routeId': FieldValue.delete(),
          'calculatedETA': FieldValue.delete(),
          'routeDistance': FieldValue.delete(),
          'routeDuration': FieldValue.delete(),
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': cancelledBy,
          'cancelledByName': cancelledByName,
          'cancellationReason': cancellationReason,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 2. Update ambulance status
        final ambulanceRef =
            _firestore.collection('ambulances').doc(ambulanceId);
        transaction.update(ambulanceRef, {
          'status': AmbulanceStatus.available.value,
          'currentEmergencyId': FieldValue.delete(),
          'lastCancellationTime': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 3. Mark route as cancelled if exists
        if (route != null && route.status != RouteStatus.completed) {
          final routeRef = _firestore.collection('routes').doc(route.id);
          transaction.update(routeRef, {
            'status': RouteStatus.completed.value,
            'completedAt': FieldValue.serverTimestamp(),
            'completedBy': cancelledBy,
            'completedByName': cancelledByName,
            'completionReason':
                'Route cancelled: ${cancellationReason ?? 'Assignment cancelled'}',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // 4. Create cancellation audit record
        final auditRef = _firestore.collection('audit_trail').doc();
        transaction.set(auditRef, {
          'type': 'assignment_cancellation',
          'emergencyId': emergencyId,
          'ambulanceId': ambulanceId,
          'routeId': route?.id,
          'cancelledBy': cancelledBy,
          'cancelledByName': cancelledByName,
          'cancellationReason': cancellationReason,
          'timestamp': FieldValue.serverTimestamp(),
          'hospitalId': emergency.hospitalId,
        });
      });

      // 5. Send cancellation notifications
      await _sendCancellationNotifications(
        emergency: emergency,
        ambulanceId: ambulanceId,
        route: route,
        cancelledBy: cancelledByName,
        reason: cancellationReason,
      );

      log('Assignment cancellation with cleanup completed');
    } catch (e) {
      log('Error in assignment cancellation: $e');
      throw Exception('Failed to cancel assignment with cleanup: $e');
    }
  }

  /// Send cancellation notifications
  Future<void> _sendCancellationNotifications({
    required EmergencyModel emergency,
    required String ambulanceId,
    required AmbulanceRouteModel? route,
    required String cancelledBy,
    String? reason,
  }) async {
    try {
      // Get ambulance details for driver notification
      final ambulanceDoc =
          await _firestore.collection('ambulances').doc(ambulanceId).get();
      if (!ambulanceDoc.exists) return;

      final ambulance = AmbulanceModel.fromFirestore(ambulanceDoc);

      // Notify driver
      if (ambulance.currentDriverId != null) {
        await _notificationService.sendNotificationToDriver(
          driverId: ambulance.currentDriverId!,
          title: '❌ Assignment Cancelled',
          message:
              'Your emergency assignment has been cancelled. ${reason ?? 'You are now available for new assignments.'}',
          type: 'assignment_cancelled',
          data: {
            'emergencyId': emergency.id,
            'ambulanceId': ambulanceId,
            'routeId': route?.id,
            'cancelledBy': cancelledBy,
            'reason': reason,
          },
        );
      }

      // Notify hospital staff
      if (route != null) {
        await _notificationService.sendRouteNotificationToHospital(
          route: route,
          type: 'assignment_cancelled',
          hospitalId: emergency.hospitalId,
          completionReason:
              'Assignment cancelled: ${reason ?? 'No reason provided'}',
        );
      }
    } catch (e) {
      log('Error sending cancellation notifications: $e');
    }
  }

  // ==========================================================================
  // EMERGENCY STATUS SYNCHRONIZATION
  // ==========================================================================

  /// Synchronize emergency status based on route completion
  Future<void> synchronizeEmergencyWithRouteStatus(String routeId) async {
    try {
      final route = await _routeService.getRoute(routeId);
      if (route == null) return;

      // Only sync if route is completed
      if (route.status != RouteStatus.completed) return;

      final emergencyDoc = await _firestore
          .collection('emergencies')
          .doc(route.emergencyId)
          .get();
      if (!emergencyDoc.exists) return;

      final emergency = EmergencyModel.fromFirestore(emergencyDoc);

      // Only update if emergency is not already completed
      if (emergency.status == EmergencyStatus.completed) return;

      await completeEmergencyWithRouteIntegration(
        emergencyId: route.emergencyId,
        ambulanceId: route.ambulanceId,
        driverId: route.driverId,
        completedBy: route.policeOfficerId ?? 'system',
        completedByName: route.policeOfficerName ?? 'System',
        completionNotes: 'Emergency completed due to route completion',
        routeCompletionReason: route.completionReason,
        isDriverInitiated: route.policeOfficerId == route.driverId,
      );

      log('Emergency synchronized with route completion: ${route.emergencyId}');
    } catch (e) {
      log('Error synchronizing emergency with route status: $e');
    }
  }

  // ==========================================================================
  // ROUTE STATUS MONITORING
  // ==========================================================================

  /// Monitor route status changes and update emergency accordingly
  Stream<void> monitorRouteStatusChanges() {
    return _firestore
        .collection('routes')
        .where('status', isEqualTo: RouteStatus.completed.value)
        .snapshots()
        .asyncMap((snapshot) async {
      for (final doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.modified ||
            doc.type == DocumentChangeType.added) {
          final route = AmbulanceRouteModel.fromFirestore(doc.doc);
          await synchronizeEmergencyWithRouteStatus(route.id);
        }
      }
    });
  }

  // ==========================================================================
  // COMPREHENSIVE EMERGENCY DATA RETRIEVAL
  // ==========================================================================

  /// Get complete emergency information including route and ambulance details
  Future<Map<String, dynamic>?> getCompleteEmergencyInfo(
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
        'driver': null,
      };

      // Get route information
      if (emergency.assignedAmbulanceId != null) {
        try {
          final route = await _routeService.getRouteForEmergency(emergencyId);
          if (route != null) {
            result['route'] = route;
          }
        } catch (e) {
          log('Error getting route for emergency $emergencyId: $e');
        }

        // Get ambulance information
        try {
          final ambulanceDoc = await _firestore
              .collection('ambulances')
              .doc(emergency.assignedAmbulanceId!)
              .get();

          if (ambulanceDoc.exists) {
            result['ambulance'] = AmbulanceModel.fromFirestore(ambulanceDoc);
          }
        } catch (e) {
          log('Error getting ambulance for emergency $emergencyId: $e');
        }

        // Get driver information
        if (emergency.assignedDriverId != null) {
          try {
            final driverDoc = await _firestore
                .collection('users')
                .doc(emergency.assignedDriverId!)
                .get();

            if (driverDoc.exists) {
              result['driver'] = driverDoc.data();
            }
          } catch (e) {
            log('Error getting driver for emergency $emergencyId: $e');
          }
        }
      }

      return result;
    } catch (e) {
      log('Error getting complete emergency info: $e');
      return null;
    }
  }

  // ==========================================================================
  // EMERGENCY METRICS AND ANALYTICS
  // ==========================================================================

  /// Get emergency completion metrics
  Future<Map<String, dynamic>> getEmergencyCompletionMetrics(
      String hospitalId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
      final startOfMonth = DateTime(now.year, now.month, 1);

      // Get completed emergencies for different time periods
      final dailyQuery = await _firestore
          .collection('emergencies')
          .where('hospitalId', isEqualTo: hospitalId)
          .where('status', isEqualTo: EmergencyStatus.completed.value)
          .where('completedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      final weeklyQuery = await _firestore
          .collection('emergencies')
          .where('hospitalId', isEqualTo: hospitalId)
          .where('status', isEqualTo: EmergencyStatus.completed.value)
          .where('completedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
          .get();

      final monthlyQuery = await _firestore
          .collection('emergencies')
          .where('hospitalId', isEqualTo: hospitalId)
          .where('status', isEqualTo: EmergencyStatus.completed.value)
          .where('completedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .get();

      // Calculate metrics
      double totalResponseTime = 0;
      int responseTimeCount = 0;
      int driverInitiatedCompletions = 0;
      int hospitalInitiatedCompletions = 0;

      for (final doc in monthlyQuery.docs) {
        final data = doc.data();

        // Calculate response time if both timestamps exist
        if (data['createdAt'] != null && data['completedAt'] != null) {
          final created = (data['createdAt'] as Timestamp).toDate();
          final completed = (data['completedAt'] as Timestamp).toDate();
          totalResponseTime += completed.difference(created).inMinutes;
          responseTimeCount++;
        }

        // Count completion sources
        final completionSource = data['completionSource'] as String?;
        if (completionSource == 'driver') {
          driverInitiatedCompletions++;
        } else {
          hospitalInitiatedCompletions++;
        }
      }

      final averageResponseTime =
          responseTimeCount > 0 ? totalResponseTime / responseTimeCount : 0.0;

      return {
        'daily': {
          'completed': dailyQuery.docs.length,
        },
        'weekly': {
          'completed': weeklyQuery.docs.length,
        },
        'monthly': {
          'completed': monthlyQuery.docs.length,
          'averageResponseTime': averageResponseTime,
          'driverInitiatedCompletions': driverInitiatedCompletions,
          'hospitalInitiatedCompletions': hospitalInitiatedCompletions,
        },
      };
    } catch (e) {
      log('Error getting emergency completion metrics: $e');
      return {};
    }
  }
}
