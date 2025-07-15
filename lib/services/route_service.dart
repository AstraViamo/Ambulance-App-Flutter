// lib/services/route_service.dart
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../models/ambulance_model.dart';
import '../models/emergency_model.dart';
import '../models/route_model.dart';
import 'notification_service.dart';

class RouteService {
  static final RouteService _instance = RouteService._internal();
  factory RouteService() => _instance;
  RouteService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Google Directions API configuration
  static const String _directionsApiKey =
      'AIzaSyAnBu-wsGuEBDOlMWZeAio-w5YymCIh19E';
  static const String _directionsBaseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Calculate and create ambulance route
  Future<AmbulanceRouteModel?> calculateAmbulanceRoute({
    required String ambulanceId,
    required String emergencyId,
    required String driverId,
    required double ambulanceLat,
    required double ambulanceLng,
    required double patientLat,
    required double patientLng,
    required EmergencyModel emergency,
    required AmbulanceModel ambulance,
  }) async {
    try {
      log('Calculating route for ambulance $ambulanceId to emergency $emergencyId');

      // Call Google Directions API
      final directionsData = await _getDirections(
        originLat: ambulanceLat,
        originLng: ambulanceLng,
        destLat: patientLat,
        destLng: patientLng,
      );

      if (directionsData == null) {
        throw Exception('Could not calculate route');
      }

      // Create route model
      final route = AmbulanceRouteModel(
        id: '', // Will be set by Firestore
        ambulanceId: ambulanceId,
        emergencyId: emergencyId,
        driverId: driverId,
        ambulanceLicensePlate: ambulance.licensePlate,
        status: RouteStatus.active,
        encodedPolyline: directionsData['polyline'],
        steps: directionsData['steps'],
        distanceMeters: directionsData['distance'],
        durationSeconds: directionsData['duration'],
        etaMinutes: (directionsData['duration'] / 60).round(),
        startLat: ambulanceLat,
        startLng: ambulanceLng,
        endLat: patientLat,
        endLng: patientLng,
        startAddress:
            'Ambulance Location', // Could be enhanced with reverse geocoding
        endAddress: emergency.patientAddressString,
        emergencyPriority: emergency.priority.value,
        patientLocation: emergency.patientAddressString,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        estimatedArrival:
            DateTime.now().add(Duration(seconds: directionsData['duration'])),
      );

      // Save route to Firestore
      final routeRef =
          await _firestore.collection('routes').add(route.toFirestore());
      final savedRoute = route.copyWith();

      log('Route calculated and saved with ID: ${routeRef.id}');

      // Notify police if high priority
      if (route.isHighPriority) {
        await _notifyPoliceOfNewRoute(savedRoute);
      }

      return savedRoute;
    } catch (e) {
      log('Error calculating ambulance route: $e');
      throw Exception('Failed to calculate route: $e');
    }
  }

  /// Get directions from Google Directions API
  Future<Map<String, dynamic>?> _getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final url = Uri.parse('$_directionsBaseUrl?'
          'origin=$originLat,$originLng&'
          'destination=$destLat,$destLng&'
          'mode=driving&'
          'traffic_model=best_guess&'
          'departure_time=now&'
          'key=$_directionsApiKey');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          // Extract polyline
          final polyline = route['overview_polyline']['points'];

          // Extract steps
          final steps = (leg['steps'] as List).map((step) {
            final startLocation = step['start_location'];
            final endLocation = step['end_location'];

            return RouteStep(
              instruction: _stripHtmlTags(step['html_instructions']),
              distanceMeters: step['distance']['value'].toDouble(),
              durationSeconds: step['duration']['value'],
              startLat: startLocation['lat'].toDouble(),
              startLng: startLocation['lng'].toDouble(),
              endLat: endLocation['lat'].toDouble(),
              endLng: endLocation['lng'].toDouble(),
              maneuver: step['maneuver'] ?? '',
            );
          }).toList();

          return {
            'polyline': polyline,
            'steps': steps,
            'distance': leg['distance']['value'].toDouble(),
            'duration': leg['duration']['value'],
          };
        } else {
          log('Directions API error: ${data['status']}');
          return null;
        }
      } else {
        log('HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      log('Error getting directions: $e');
      return null;
    }
  }

  /// Strip HTML tags from instruction text
  String _stripHtmlTags(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '');
  }

  /// Get active routes for hospital
  Stream<List<AmbulanceRouteModel>> getActiveRoutes(String hospitalId) {
    return _firestore
        .collection('routes')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AmbulanceRouteModel.fromFirestore(doc))
            .toList());
  }

  /// Get all routes (for police dashboard)
  Stream<List<AmbulanceRouteModel>> getAllActiveRoutes() {
    return _firestore
        .collection('routes')
        .where('status', whereIn: ['active', 'cleared'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AmbulanceRouteModel.fromFirestore(doc))
            .toList());
  }

  /// Update route status (used by police)
  Future<void> updateRouteStatus({
    required String routeId,
    required RouteStatus newStatus,
    required String policeOfficerId,
    required String policeOfficerName,
    String? notes,
  }) async {
    try {
      final batch = _firestore.batch();

      // Update route document
      final routeRef = _firestore.collection('routes').doc(routeId);
      batch.update(routeRef, {
        'status': newStatus.value,
        'policeOfficerId': policeOfficerId,
        'policeOfficerName': policeOfficerName,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (notes != null) 'statusNotes': notes,
      });

      await batch.commit();

      // Get route details for notification
      final routeDoc = await routeRef.get();
      if (routeDoc.exists) {
        final route = AmbulanceRouteModel.fromFirestore(routeDoc);
        await _notifyHospitalOfRouteUpdate(route, newStatus, policeOfficerName);
      }

      log('Route $routeId status updated to ${newStatus.value}');
    } catch (e) {
      log('Error updating route status: $e');
      throw Exception('Failed to update route status: $e');
    }
  }

  /// Complete route when ambulance arrives
  Future<void> completeRoute(String routeId) async {
    try {
      await _firestore.collection('routes').doc(routeId).update({
        'status': RouteStatus.completed.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      log('Route $routeId completed');
    } catch (e) {
      log('Error completing route: $e');
      throw Exception('Failed to complete route: $e');
    }
  }

  /// Notify police of new high-priority route
  Future<void> _notifyPoliceOfNewRoute(AmbulanceRouteModel route) async {
    try {
      // Get all police officers
      final policeQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'police')
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();

      for (final doc in policeQuery.docs) {
        final userId = doc.id;

        // Create notification for each police officer
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'type': 'new_route',
          'title':
              '🚨 New ${route.emergencyPriority.toUpperCase()} Emergency Route',
          'message':
              'Ambulance ${route.ambulanceLicensePlate} dispatched to ${route.patientLocation}. ETA: ${route.formattedETA}',
          'recipientId': userId,
          'routeId': route.id,
          'ambulanceId': route.ambulanceId,
          'emergencyId': route.emergencyId,
          'priority': route.emergencyPriority,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'data': {
            'routeId': route.id,
            'ambulanceLicensePlate': route.ambulanceLicensePlate,
            'eta': route.etaMinutes,
            'emergencyPriority': route.emergencyPriority,
            'patientLocation': route.patientLocation,
          },
        });

        // Send push notification
        await _notificationService.sendPushNotification(
          userId: userId,
          title:
              '🚨 New ${route.emergencyPriority.toUpperCase()} Emergency Route',
          message:
              'Ambulance ${route.ambulanceLicensePlate} dispatched. ETA: ${route.formattedETA}',
          data: {
            'type': 'new_route',
            'routeId': route.id,
            'ambulanceId': route.ambulanceId,
            'emergencyId': route.emergencyId,
          },
        );
      }

      await batch.commit();
      log('Police notified of new route: ${route.id}');
    } catch (e) {
      log('Error notifying police of new route: $e');
    }
  }

  /// Notify hospital of route status update
  Future<void> _notifyHospitalOfRouteUpdate(
    AmbulanceRouteModel route,
    RouteStatus newStatus,
    String policeOfficerName,
  ) async {
    try {
      // Get emergency details to find hospital
      final emergencyDoc = await _firestore
          .collection('emergencies')
          .doc(route.emergencyId)
          .get();

      if (!emergencyDoc.exists) return;

      final emergency = EmergencyModel.fromFirestore(emergencyDoc);

      // Get hospital admin users
      final hospitalQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'hospital_admin')
          .where('roleSpecificData.hospitalId', isEqualTo: emergency.hospitalId)
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();

      String notificationMessage;
      switch (newStatus) {
        case RouteStatus.cleared:
          notificationMessage =
              '✅ Route for Ambulance ${route.ambulanceLicensePlate} has been cleared by Officer $policeOfficerName';
          break;
        case RouteStatus.timeout:
          notificationMessage =
              '⏰ Route for Ambulance ${route.ambulanceLicensePlate} marked as timeout by Officer $policeOfficerName';
          break;
        default:
          notificationMessage =
              'Route for Ambulance ${route.ambulanceLicensePlate} updated by Officer $policeOfficerName';
      }

      for (final doc in hospitalQuery.docs) {
        final userId = doc.id;

        // Create notification
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'type': 'route_update',
          'title': 'Route Status Update',
          'message': notificationMessage,
          'recipientId': userId,
          'routeId': route.id,
          'ambulanceId': route.ambulanceId,
          'emergencyId': route.emergencyId,
          'policeOfficerId': route.policeOfficerId,
          'policeOfficerName': policeOfficerName,
          'newStatus': newStatus.value,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'data': {
            'routeId': route.id,
            'ambulanceLicensePlate': route.ambulanceLicensePlate,
            'newStatus': newStatus.value,
            'policeOfficerName': policeOfficerName,
          },
        });

        // Send push notification
        await _notificationService.sendPushNotification(
          userId: userId,
          title: 'Route Status Update',
          message: notificationMessage,
          data: {
            'type': 'route_update',
            'routeId': route.id,
            'ambulanceId': route.ambulanceId,
            'emergencyId': route.emergencyId,
            'newStatus': newStatus.value,
          },
        );
      }

      await batch.commit();
      log('Hospital notified of route update: ${route.id}');
    } catch (e) {
      log('Error notifying hospital of route update: $e');
    }
  }

  /// Get route by ID
  Future<AmbulanceRouteModel?> getRoute(String routeId) async {
    try {
      final doc = await _firestore.collection('routes').doc(routeId).get();
      if (doc.exists) {
        return AmbulanceRouteModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      log('Error getting route: $e');
      return null;
    }
  }

  /// Get route for emergency
  Future<AmbulanceRouteModel?> getRouteForEmergency(String emergencyId) async {
    try {
      final query = await _firestore
          .collection('routes')
          .where('emergencyId', isEqualTo: emergencyId)
          .where('status', whereIn: ['active', 'cleared'])
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return AmbulanceRouteModel.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      log('Error getting route for emergency: $e');
      return null;
    }
  }
}
