// lib/services/driver_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class DriverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _usersCollection = 'users';
  final String _ambulancesCollection = 'ambulances';

  // Get all drivers for a hospital
  Stream<List<UserModel>> getDriversByHospital(String hospitalId) {
    return _firestore
        .collection(_usersCollection)
        .where('role', isEqualTo: UserRole.ambulanceDriver.value)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((driver) =>
              driver.roleSpecificData.assignedAmbulances?.isNotEmpty == true)
          .toList();
    });
  }

  // Get available drivers (on shift and not assigned to active ambulances)
  Stream<List<UserModel>> getAvailableDrivers(String hospitalId) {
    return _firestore
        .collection(_usersCollection)
        .where('role', isEqualTo: UserRole.ambulanceDriver.value)
        .where('roleSpecificData.isAvailable', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<UserModel> availableDrivers = [];

      for (var doc in snapshot.docs) {
        final driver = UserModel.fromFirestore(doc);

        // Check if driver has any assigned ambulances
        if (driver.roleSpecificData.assignedAmbulances?.isEmpty ?? true) {
          availableDrivers.add(driver);
          continue;
        }

        // Check if any of their assigned ambulances are currently available or offline
        bool hasAvailableAmbulance = false;
        for (String ambulanceId
            in driver.roleSpecificData.assignedAmbulances!) {
          final ambulanceDoc = await _firestore
              .collection(_ambulancesCollection)
              .doc(ambulanceId)
              .get();

          if (ambulanceDoc.exists) {
            final ambulanceData = ambulanceDoc.data()!;
            final status = ambulanceData['status'] as String;

            // Driver is available if they have an ambulance that's not on duty
            if (status == 'available' || status == 'offline') {
              hasAvailableAmbulance = true;
              break;
            }
          }
        }

        if (hasAvailableAmbulance) {
          availableDrivers.add(driver);
        }
      }

      return availableDrivers;
    });
  }

  // Update driver availability (shift in/out)
  Future<void> updateDriverAvailability(
      String driverId, bool isAvailable) async {
    try {
      await _firestore.collection(_usersCollection).doc(driverId).update({
        'roleSpecificData.isAvailable': isAvailable,
        'roleSpecificData.lastAvailabilityUpdate':
            Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw 'Failed to update availability: ${e.toString()}';
    }
  }

  // Assign ambulance to driver
  Future<void> assignAmbulanceToDriver(
      String driverId, String ambulanceId) async {
    try {
      final driverDoc =
          await _firestore.collection(_usersCollection).doc(driverId).get();
      if (!driverDoc.exists) {
        throw 'Driver not found';
      }

      final driverData = driverDoc.data()!;
      final currentAmbulances = List<String>.from(
          driverData['roleSpecificData']['assignedAmbulances'] ?? []);

      if (!currentAmbulances.contains(ambulanceId)) {
        currentAmbulances.add(ambulanceId);

        await _firestore.collection(_usersCollection).doc(driverId).update({
          'roleSpecificData.assignedAmbulances': currentAmbulances,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      // Update ambulance with current driver
      await _firestore
          .collection(_ambulancesCollection)
          .doc(ambulanceId)
          .update({
        'currentDriverId': driverId,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw 'Failed to assign ambulance: ${e.toString()}';
    }
  }

  // Remove ambulance from driver
  Future<void> removeAmbulanceFromDriver(
      String driverId, String ambulanceId) async {
    try {
      final driverDoc =
          await _firestore.collection(_usersCollection).doc(driverId).get();
      if (!driverDoc.exists) {
        throw 'Driver not found';
      }

      final driverData = driverDoc.data()!;
      final currentAmbulances = List<String>.from(
          driverData['roleSpecificData']['assignedAmbulances'] ?? []);

      currentAmbulances.remove(ambulanceId);

      await _firestore.collection(_usersCollection).doc(driverId).update({
        'roleSpecificData.assignedAmbulances': currentAmbulances,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Remove driver from ambulance
      await _firestore
          .collection(_ambulancesCollection)
          .doc(ambulanceId)
          .update({
        'currentDriverId': null,
        'status': 'offline',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw 'Failed to remove ambulance: ${e.toString()}';
    }
  }

  // Get driver by ID
  Future<UserModel?> getDriverById(String driverId) async {
    try {
      final doc =
          await _firestore.collection(_usersCollection).doc(driverId).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw 'Failed to fetch driver: ${e.toString()}';
    }
  }

  // Get driver's assigned ambulances
  Stream<List<Map<String, dynamic>>> getDriverAmbulances(String driverId) {
    return _firestore
        .collection(_usersCollection)
        .doc(driverId)
        .snapshots()
        .asyncMap((driverDoc) async {
      if (!driverDoc.exists) return [];

      final driverData = driverDoc.data()!;
      final assignedAmbulances = List<String>.from(
          driverData['roleSpecificData']['assignedAmbulances'] ?? []);

      if (assignedAmbulances.isEmpty) return [];

      List<Map<String, dynamic>> ambulances = [];

      for (String ambulanceId in assignedAmbulances) {
        final ambulanceDoc = await _firestore
            .collection(_ambulancesCollection)
            .doc(ambulanceId)
            .get();

        if (ambulanceDoc.exists) {
          final data = ambulanceDoc.data()!;
          data['id'] = ambulanceDoc.id;
          ambulances.add(data);
        }
      }

      return ambulances;
    });
  }

  // Switch driver to different ambulance
  Future<void> switchDriverAmbulance(
      String driverId, String fromAmbulanceId, String toAmbulanceId) async {
    try {
      final batch = _firestore.batch();

      // Update previous ambulance
      final fromAmbulanceRef =
          _firestore.collection(_ambulancesCollection).doc(fromAmbulanceId);
      batch.update(fromAmbulanceRef, {
        'currentDriverId': null,
        'status': 'offline',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Update new ambulance
      final toAmbulanceRef =
          _firestore.collection(_ambulancesCollection).doc(toAmbulanceId);
      batch.update(toAmbulanceRef, {
        'currentDriverId': driverId,
        'status': 'available',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      await batch.commit();
    } catch (e) {
      throw 'Failed to switch ambulance: ${e.toString()}';
    }
  }

  // Get driver statistics
  Future<Map<String, dynamic>> getDriverStats(String driverId) async {
    try {
      final driverDoc =
          await _firestore.collection(_usersCollection).doc(driverId).get();
      if (!driverDoc.exists) {
        throw 'Driver not found';
      }

      final driverData = driverDoc.data()!;
      final assignedAmbulances = List<String>.from(
          driverData['roleSpecificData']['assignedAmbulances'] ?? []);

      final isAvailable =
          driverData['roleSpecificData']['isAvailable'] ?? false;

      int totalAmbulances = assignedAmbulances.length;
      int availableAmbulances = 0;
      int onDutyAmbulances = 0;

      for (String ambulanceId in assignedAmbulances) {
        final ambulanceDoc = await _firestore
            .collection(_ambulancesCollection)
            .doc(ambulanceId)
            .get();

        if (ambulanceDoc.exists) {
          final status = ambulanceDoc.data()!['status'] as String;
          if (status == 'available') {
            availableAmbulances++;
          } else if (status == 'on_duty') {
            onDutyAmbulances++;
          }
        }
      }

      return {
        'totalAmbulances': totalAmbulances,
        'availableAmbulances': availableAmbulances,
        'onDutyAmbulances': onDutyAmbulances,
        'isOnShift': isAvailable,
        'lastAvailabilityUpdate': driverData['roleSpecificData']
            ['lastAvailabilityUpdate'],
      };
    } catch (e) {
      throw 'Failed to fetch driver stats: ${e.toString()}';
    }
  }
}
