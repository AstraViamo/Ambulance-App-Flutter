// lib/services/emergency_service.dart
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../models/ambulance_model.dart';
import '../models/emergency_model.dart';
import '../models/route_model.dart';
import 'notification_service.dart';
import 'route_service.dart';

class EmergencyService {
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final RouteService _routeService = RouteService();

  // Google Places API key - replace with your actual key
  static const String _placesApiKey = 'AIzaSyAnBu-wsGuEBDOlMWZeAio-w5YymCIh19E';

  /// Create a new emergency
  Future<String> createEmergency(EmergencyModel emergency) async {
    try {
      log('Creating emergency for ${emergency.callerName}');

      final docRef = await _firestore.collection('emergencies').add(
            emergency.toFirestore(),
          );

      log('Emergency created with ID: ${docRef.id}');

      // Send notification to hospital staff
      await _notificationService.sendEmergencyNotificationToHospital(
        hospitalId: emergency.hospitalId,
        emergencyId: docRef.id,
        priority: emergency.priority,
        description: emergency.description,
        location: emergency.patientAddressString,
      );

      return docRef.id;
    } catch (e) {
      log('Error creating emergency: $e');
      throw Exception('Failed to create emergency: $e');
    }
  }

  /// Get all emergencies for a hospital
  Stream<List<EmergencyModel>> getEmergenciesForHospital(String hospitalId) {
    return _firestore
        .collection('emergencies')
        .where('hospitalId', isEqualTo: hospitalId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EmergencyModel.fromFirestore(doc))
            .toList());
  }

  /// Get active emergencies for a hospital
  Stream<List<EmergencyModel>> getActiveEmergencies(String hospitalId) {
    return _firestore
        .collection('emergencies')
        .where('hospitalId', isEqualTo: hospitalId)
        .where('status', whereIn: [
          EmergencyStatus.pending.value,
          EmergencyStatus.assigned.value,
          EmergencyStatus.enRoute.value,
          EmergencyStatus.arrived.value,
        ])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EmergencyModel.fromFirestore(doc))
            .toList());
  }

  /// Get emergencies by priority
  Stream<List<EmergencyModel>> getEmergenciesByPriority(
    String hospitalId,
    EmergencyPriority priority,
  ) {
    return _firestore
        .collection('emergencies')
        .where('hospitalId', isEqualTo: hospitalId)
        .where('priority', isEqualTo: priority.value)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EmergencyModel.fromFirestore(doc))
            .toList());
  }

  /// Get emergency statistics for dashboard
  Future<Map<String, int>> getEmergencyStats(String hospitalId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final emergenciesSnapshot = await _firestore
          .collection('emergencies')
          .where('hospitalId', isEqualTo: hospitalId)
          .get();

      final emergencies = emergenciesSnapshot.docs
          .map((doc) => EmergencyModel.fromFirestore(doc))
          .toList();

      int active = 0;
      int pending = 0;
      int critical = 0;
      int high = 0;
      int medium = 0;
      int low = 0;
      int completedToday = 0;
      int totalCompleted = 0;

      for (final emergency in emergencies) {
        // Count by status
        switch (emergency.status) {
          case EmergencyStatus.pending:
            pending++;
            active++;
            break;
          case EmergencyStatus.assigned:
          case EmergencyStatus.enRoute:
          case EmergencyStatus.arrived:
            active++;
            break;
          case EmergencyStatus.completed:
            totalCompleted++;
            // Use actualArrival if available, otherwise updatedAt
            final completionTime =
                emergency.actualArrival ?? emergency.updatedAt;
            if (completionTime.isAfter(today)) {
              completedToday++;
            }
            break;
          case EmergencyStatus.cancelled:
            // Don't count cancelled emergencies in main stats
            break;
        }

        // Count by priority (only for active emergencies)
        if (emergency.status != EmergencyStatus.completed &&
            emergency.status != EmergencyStatus.cancelled) {
          switch (emergency.priority) {
            case EmergencyPriority.critical:
              critical++;
              break;
            case EmergencyPriority.high:
              high++;
              break;
            case EmergencyPriority.medium:
              medium++;
              break;
            case EmergencyPriority.low:
              low++;
              break;
          }
        }
      }

      return {
        'total': emergencies.length,
        'active': active,
        'pending': pending,
        'critical': critical,
        'high': high,
        'medium': medium,
        'low': low,
        'completedToday': completedToday,
        'totalCompleted': totalCompleted,
      };
    } catch (e) {
      log('Error getting emergency stats: $e');
      return {
        'total': 0,
        'active': 0,
        'pending': 0,
        'critical': 0,
        'high': 0,
        'medium': 0,
        'low': 0,
        'completedToday': 0,
        'totalCompleted': 0,
      };
    }
  }

  /// Update emergency
  Future<void> updateEmergency(
    String emergencyId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore.collection('emergencies').doc(emergencyId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      log('Emergency $emergencyId updated successfully');
    } catch (e) {
      log('Error updating emergency: $e');
      throw Exception('Failed to update emergency: $e');
    }
  }

  /// Update emergency status
  Future<void> updateEmergencyStatus({
    required String emergencyId,
    required EmergencyStatus newStatus,
    DateTime? estimatedArrival,
    DateTime? actualArrival,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus.value,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (estimatedArrival != null) {
        updateData['estimatedArrival'] = Timestamp.fromDate(estimatedArrival);
      }

      if (actualArrival != null) {
        updateData['actualArrival'] = Timestamp.fromDate(actualArrival);
      }

      await _firestore
          .collection('emergencies')
          .doc(emergencyId)
          .update(updateData);
      log('Emergency $emergencyId status updated to ${newStatus.value}');
    } catch (e) {
      log('Error updating emergency status: $e');
      throw Exception('Failed to update emergency status: $e');
    }
  }

  /// Complete emergency
  Future<void> completeEmergency(String emergencyId) async {
    try {
      await _firestore.collection('emergencies').doc(emergencyId).update({
        'status': EmergencyStatus.completed.value,
        'actualArrival': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      log('Emergency $emergencyId completed');
    } catch (e) {
      log('Error completing emergency: $e');
      throw Exception('Failed to complete emergency: $e');
    }
  }

  /// Cancel emergency assignment
  Future<void> cancelEmergencyAssignment(String emergencyId) async {
    try {
      await _firestore.collection('emergencies').doc(emergencyId).update({
        'status': EmergencyStatus.pending.value,
        'assignedAmbulanceId': FieldValue.delete(),
        'assignedDriverId': FieldValue.delete(),
        'assignedAt': FieldValue.delete(),
        'estimatedArrival': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      log('Emergency $emergencyId assignment cancelled');
    } catch (e) {
      log('Error cancelling emergency assignment: $e');
      throw Exception('Failed to cancel emergency assignment: $e');
    }
  }

  /// Delete emergency
  Future<void> deleteEmergency(String emergencyId) async {
    try {
      await _firestore.collection('emergencies').doc(emergencyId).delete();
      log('Emergency $emergencyId deleted');
    } catch (e) {
      log('Error deleting emergency: $e');
      throw Exception('Failed to delete emergency: $e');
    }
  }

  /// Find nearest available ambulance
  Future<AmbulanceModel?> findNearestAmbulance({
    required String hospitalId,
    required double patientLat,
    required double patientLng,
  }) async {
    try {
      final ambulancesSnapshot = await _firestore
          .collection('ambulances')
          .where('hospitalId', isEqualTo: hospitalId)
          .where('status', isEqualTo: AmbulanceStatus.available.value)
          .get();

      if (ambulancesSnapshot.docs.isEmpty) {
        return null;
      }

      final ambulances = ambulancesSnapshot.docs
          .map((doc) => AmbulanceModel.fromFirestore(doc))
          .toList();

      // Filter ambulances with valid location data
      final ambulancesWithLocation = ambulances
          .where((ambulance) =>
              ambulance.latitude != null && ambulance.longitude != null)
          .toList();

      if (ambulancesWithLocation.isEmpty) {
        return null;
      }

      // Find the closest ambulance
      AmbulanceModel? nearest;
      double minDistance = double.infinity;

      for (final ambulance in ambulancesWithLocation) {
        final distance = calculateHaversineDistance(
          patientLat,
          patientLng,
          ambulance.latitude!,
          ambulance.longitude!,
        );

        if (distance < minDistance) {
          minDistance = distance;
          nearest = ambulance;
        }
      }

      return nearest;
    } catch (e) {
      log('Error finding nearest ambulance: $e');
      return null;
    }
  }

  /// Assign ambulance to emergency (basic version)
  Future<bool> assignAmbulanceToEmergency({
    required String emergencyId,
    required String ambulanceId,
    required String driverId,
  }) async {
    try {
      final batch = _firestore.batch();

      // Update emergency
      final emergencyRef =
          _firestore.collection('emergencies').doc(emergencyId);
      batch.update(emergencyRef, {
        'status': EmergencyStatus.assigned.value,
        'assignedAmbulanceId': ambulanceId,
        'assignedDriverId': driverId,
        'assignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update ambulance
      final ambulanceRef = _firestore.collection('ambulances').doc(ambulanceId);
      batch.update(ambulanceRef, {
        'status': AmbulanceStatus.onDuty.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      log('Emergency $emergencyId assigned to ambulance $ambulanceId');
      return true;
    } catch (e) {
      log('Error assigning ambulance to emergency: $e');
      return false;
    }
  }

  /// Calculate distance between two points using Haversine formula
  static double calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
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

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Get place suggestions using Google Places API
  Future<List<PlaceSuggestion>> getPlaceSuggestions(String input) async {
    try {
      if (input.isEmpty) return [];

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(input)}'
        '&key=$_placesApiKey'
        '&types=geocode'
        '&components=country:ke', // Kenya only
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          return predictions
              .map((prediction) => PlaceSuggestion.fromJson(prediction))
              .toList();
        }
      }

      return [];
    } catch (e) {
      log('Error getting place suggestions: $e');
      return [];
    }
  }

  /// Get place details from place ID
  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&key=$_placesApiKey'
        '&fields=place_id,name,formatted_address,geometry',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data['result']);
        }
      }

      return null;
    } catch (e) {
      log('Error getting place details: $e');
      return null;
    }
  }

  /// Enhanced emergency completion with route integration
  Future<void> completeEmergencyWithRoute({
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
      log('Starting enhanced emergency completion for $emergencyId');

      // Get emergency and route data
      final emergencyDoc =
          await _firestore.collection('emergencies').doc(emergencyId).get();
      if (!emergencyDoc.exists) {
        throw Exception('Emergency not found');
      }

      final emergency = EmergencyModel.fromFirestore(emergencyDoc);
      final route = await _routeService.getRouteForEmergency(emergencyId);

      await _firestore.runTransaction((transaction) async {
        // 1. Complete the emergency
        final emergencyRef =
            _firestore.collection('emergencies').doc(emergencyId);
        transaction.update(emergencyRef, {
          'status': EmergencyStatus.completed.value,
          'actualArrival': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'completedBy': completedBy,
          'completedByName': completedByName,
          'completionNotes': completionNotes,
        });

        // 2. Update ambulance status to available
        final ambulanceRef =
            _firestore.collection('ambulances').doc(ambulanceId);
        transaction.update(ambulanceRef, {
          'status': AmbulanceStatus.available.value,
          'currentDriverId': driverId,
          'lastCompletedEmergency': emergencyId,
          'lastCompletedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 3. Complete the route if it exists
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

      // 5. Send completion notifications
      await _sendCompletionNotifications(
        emergencyId: emergencyId,
        ambulanceId: ambulanceId,
        driverId: driverId,
        route: route,
        completedBy: completedByName,
        isDriverInitiated: isDriverInitiated,
      );

      log('Enhanced emergency completion successful');
    } catch (e) {
      log('Error in enhanced emergency completion: $e');
      throw Exception(
          'Failed to complete emergency with route integration: $e');
    }
  }

  /// Send completion notifications
  Future<void> _sendCompletionNotifications({
    required String emergencyId,
    required String ambulanceId,
    required String driverId,
    required AmbulanceRouteModel? route,
    required String completedBy,
    required bool isDriverInitiated,
  }) async {
    try {
      // Implementation for sending notifications would go here
      // This is a placeholder for the notification logic
      log('Sending completion notifications for emergency $emergencyId');
    } catch (e) {
      log('Error sending completion notifications: $e');
    }
  }
}
