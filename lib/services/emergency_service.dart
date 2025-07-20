import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ambulance_model.dart';
import '../models/emergency_model.dart';
import '../models/route_model.dart';
import 'notification_service.dart';
import 'route_service.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;
final RouteService _routeService = RouteService();
final NotificationService _notificationService = NotificationService();

Future<void> completeEmergencyWithRouteIntegration({
  required String emergencyId,
  required String ambulanceId,
  required String driverId,
  required String completedBy,
  required String completedByName,
  String? completionNotes,
  String? routeCompletionReason,
  required bool isDriverInitiated,
}) async {
  try {
    log('Completing emergency $emergencyId with route integration');

    // Get emergency details first
    final emergencyDoc =
        await _firestore.collection('emergencies').doc(emergencyId).get();
    if (!emergencyDoc.exists) {
      throw Exception('Emergency not found');
    }

    final emergency = EmergencyModel.fromFirestore(emergencyDoc);

    // Get the route associated with this emergency BEFORE the transaction
    AmbulanceRouteModel? route;
    try {
      route = await _routeService.getRouteForEmergency(emergencyId);
    } catch (e) {
      log('Error getting route for emergency: $e');
      // Continue without route if not found
    }

    await _firestore.runTransaction((transaction) async {
      // 1. Update emergency status
      final emergencyRef =
          _firestore.collection('emergencies').doc(emergencyId);
      transaction.update(emergencyRef, {
        'status': EmergencyStatus.completed.value,
        'completedAt': FieldValue.serverTimestamp(),
        'completedBy': completedBy,
        'completedByName': completedByName,
        'updatedAt': FieldValue.serverTimestamp(),
        if (completionNotes != null) 'completionNotes': completionNotes,
        if (routeCompletionReason != null)
          'routeCompletionReason': routeCompletionReason,
      });

      // 2. Update ambulance status to available
      final ambulanceRef = _firestore.collection('ambulances').doc(ambulanceId);
      transaction.update(ambulanceRef, {
        'status': AmbulanceStatus.available.value,
        'currentDriverId': driverId, // Maintain driver assignment
        'lastCompletedEmergency': emergencyId,
        'lastCompletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Complete the route if it exists and isn't already completed
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

      // 4. Create completion audit record
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

    // 5. Send notifications after transaction completes
    // FIX: Use the route variable that was defined above
    await _sendCompletionNotifications(
      emergencyId: emergencyId,
      ambulanceId: ambulanceId,
      driverId: driverId,
      route: route, // This route is now properly defined
      completedBy: completedByName,
      isDriverInitiated: isDriverInitiated,
    );

    log('Emergency and route completion successful');
  } catch (e) {
    log('Error in enhanced emergency completion: $e');
    throw Exception('Failed to complete emergency with route integration: $e');
  }
}

// FIX 2: Ensure the _sendCompletionNotifications method signature is correct
Future<void> _sendCompletionNotifications({
  required String emergencyId,
  required String ambulanceId,
  required String driverId,
  required AmbulanceRouteModel? route, // Make sure this parameter is nullable
  required String completedBy,
  required bool isDriverInitiated,
}) async {
  try {
    // Get emergency details for hospital identification
    final emergencyDoc =
        await _firestore.collection('emergencies').doc(emergencyId).get();
    if (!emergencyDoc.exists) return;

    final emergency = EmergencyModel.fromFirestore(emergencyDoc);

    // Only proceed with route notifications if route exists
    if (route != null) {
      // Notify hospital staff
      await _notificationService.sendRouteNotificationToHospital(
        route: route,
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
    } else {
      log('No route found for emergency $emergencyId, skipping route-specific notifications');
    }
  } catch (e) {
    log('Error sending completion notifications: $e');
    // Don't throw - notifications failing shouldn't fail the completion
  }
}
