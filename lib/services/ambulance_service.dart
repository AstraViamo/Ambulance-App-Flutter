// lib/services/ambulance_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ambulance_model.dart';

class AmbulanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'ambulances';

  // Create new ambulance
  Future<String> createAmbulance(AmbulanceModel ambulance) async {
    try {
      // Check if license plate already exists for this hospital
      final existingAmbulance = await _firestore
          .collection(_collection)
          .where('licensePlate', isEqualTo: ambulance.licensePlate)
          .where('hospitalId', isEqualTo: ambulance.hospitalId)
          .where('isActive', isEqualTo: true)
          .get();

      if (existingAmbulance.docs.isNotEmpty) {
        throw 'An ambulance with license plate "${ambulance.licensePlate}" already exists';
      }

      // Create new ambulance document
      final docRef = await _firestore.collection(_collection).add(
            ambulance.toFirestore(),
          );

      return docRef.id;
    } catch (e) {
      if (e is String) {
        throw e;
      }
      throw 'Failed to create ambulance: ${e.toString()}';
    }
  }

  // Get ambulances by hospital ID
  Stream<List<AmbulanceModel>> getAmbulancesByHospital(String hospitalId) {
    return _firestore
        .collection(_collection)
        .where('hospitalId', isEqualTo: hospitalId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AmbulanceModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get single ambulance by ID
  Future<AmbulanceModel?> getAmbulanceById(String ambulanceId) async {
    try {
      final doc =
          await _firestore.collection(_collection).doc(ambulanceId).get();

      if (doc.exists && doc.data() != null) {
        return AmbulanceModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw 'Failed to fetch ambulance: ${e.toString()}';
    }
  }

  // Update ambulance
  Future<void> updateAmbulance(
      String ambulanceId, Map<String, dynamic> updates) async {
    try {
      // Add updated timestamp
      updates['updatedAt'] = Timestamp.fromDate(DateTime.now());

      // If updating license plate, check for duplicates
      if (updates.containsKey('licensePlate')) {
        final currentAmbulance = await getAmbulanceById(ambulanceId);
        if (currentAmbulance != null) {
          final existingAmbulance = await _firestore
              .collection(_collection)
              .where('licensePlate', isEqualTo: updates['licensePlate'])
              .where('hospitalId', isEqualTo: currentAmbulance.hospitalId)
              .where('isActive', isEqualTo: true)
              .get();

          // Check if any existing ambulance has this license plate (excluding current one)
          final duplicates = existingAmbulance.docs
              .where((doc) => doc.id != ambulanceId)
              .toList();

          if (duplicates.isNotEmpty) {
            throw 'An ambulance with license plate "${updates['licensePlate']}" already exists';
          }
        }
      }

      await _firestore.collection(_collection).doc(ambulanceId).update(updates);
    } catch (e) {
      if (e is String) {
        throw e;
      }
      throw 'Failed to update ambulance: ${e.toString()}';
    }
  }

  // Delete ambulance (soft delete)
  Future<void> deleteAmbulance(String ambulanceId) async {
    try {
      await _firestore.collection(_collection).doc(ambulanceId).update({
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'status': AmbulanceStatus.offline.value,
        'currentDriverId': null, // Remove driver assignment
      });
    } catch (e) {
      throw 'Failed to delete ambulance: ${e.toString()}';
    }
  }

  // Assign driver to ambulance
  Future<void> assignDriver(String ambulanceId, String driverId) async {
    try {
      await updateAmbulance(ambulanceId, {
        'currentDriverId': driverId,
        'status': AmbulanceStatus.available.value,
      });
    } catch (e) {
      throw 'Failed to assign driver: ${e.toString()}';
    }
  }

  // Remove driver from ambulance
  Future<void> removeDriver(String ambulanceId) async {
    try {
      await updateAmbulance(ambulanceId, {
        'currentDriverId': null,
        'status': AmbulanceStatus.offline.value,
      });
    } catch (e) {
      throw 'Failed to remove driver: ${e.toString()}';
    }
  }

  // Update ambulance status
  Future<void> updateStatus(String ambulanceId, AmbulanceStatus status) async {
    try {
      await updateAmbulance(ambulanceId, {
        'status': status.value,
      });
    } catch (e) {
      throw 'Failed to update status: ${e.toString()}';
    }
  }

  // Update ambulance location
  Future<void> updateLocation(
      String ambulanceId, double latitude, double longitude) async {
    try {
      await updateAmbulance(ambulanceId, {
        'latitude': latitude,
        'longitude': longitude,
        'lastLocationUpdate': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw 'Failed to update location: ${e.toString()}';
    }
  }

  // Get available ambulances for hospital
  Stream<List<AmbulanceModel>> getAvailableAmbulances(String hospitalId) {
    return _firestore
        .collection(_collection)
        .where('hospitalId', isEqualTo: hospitalId)
        .where('status', isEqualTo: AmbulanceStatus.available.value)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AmbulanceModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get ambulances by status
  Stream<List<AmbulanceModel>> getAmbulancesByStatus(
      String hospitalId, AmbulanceStatus status) {
    return _firestore
        .collection(_collection)
        .where('hospitalId', isEqualTo: hospitalId)
        .where('status', isEqualTo: status.value)
        .where('isActive', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AmbulanceModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get ambulance statistics for hospital
  Future<Map<String, int>> getAmbulanceStats(String hospitalId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('hospitalId', isEqualTo: hospitalId)
          .where('isActive', isEqualTo: true)
          .get();

      final ambulances = snapshot.docs
          .map((doc) => AmbulanceModel.fromFirestore(doc))
          .toList();

      return {
        'total': ambulances.length,
        'available': ambulances
            .where((a) => a.status == AmbulanceStatus.available)
            .length,
        'onDuty':
            ambulances.where((a) => a.status == AmbulanceStatus.onDuty).length,
        'maintenance': ambulances
            .where((a) => a.status == AmbulanceStatus.maintenance)
            .length,
        'offline':
            ambulances.where((a) => a.status == AmbulanceStatus.offline).length,
        'withDriver': ambulances.where((a) => a.hasDriver).length,
      };
    } catch (e) {
      throw 'Failed to fetch ambulance statistics: ${e.toString()}';
    }
  }

  // Search ambulances by license plate or model
  Stream<List<AmbulanceModel>> searchAmbulances(
      String hospitalId, String query) {
    final lowercaseQuery = query.toLowerCase();

    return getAmbulancesByHospital(hospitalId).map((ambulances) {
      return ambulances.where((ambulance) {
        return ambulance.licensePlate.toLowerCase().contains(lowercaseQuery) ||
            ambulance.model.toLowerCase().contains(lowercaseQuery);
      }).toList();
    });
  }
}
