// lib/providers/ambulance_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ambulance_model.dart';
import '../services/ambulance_service.dart';

// Ambulance service provider
final ambulanceServiceProvider = Provider<AmbulanceService>((ref) {
  return AmbulanceService();
});

// Current hospital ID provider (should be set when user logs in)
final currentHospitalIdProvider = StateProvider<String?>((ref) => null);

// Ambulances list provider for current hospital
final ambulancesProvider = StreamProvider.family<List<AmbulanceModel>, String>(
  (ref, hospitalId) {
    final ambulanceService = ref.watch(ambulanceServiceProvider);
    return ambulanceService.getAmbulancesByHospital(hospitalId);
  },
);

// Available ambulances provider
final availableAmbulancesProvider =
    StreamProvider.family<List<AmbulanceModel>, String>(
  (ref, hospitalId) {
    final ambulanceService = ref.watch(ambulanceServiceProvider);
    return ambulanceService.getAvailableAmbulances(hospitalId);
  },
);

// Ambulances by status provider
final ambulancesByStatusProvider = StreamProvider.family<List<AmbulanceModel>,
    ({String hospitalId, AmbulanceStatus status})>(
  (ref, params) {
    final ambulanceService = ref.watch(ambulanceServiceProvider);
    return ambulanceService.getAmbulancesByStatus(
        params.hospitalId, params.status);
  },
);

// Ambulance statistics provider
final ambulanceStatsProvider = FutureProvider.family<Map<String, int>, String>(
  (ref, hospitalId) async {
    final ambulanceService = ref.watch(ambulanceServiceProvider);
    return ambulanceService.getAmbulanceStats(hospitalId);
  },
);

// Search query provider
final ambulanceSearchQueryProvider = StateProvider<String>((ref) => '');

// Filtered ambulances provider (with search)
final filteredAmbulancesProvider =
    Provider.family<AsyncValue<List<AmbulanceModel>>, String>(
  (ref, hospitalId) {
    final query = ref.watch(ambulanceSearchQueryProvider);
    final ambulancesAsync = ref.watch(ambulancesProvider(hospitalId));

    return ambulancesAsync.when(
      data: (ambulances) {
        if (query.isEmpty) {
          return AsyncValue.data(ambulances);
        }

        final lowercaseQuery = query.toLowerCase();
        final filtered = ambulances.where((ambulance) {
          return ambulance.licensePlate
                  .toLowerCase()
                  .contains(lowercaseQuery) ||
              ambulance.model.toLowerCase().contains(lowercaseQuery);
        }).toList();

        return AsyncValue.data(filtered);
      },
      loading: () => const AsyncValue.loading(),
      error: (error, stack) => AsyncValue.error(error, stack),
    );
  },
);

// Loading state providers for ambulance operations
final ambulanceLoadingProvider = StateProvider<bool>((ref) => false);
final ambulanceErrorProvider = StateProvider<String?>((ref) => null);

// Selected ambulance provider (for editing)
final selectedAmbulanceProvider = StateProvider<AmbulanceModel?>((ref) => null);

// Form validation providers
final ambulanceFormValidProvider = StateProvider<bool>((ref) => false);

// Sort option provider
enum AmbulanceSortOption {
  newest,
  oldest,
  licensePlate,
  model,
  status,
}

final ambulanceSortOptionProvider =
    StateProvider<AmbulanceSortOption>((ref) => AmbulanceSortOption.newest);

// Sorted ambulances provider
final sortedAmbulancesProvider =
    Provider.family<AsyncValue<List<AmbulanceModel>>, String>(
  (ref, hospitalId) {
    final sortOption = ref.watch(ambulanceSortOptionProvider);
    final filteredAmbulances =
        ref.watch(filteredAmbulancesProvider(hospitalId));

    return filteredAmbulances.when(
      data: (ambulances) {
        final sorted = List<AmbulanceModel>.from(ambulances);

        switch (sortOption) {
          case AmbulanceSortOption.newest:
            sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            break;
          case AmbulanceSortOption.oldest:
            sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            break;
          case AmbulanceSortOption.licensePlate:
            sorted.sort((a, b) => a.licensePlate.compareTo(b.licensePlate));
            break;
          case AmbulanceSortOption.model:
            sorted.sort((a, b) => a.model.compareTo(b.model));
            break;
          case AmbulanceSortOption.status:
            sorted.sort((a, b) => a.status.value.compareTo(b.status.value));
            break;
        }

        return AsyncValue.data(sorted);
      },
      loading: () => const AsyncValue.loading(),
      error: (error, stack) => AsyncValue.error(error, stack),
    );
  },
);

// Ambulance action providers for CRUD operations
class AmbulanceActions {
  final AmbulanceService _service;
  final Ref _ref;

  AmbulanceActions(this._service, this._ref);

  Future<String?> createAmbulance(AmbulanceModel ambulance) async {
    try {
      _ref.read(ambulanceLoadingProvider.notifier).state = true;
      _ref.read(ambulanceErrorProvider.notifier).state = null;

      final id = await _service.createAmbulance(ambulance);
      return id;
    } catch (e) {
      _ref.read(ambulanceErrorProvider.notifier).state = e.toString();
      return null;
    } finally {
      _ref.read(ambulanceLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> updateAmbulance(
      String ambulanceId, Map<String, dynamic> updates) async {
    try {
      _ref.read(ambulanceLoadingProvider.notifier).state = true;
      _ref.read(ambulanceErrorProvider.notifier).state = null;

      await _service.updateAmbulance(ambulanceId, updates);
      return true;
    } catch (e) {
      _ref.read(ambulanceErrorProvider.notifier).state = e.toString();
      return false;
    } finally {
      _ref.read(ambulanceLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> deleteAmbulance(String ambulanceId) async {
    try {
      _ref.read(ambulanceLoadingProvider.notifier).state = true;
      _ref.read(ambulanceErrorProvider.notifier).state = null;

      await _service.deleteAmbulance(ambulanceId);
      return true;
    } catch (e) {
      _ref.read(ambulanceErrorProvider.notifier).state = e.toString();
      return false;
    } finally {
      _ref.read(ambulanceLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> assignDriver(String ambulanceId, String driverId) async {
    try {
      _ref.read(ambulanceLoadingProvider.notifier).state = true;
      _ref.read(ambulanceErrorProvider.notifier).state = null;

      await _service.assignDriver(ambulanceId, driverId);
      return true;
    } catch (e) {
      _ref.read(ambulanceErrorProvider.notifier).state = e.toString();
      return false;
    } finally {
      _ref.read(ambulanceLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> removeDriver(String ambulanceId) async {
    try {
      _ref.read(ambulanceLoadingProvider.notifier).state = true;
      _ref.read(ambulanceErrorProvider.notifier).state = null;

      await _service.removeDriver(ambulanceId);
      return true;
    } catch (e) {
      _ref.read(ambulanceErrorProvider.notifier).state = e.toString();
      return false;
    } finally {
      _ref.read(ambulanceLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> updateStatus(String ambulanceId, AmbulanceStatus status) async {
    try {
      _ref.read(ambulanceLoadingProvider.notifier).state = true;
      _ref.read(ambulanceErrorProvider.notifier).state = null;

      await _service.updateStatus(ambulanceId, status);
      return true;
    } catch (e) {
      _ref.read(ambulanceErrorProvider.notifier).state = e.toString();
      return false;
    } finally {
      _ref.read(ambulanceLoadingProvider.notifier).state = false;
    }
  }
}

// Ambulance actions provider
final ambulanceActionsProvider = Provider<AmbulanceActions>((ref) {
  final service = ref.watch(ambulanceServiceProvider);
  return AmbulanceActions(service, ref);
});
