// lib/providers/driver_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/driver_service.dart';

// Driver service provider
final driverServiceProvider = Provider<DriverService>((ref) {
  return DriverService();
});

// Available drivers provider for hospital
final availableDriversProvider = StreamProvider.family<List<UserModel>, String>(
  (ref, hospitalId) {
    final driverService = ref.watch(driverServiceProvider);
    return driverService.getAvailableDrivers(hospitalId);
  },
);

// All drivers provider for hospital
final allDriversProvider = StreamProvider.family<List<UserModel>, String>(
  (ref, hospitalId) {
    final driverService = ref.watch(driverServiceProvider);
    return driverService.getDriversByHospital(hospitalId);
  },
);

// Current driver ambulances provider
final driverAmbulancesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, driverId) {
    final driverService = ref.watch(driverServiceProvider);
    return driverService.getDriverAmbulances(driverId);
  },
);

// Driver stats provider
final driverStatsProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, driverId) {
    final driverService = ref.watch(driverServiceProvider);
    return driverService.getDriverStats(driverId);
  },
);

// Driver loading state providers
final driverLoadingProvider = StateProvider<bool>((ref) => false);
final driverErrorProvider = StateProvider<String?>((ref) => null);

// Current driver availability provider
final currentDriverAvailabilityProvider = StateProvider<bool>((ref) => false);

// Selected ambulance for switching provider
final selectedAmbulanceForSwitchProvider =
    StateProvider<String?>((ref) => null);

// Driver actions class for operations
class DriverActions {
  final DriverService _service;
  final Ref _ref;

  DriverActions(this._service, this._ref);

  Future<bool> updateAvailability(String driverId, bool isAvailable) async {
    try {
      _ref.read(driverLoadingProvider.notifier).state = true;
      _ref.read(driverErrorProvider.notifier).state = null;

      await _service.updateDriverAvailability(driverId, isAvailable);
      _ref.read(currentDriverAvailabilityProvider.notifier).state = isAvailable;
      return true;
    } catch (e) {
      _ref.read(driverErrorProvider.notifier).state = e.toString();
      return false;
    } finally {
      _ref.read(driverLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> assignAmbulanceToDriver(
      String driverId, String ambulanceId) async {
    try {
      _ref.read(driverLoadingProvider.notifier).state = true;
      _ref.read(driverErrorProvider.notifier).state = null;

      await _service.assignAmbulanceToDriver(driverId, ambulanceId);
      return true;
    } catch (e) {
      _ref.read(driverErrorProvider.notifier).state = e.toString();
      return false;
    } finally {
      _ref.read(driverLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> removeAmbulanceFromDriver(
      String driverId, String ambulanceId) async {
    try {
      _ref.read(driverLoadingProvider.notifier).state = true;
      _ref.read(driverErrorProvider.notifier).state = null;

      await _service.removeAmbulanceFromDriver(driverId, ambulanceId);
      return true;
    } catch (e) {
      _ref.read(driverErrorProvider.notifier).state = e.toString();
      return false;
    } finally {
      _ref.read(driverLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> switchAmbulance(
      String driverId, String fromAmbulanceId, String toAmbulanceId) async {
    try {
      _ref.read(driverLoadingProvider.notifier).state = true;
      _ref.read(driverErrorProvider.notifier).state = null;

      await _service.switchDriverAmbulance(
          driverId, fromAmbulanceId, toAmbulanceId);
      return true;
    } catch (e) {
      _ref.read(driverErrorProvider.notifier).state = e.toString();
      return false;
    } finally {
      _ref.read(driverLoadingProvider.notifier).state = false;
    }
  }

  Future<UserModel?> getDriverById(String driverId) async {
    try {
      return await _service.getDriverById(driverId);
    } catch (e) {
      _ref.read(driverErrorProvider.notifier).state = e.toString();
      return null;
    }
  }
}

// Driver actions provider
final driverActionsProvider = Provider<DriverActions>((ref) {
  final service = ref.watch(driverServiceProvider);
  return DriverActions(service, ref);
});
