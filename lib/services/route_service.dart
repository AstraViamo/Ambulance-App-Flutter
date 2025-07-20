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
        startAddress: 'Ambulance Location',
        endAddress: emergency.patientAddressString,
        emergencyPriority: emergency.priority.value,
        patientLocation: emergency.patientAddressString,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        estimatedArrival: DateTime.now().add(
          Duration(seconds: directionsData['duration']),
        ),
      );

      // Save route to Firestore
      final docRef =
          await _firestore.collection('routes').add(route.toFirestore());
      final savedRoute = route.copyWith(id: docRef.id);

      // Send notifications to police
      await _notificationService.sendRouteNotificationToPolice(
        route: savedRoute,
        type: 'new_route',
      );

      log('Route created successfully: ${docRef.id}');
      return savedRoute;
    } catch (e) {
      log('Error calculating route: $e');
      return null;
    }
  }

  // HOSPITAL DASHBOARD QUERIES

  /// Get all routes for hospital dashboard (regardless of status)
  /// Hospital should see all routes with their status
  Stream<List<AmbulanceRouteModel>> getHospitalRoutes(String hospitalId) {
    return _firestore
        .collection('routes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AmbulanceRouteModel.fromFirestore(doc))
            .toList());
  }

  /// Get active routes for hospital (not completed yet)
  /// Active routes = active + cleared statuses
  Stream<List<AmbulanceRouteModel>> getHospitalActiveRoutes(String hospitalId) {
    return _firestore
        .collection('routes')
        .where('status', whereIn: ['active', 'cleared'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AmbulanceRouteModel.fromFirestore(doc))
            .toList());
  }

  /// Get completed routes for hospital route history
  Stream<List<AmbulanceRouteModel>> getHospitalRouteHistory(String hospitalId) {
    return _firestore
        .collection('routes')
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AmbulanceRouteModel.fromFirestore(doc))
            .toList());
  }

  // POLICE DASHBOARD QUERIES

  /// Get pending routes for police (routes needing clearance)
  /// Pending routes = active status only
  Stream<List<AmbulanceRouteModel>> getPolicePendingRoutes() {
    return _firestore
        .collection('routes')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AmbulanceRouteModel.fromFirestore(doc))
            .toList());
  }

  /// Get active routes for police (cleared but not completed)
  /// Active routes = cleared status only
  Stream<List<AmbulanceRouteModel>> getPoliceActiveRoutes() {
    return _firestore
        .collection('routes')
        .where('status', isEqualTo: 'cleared')
        .orderBy('clearedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AmbulanceRouteModel.fromFirestore(doc))
            .toList());
  }

  /// Get route history for police (completed routes)
  Stream<List<AmbulanceRouteModel>> getPoliceRouteHistory() {
    return _firestore
        .collection('routes')
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AmbulanceRouteModel.fromFirestore(doc))
            .toList());
  }

  /// Get all routes for police dashboard (active + cleared)
  /// This replaces the old getAllActiveRoutes method
  Stream<List<AmbulanceRouteModel>> getPoliceAllRoutes() {
    return _firestore
        .collection('routes')
        .where('status', whereIn: ['active', 'cleared'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AmbulanceRouteModel.fromFirestore(doc))
            .toList());
  }

  // LEGACY METHODS (for backwards compatibility)

  /// Get active routes for hospital (legacy method)
  /// Updated to return all non-completed routes
  Stream<List<AmbulanceRouteModel>> getActiveRoutes(String hospitalId) {
    return getHospitalActiveRoutes(hospitalId);
  }

  /// Get all active routes (legacy method for police)
  /// Updated to return active + cleared routes
  Stream<List<AmbulanceRouteModel>> getAllActiveRoutes() {
    return getPoliceAllRoutes();
  }

  // ROUTE STATUS MANAGEMENT

  /// Update route status with enhanced validation and tracking
  Future<void> updateRouteStatus({
    required String routeId,
    required RouteStatus newStatus,
    required String policeOfficerId,
    required String policeOfficerName,
    String? notes,
    String? completionReason,
  }) async {
    try {
      log('Updating route $routeId status to ${newStatus.value}');

      // Get current route to validate transition
      final routeDoc = await _firestore.collection('routes').doc(routeId).get();
      if (!routeDoc.exists) {
        throw Exception('Route not found');
      }

      final currentRoute = AmbulanceRouteModel.fromFirestore(routeDoc);

      // Validate status transition
      if (!currentRoute.canTransitionTo(newStatus)) {
        throw Exception(
            'Invalid status transition from ${currentRoute.status.value} to ${newStatus.value}');
      }

      final updateData = <String, dynamic>{
        'status': newStatus.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'policeOfficerId': policeOfficerId,
        'policeOfficerName': policeOfficerName,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'statusNotes': notes,
      };

      // Add specific timestamp fields based on status
      switch (newStatus) {
        case RouteStatus.cleared:
          updateData['clearedAt'] = FieldValue.serverTimestamp();
          break;
        case RouteStatus.completed:
          updateData['completedAt'] = FieldValue.serverTimestamp();
          if (completionReason != null) {
            updateData['completionReason'] = completionReason;
          }
          break;
        default:
          break;
      }

      await _firestore.collection('routes').doc(routeId).update(updateData);

      // Send appropriate notifications
      final updatedRoute = currentRoute.copyWith(
        status: newStatus,
        policeOfficerId: policeOfficerId,
        policeOfficerName: policeOfficerName,
        statusNotes: notes,
      );

      await _sendStatusUpdateNotifications(updatedRoute, newStatus);

      log('Route status updated successfully');
    } catch (e) {
      log('Error updating route status: $e');
      throw Exception('Failed to update route status: $e');
    }
  }

  /// Complete route (usually called by driver/hospital)
  Future<void> completeRoute({
    required String routeId,
    required String completedBy,
    required String completedByName,
    String? completionReason,
    String? notes,
  }) async {
    await updateRouteStatus(
      routeId: routeId,
      newStatus: RouteStatus.completed,
      policeOfficerId: completedBy,
      policeOfficerName: completedByName,
      notes: notes,
      completionReason: completionReason ?? 'Arrived at destination',
    );
  }

  // UTILITY METHODS

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

  /// Get route for specific emergency
  Future<AmbulanceRouteModel?> getRouteForEmergency(String emergencyId) async {
    try {
      final querySnapshot = await _firestore
          .collection('routes')
          .where('emergencyId', isEqualTo: emergencyId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return AmbulanceRouteModel.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      log('Error getting route for emergency: $e');
      return null;
    }
  }

  /// Get routes by status
  Stream<List<AmbulanceRouteModel>> getRoutesByStatus(RouteStatus status) {
    return _firestore
        .collection('routes')
        .where('status', isEqualTo: status.value)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AmbulanceRouteModel.fromFirestore(doc))
            .toList());
  }

  /// Get routes by multiple statuses
  Stream<List<AmbulanceRouteModel>> getRoutesByStatuses(
      List<RouteStatus> statuses) {
    final statusValues = statuses.map((s) => s.value).toList();
    return _firestore
        .collection('routes')
        .where('status', whereIn: statusValues)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AmbulanceRouteModel.fromFirestore(doc))
            .toList());
  }

  // PRIVATE HELPER METHODS

  /// Send notifications based on status update
  Future<void> _sendStatusUpdateNotifications(
    AmbulanceRouteModel route,
    RouteStatus newStatus,
  ) async {
    try {
      switch (newStatus) {
        case RouteStatus.cleared:
          await _notificationService.sendRouteNotificationToHospital(
            route: route,
            type: 'route_cleared',
            hospitalId: route.ambulanceId, // Assuming hospital can be derived
          );
          break;
        case RouteStatus.completed:
          await _notificationService.sendRouteNotificationToHospital(
            route: route,
            type: 'route_completed',
            hospitalId: route.ambulanceId,
          );
          break;
        case RouteStatus.timeout:
          await _notificationService.sendRouteNotificationToHospital(
            route: route,
            type: 'route_timeout',
            hospitalId: route.ambulanceId,
          );
          break;
        default:
          break;
      }
    } catch (e) {
      log('Error sending status update notifications: $e');
      // Don't throw - notifications failing shouldn't fail the status update
    }
  }

  // Add these methods to your RouteService class in lib/services/route_service.dart

  // =============================================================================
  // DRIVER DASHBOARD QUERIES
  // =============================================================================

  /// Get all routes for a specific driver
  Stream<List<AmbulanceRouteModel>> getRoutesByDriver(String driverId) {
    return _firestore
        .collection('routes')
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AmbulanceRouteModel.fromFirestore(doc))
            .toList());
  }

  /// Get current active route for driver
  Stream<AmbulanceRouteModel?> getCurrentRouteForDriver(String driverId) {
    return _firestore
        .collection('routes')
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['active', 'cleared'])
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            return AmbulanceRouteModel.fromFirestore(snapshot.docs.first);
          }
          return null;
        });
  }

  /// Get route history for driver (completed routes only)
  Stream<List<AmbulanceRouteModel>> getDriverRouteHistory(String driverId) {
    return _firestore
        .collection('routes')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AmbulanceRouteModel.fromFirestore(doc))
            .toList());
  }

  /// Get active routes count for driver
  Future<int> getActiveRoutesCountForDriver(String driverId) async {
    try {
      final querySnapshot = await _firestore
          .collection('routes')
          .where('driverId', isEqualTo: driverId)
          .where('status', whereIn: ['active', 'cleared']).get();

      return querySnapshot.docs.length;
    } catch (e) {
      log('Error getting active routes count for driver: $e');
      return 0;
    }
  }

  /// Get driver statistics
  Future<Map<String, dynamic>> getDriverStatistics(String driverId) async {
    try {
      final allRoutes = await _firestore
          .collection('routes')
          .where('driverId', isEqualTo: driverId)
          .get();

      final routes = allRoutes.docs
          .map((doc) => AmbulanceRouteModel.fromFirestore(doc))
          .toList();

      final completedRoutes =
          routes.where((r) => r.status == RouteStatus.completed).length;
      final totalRoutes = routes.length;
      final activeRoutes =
          routes.where((r) => r.status != RouteStatus.completed).length;

      // Calculate average completion time for completed routes
      final completedRoutesList =
          routes.where((r) => r.status == RouteStatus.completed).toList();
      double avgCompletionTime = 0;

      if (completedRoutesList.isNotEmpty) {
        final totalMinutes = completedRoutesList
            .map((r) =>
                r.estimatedArrival?.difference(r.createdAt).inMinutes ?? 0)
            .fold(0, (sum, minutes) => sum + minutes);
        avgCompletionTime = totalMinutes / completedRoutesList.length;
      }

      return {
        'totalRoutes': totalRoutes,
        'completedRoutes': completedRoutes,
        'activeRoutes': activeRoutes,
        'completionRate':
            totalRoutes > 0 ? (completedRoutes / totalRoutes * 100).round() : 0,
        'avgCompletionTimeMinutes': avgCompletionTime.round(),
      };
    } catch (e) {
      log('Error getting driver statistics: $e');
      return {
        'totalRoutes': 0,
        'completedRoutes': 0,
        'activeRoutes': 0,
        'completionRate': 0,
        'avgCompletionTimeMinutes': 0,
      };
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
      final url = '$_directionsBaseUrl?'
          'origin=$originLat,$originLng&'
          'destination=$destLat,$destLng&'
          'key=$_directionsApiKey&'
          'mode=driving&'
          'traffic_model=best_guess&'
          'departure_time=now';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          final polyline = route['overview_polyline']['points'];

          final steps = (leg['steps'] as List).map((step) {
            return RouteStep(
              instruction: _stripHtmlTags(step['html_instructions'] ?? ''),
              distanceMeters: step['distance']['value'].toDouble(),
              durationSeconds: step['duration']['value'],
              startLat: step['start_location']['lat'].toDouble(),
              startLng: step['start_location']['lng'].toDouble(),
              endLat: step['end_location']['lat'].toDouble(),
              endLng: step['end_location']['lng'].toDouble(),
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
}
