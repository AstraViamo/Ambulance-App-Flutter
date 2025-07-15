// lib/services/emergency_service.dart
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../models/ambulance_model.dart';
import '../models/emergency_model.dart';

class EmergencyService {
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Google Places API configuration
  static const String _placesApiKey =
      'AIzaSyAnBu-wsGuEBDOlMWZeAio-w5YymCIh19E'; // Replace with your API key
  static const String _placesBaseUrl =
      'https://maps.googleapis.com/maps/api/place';

  /// Create a new emergency
  Future<String> createEmergency(EmergencyModel emergency) async {
    try {
      final docRef = await _firestore
          .collection('emergencies')
          .add(emergency.toFirestore());

      log('Emergency created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      log('Error creating emergency: $e');
      throw Exception('Failed to create emergency: $e');
    }
  }

  /// Update emergency
  Future<void> updateEmergency(
      String emergencyId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('emergencies')
          .doc(emergencyId)
          .update(updates);

      log('Emergency updated: $emergencyId');
    } catch (e) {
      log('Error updating emergency: $e');
      throw Exception('Failed to update emergency: $e');
    }
  }

  /// Get emergencies for a hospital
  Stream<List<EmergencyModel>> getEmergenciesForHospital(String hospitalId) {
    return _firestore
        .collection('emergencies')
        .where('hospitalId', isEqualTo: hospitalId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return EmergencyModel.fromFirestore(doc);
      }).toList();
    });
  }

  /// Get active emergencies (not completed or cancelled)
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
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return EmergencyModel.fromFirestore(doc);
          }).toList();
        });
  }

  /// Get emergencies by priority
  Stream<List<EmergencyModel>> getEmergenciesByPriority(
      String hospitalId, EmergencyPriority priority) {
    return _firestore
        .collection('emergencies')
        .where('hospitalId', isEqualTo: hospitalId)
        .where('priority', isEqualTo: priority.value)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return EmergencyModel.fromFirestore(doc);
      }).toList();
    });
  }

  /// Get single emergency by ID
  Future<EmergencyModel?> getEmergencyById(String emergencyId) async {
    try {
      final doc =
          await _firestore.collection('emergencies').doc(emergencyId).get();

      if (doc.exists) {
        return EmergencyModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      log('Error getting emergency: $e');
      return null;
    }
  }

  /// Find nearest available ambulance using Haversine formula
  Future<AmbulanceModel?> findNearestAmbulance({
    required String hospitalId,
    required double patientLat,
    required double patientLng,
  }) async {
    try {
      // Get all available ambulances for the hospital
      final querySnapshot = await _firestore
          .collection('ambulances')
          .where('hospitalId', isEqualTo: hospitalId)
          .where('status', isEqualTo: AmbulanceStatus.available.value)
          .where('isActive', isEqualTo: true)
          .where('currentDriverId', isNotEqualTo: null)
          .get();

      if (querySnapshot.docs.isEmpty) {
        log('No available ambulances found');
        return null;
      }

      // Calculate distances and find nearest
      AmbulanceModel? nearestAmbulance;
      double shortestDistance = double.infinity;

      for (final doc in querySnapshot.docs) {
        final ambulance = AmbulanceModel.fromFirestore(doc);

        // Skip ambulances without location data
        if (ambulance.latitude == null || ambulance.longitude == null) {
          continue;
        }

        // Calculate distance using Haversine formula
        final distance = calculateHaversineDistance(
          patientLat,
          patientLng,
          ambulance.latitude!,
          ambulance.longitude!,
        );

        if (distance < shortestDistance) {
          shortestDistance = distance;
          nearestAmbulance = ambulance;
        }
      }

      if (nearestAmbulance != null) {
        log('Nearest ambulance found: ${nearestAmbulance.licensePlate} at ${shortestDistance.toStringAsFixed(2)}km');
      }

      return nearestAmbulance;
    } catch (e) {
      log('Error finding nearest ambulance: $e');
      throw Exception('Failed to find nearest ambulance: $e');
    }
  }

  /// Assign ambulance to emergency
  Future<bool> assignAmbulanceToEmergency({
    required String emergencyId,
    required String ambulanceId,
    required String driverId,
  }) async {
    try {
      final batch = _firestore.batch();

      // Update emergency with assignment details
      final emergencyRef =
          _firestore.collection('emergencies').doc(emergencyId);
      batch.update(emergencyRef, {
        'status': EmergencyStatus.assigned.value,
        'assignedAmbulanceId': ambulanceId,
        'assignedDriverId': driverId,
        'assignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update ambulance status to on-duty
      final ambulanceRef = _firestore.collection('ambulances').doc(ambulanceId);
      batch.update(ambulanceRef, {
        'status': AmbulanceStatus.onDuty.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create assignment notification
      final notificationRef = _firestore.collection('notifications').doc();
      batch.set(notificationRef, {
        'type': 'emergency_assignment',
        'emergencyId': emergencyId,
        'ambulanceId': ambulanceId,
        'driverId': driverId,
        'message': 'New emergency assignment',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      log('Ambulance $ambulanceId assigned to emergency $emergencyId');
      return true;
    } catch (e) {
      log('Error assigning ambulance to emergency: $e');
      throw Exception('Failed to assign ambulance: $e');
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
      final updates = <String, dynamic>{
        'status': newStatus.value,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (estimatedArrival != null) {
        updates['estimatedArrival'] = Timestamp.fromDate(estimatedArrival);
      }

      if (actualArrival != null) {
        updates['actualArrival'] = Timestamp.fromDate(actualArrival);
      }

      await _firestore
          .collection('emergencies')
          .doc(emergencyId)
          .update(updates);

      log('Emergency status updated: $emergencyId -> ${newStatus.value}');
    } catch (e) {
      log('Error updating emergency status: $e');
      throw Exception('Failed to update emergency status: $e');
    }
  }

  /// Complete emergency and free up ambulance
  Future<void> completeEmergency(String emergencyId) async {
    try {
      // Get emergency details first
      final emergencyDoc =
          await _firestore.collection('emergencies').doc(emergencyId).get();

      if (!emergencyDoc.exists) {
        throw Exception('Emergency not found');
      }

      final emergency = EmergencyModel.fromFirestore(emergencyDoc);
      final batch = _firestore.batch();

      // Update emergency status
      final emergencyRef =
          _firestore.collection('emergencies').doc(emergencyId);
      batch.update(emergencyRef, {
        'status': EmergencyStatus.completed.value,
        'actualArrival': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Free up ambulance if assigned
      if (emergency.assignedAmbulanceId != null) {
        final ambulanceRef = _firestore
            .collection('ambulances')
            .doc(emergency.assignedAmbulanceId!);
        batch.update(ambulanceRef, {
          'status': AmbulanceStatus.available.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      log('Emergency completed: $emergencyId');
    } catch (e) {
      log('Error completing emergency: $e');
      throw Exception('Failed to complete emergency: $e');
    }
  }

  /// Calculate distance between two points using Haversine formula
  static double calculateHaversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371.0;

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Google Places Autocomplete
  Future<List<PlaceSuggestion>> getPlaceSuggestions(String input) async {
    if (input.isEmpty) return [];

    try {
      final url = Uri.parse('$_placesBaseUrl/autocomplete/json?'
          'input=${Uri.encodeComponent(input)}&'
          'key=$_placesApiKey&'
          'types=geocode&'
          'components=country:ke' // Restrict to Kenya
          );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          return predictions.map((prediction) {
            return PlaceSuggestion.fromJson(prediction);
          }).toList();
        } else {
          log('Places API error: ${data['status']}');
          return [];
        }
      } else {
        log('HTTP error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      log('Error getting place suggestions: $e');
      return [];
    }
  }

  /// Get place details from place ID
  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse('$_placesBaseUrl/details/json?'
          'place_id=$placeId&'
          'key=$_placesApiKey&'
          'fields=place_id,name,formatted_address,geometry');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data['result']);
        } else {
          log('Place details API error: ${data['status']}');
          return null;
        }
      } else {
        log('HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      log('Error getting place details: $e');
      return null;
    }
  }

  /// Get emergency statistics for hospital
  Future<Map<String, int>> getEmergencyStats(String hospitalId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Get all emergencies for today
      final todayQuery = await _firestore
          .collection('emergencies')
          .where('hospitalId', isEqualTo: hospitalId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      // Get active emergencies
      final activeQuery = await _firestore
          .collection('emergencies')
          .where('hospitalId', isEqualTo: hospitalId)
          .where('status', whereIn: [
        EmergencyStatus.pending.value,
        EmergencyStatus.assigned.value,
        EmergencyStatus.enRoute.value,
        EmergencyStatus.arrived.value,
      ]).get();

      // Count by priority
      int criticalCount = 0;
      int highCount = 0;
      int mediumCount = 0;
      int lowCount = 0;
      int pendingCount = 0;
      int assignedCount = 0;

      for (final doc in activeQuery.docs) {
        final data = doc.data();
        final priority = data['priority'] as String?;
        final status = data['status'] as String?;

        // Count by priority
        switch (priority) {
          case 'critical':
            criticalCount++;
            break;
          case 'high':
            highCount++;
            break;
          case 'medium':
            mediumCount++;
            break;
          case 'low':
            lowCount++;
            break;
        }

        // Count by status
        switch (status) {
          case 'pending':
            pendingCount++;
            break;
          case 'assigned':
          case 'en_route':
          case 'arrived':
            assignedCount++;
            break;
        }
      }

      return {
        'todayTotal': todayQuery.docs.length,
        'activeTotal': activeQuery.docs.length,
        'critical': criticalCount,
        'high': highCount,
        'medium': mediumCount,
        'low': lowCount,
        'pending': pendingCount,
        'assigned': assignedCount,
      };
    } catch (e) {
      log('Error getting emergency stats: $e');
      return {
        'todayTotal': 0,
        'activeTotal': 0,
        'critical': 0,
        'high': 0,
        'medium': 0,
        'low': 0,
        'pending': 0,
        'assigned': 0,
      };
    }
  }

  /// Delete emergency (admin only)
  Future<void> deleteEmergency(String emergencyId) async {
    try {
      await _firestore.collection('emergencies').doc(emergencyId).delete();

      log('Emergency deleted: $emergencyId');
    } catch (e) {
      log('Error deleting emergency: $e');
      throw Exception('Failed to delete emergency: $e');
    }
  }

  /// Cancel emergency assignment and free ambulance
  Future<void> cancelEmergencyAssignment(String emergencyId) async {
    try {
      // Get emergency details first
      final emergencyDoc =
          await _firestore.collection('emergencies').doc(emergencyId).get();

      if (!emergencyDoc.exists) {
        throw Exception('Emergency not found');
      }

      final emergency = EmergencyModel.fromFirestore(emergencyDoc);
      final batch = _firestore.batch();

      // Update emergency status
      final emergencyRef =
          _firestore.collection('emergencies').doc(emergencyId);
      batch.update(emergencyRef, {
        'status': EmergencyStatus.pending.value,
        'assignedAmbulanceId': FieldValue.delete(),
        'assignedDriverId': FieldValue.delete(),
        'assignedAt': FieldValue.delete(),
        'estimatedArrival': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Free up ambulance if assigned
      if (emergency.assignedAmbulanceId != null) {
        final ambulanceRef = _firestore
            .collection('ambulances')
            .doc(emergency.assignedAmbulanceId!);
        batch.update(ambulanceRef, {
          'status': AmbulanceStatus.available.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      log('Emergency assignment cancelled: $emergencyId');
    } catch (e) {
      log('Error cancelling emergency assignment: $e');
      throw Exception('Failed to cancel assignment: $e');
    }
  }

  /// Estimate arrival time based on distance (simple calculation)
  DateTime estimateArrivalTime({
    required double distanceKm,
    double averageSpeedKmh = 50.0, // Average ambulance speed in city
  }) {
    final travelTimeHours = distanceKm / averageSpeedKmh;
    final travelTimeMinutes = (travelTimeHours * 60).ceil();

    return DateTime.now().add(Duration(minutes: travelTimeMinutes));
  }

  /// Search emergencies by caller name or phone
  Future<List<EmergencyModel>> searchEmergencies({
    required String hospitalId,
    required String searchTerm,
  }) async {
    try {
      final searchLower = searchTerm.toLowerCase();

      // Get all emergencies for the hospital (Firestore doesn't support case-insensitive search)
      final querySnapshot = await _firestore
          .collection('emergencies')
          .where('hospitalId', isEqualTo: hospitalId)
          .orderBy('createdAt', descending: true)
          .limit(100) // Limit for performance
          .get();

      // Filter results locally
      final results = <EmergencyModel>[];
      for (final doc in querySnapshot.docs) {
        final emergency = EmergencyModel.fromFirestore(doc);

        if (emergency.callerName.toLowerCase().contains(searchLower) ||
            emergency.callerPhone.contains(searchTerm) ||
            emergency.description.toLowerCase().contains(searchLower)) {
          results.add(emergency);
        }
      }

      return results;
    } catch (e) {
      log('Error searching emergencies: $e');
      return [];
    }
  }
}
