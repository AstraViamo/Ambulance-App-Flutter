// lib/providers/emergency_providers.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ambulance_model.dart';
import '../models/emergency_model.dart';
import '../services/emergency_service.dart';

// Emergency service provider
final emergencyServiceProvider = Provider<EmergencyService>((ref) {
  return EmergencyService();
});

// All emergencies for hospital provider
final emergenciesProvider = StreamProvider.family<List<EmergencyModel>, String>(
  (ref, hospitalId) {
    final emergencyService = ref.watch(emergencyServiceProvider);
    return emergencyService.getEmergenciesForHospital(hospitalId);
  },
);

// Active emergencies provider
final activeEmergenciesProvider =
    StreamProvider.family<List<EmergencyModel>, String>(
  (ref, hospitalId) {
    final emergencyService = ref.watch(emergencyServiceProvider);
    return emergencyService.getActiveEmergencies(hospitalId);
  },
);

// Emergencies by priority provider
final emergenciesByPriorityProvider = StreamProvider.family<
    List<EmergencyModel>, ({String hospitalId, EmergencyPriority priority})>(
  (ref, params) {
    final emergencyService = ref.watch(emergencyServiceProvider);
    return emergencyService.getEmergenciesByPriority(
      params.hospitalId,
      params.priority,
    );
  },
);

// Emergency statistics provider
final emergencyStatsProvider = FutureProvider.family<Map<String, int>, String>(
  (ref, hospitalId) async {
    final emergencyService = ref.watch(emergencyServiceProvider);
    return emergencyService.getEmergencyStats(hospitalId);
  },
);

// Emergency search query provider
final emergencySearchQueryProvider = StateProvider<String>((ref) => '');

// Filtered emergencies provider (with search)
final filteredEmergenciesProvider =
    Provider.family<AsyncValue<List<EmergencyModel>>, String>(
  (ref, hospitalId) {
    final query = ref.watch(emergencySearchQueryProvider);
    final emergenciesAsync = ref.watch(emergenciesProvider(hospitalId));

    return emergenciesAsync.when(
      data: (emergencies) {
        if (query.isEmpty) {
          return AsyncValue.data(emergencies);
        }

        final lowercaseQuery = query.toLowerCase();
        final filtered = emergencies.where((emergency) {
          return emergency.callerName.toLowerCase().contains(lowercaseQuery) ||
              emergency.callerPhone.contains(query) ||
              emergency.description.toLowerCase().contains(lowercaseQuery) ||
              emergency.patientAddressString
                  .toLowerCase()
                  .contains(lowercaseQuery);
        }).toList();

        return AsyncValue.data(filtered);
      },
      loading: () => const AsyncValue.loading(),
      error: (error, stack) => AsyncValue.error(error, stack),
    );
  },
);

// Emergency loading state providers
final emergencyLoadingProvider = StateProvider<bool>((ref) => false);
final emergencyErrorProvider = StateProvider<String?>((ref) => null);

// Selected emergency provider (for details/editing)
final selectedEmergencyProvider = StateProvider<EmergencyModel?>((ref) => null);

// Emergency sort option provider
enum EmergencySortOption {
  newest,
  oldest,
  priority,
  status,
  callerName,
}

final emergencySortOptionProvider = StateProvider<EmergencySortOption>(
  (ref) => EmergencySortOption.newest,
);

// Sorted emergencies provider
final sortedEmergenciesProvider =
    Provider.family<AsyncValue<List<EmergencyModel>>, String>(
  (ref, hospitalId) {
    final sortOption = ref.watch(emergencySortOptionProvider);
    final filteredEmergencies =
        ref.watch(filteredEmergenciesProvider(hospitalId));

    return filteredEmergencies.when(
      data: (emergencies) {
        final sorted = List<EmergencyModel>.from(emergencies);

        switch (sortOption) {
          case EmergencySortOption.newest:
            sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            break;
          case EmergencySortOption.oldest:
            sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            break;
          case EmergencySortOption.priority:
            sorted.sort((a, b) =>
                b.priority.urgencyLevel.compareTo(a.priority.urgencyLevel));
            break;
          case EmergencySortOption.status:
            sorted.sort((a, b) => a.status.value.compareTo(b.status.value));
            break;
          case EmergencySortOption.callerName:
            sorted.sort((a, b) => a.callerName.compareTo(b.callerName));
            break;
        }

        return AsyncValue.data(sorted);
      },
      loading: () => const AsyncValue.loading(),
      error: (error, stack) => AsyncValue.error(error, stack),
    );
  },
);

// Google Places providers
final placeSuggestionsProvider =
    StateNotifierProvider<PlaceSuggestionsNotifier, List<PlaceSuggestion>>(
  (ref) => PlaceSuggestionsNotifier(ref.watch(emergencyServiceProvider)),
);

final selectedPlaceProvider = StateProvider<PlaceDetails?>((ref) => null);

// Emergency creation form providers
final emergencyFormProvider =
    StateNotifierProvider<EmergencyFormNotifier, EmergencyFormState>(
  (ref) => EmergencyFormNotifier(),
);

// Emergency assignment provider
final emergencyAssignmentProvider = StateNotifierProvider<
    EmergencyAssignmentNotifier, EmergencyAssignmentState>(
  (ref) => EmergencyAssignmentNotifier(ref.watch(emergencyServiceProvider)),
);

// Place suggestions notifier
class PlaceSuggestionsNotifier extends StateNotifier<List<PlaceSuggestion>> {
  final EmergencyService _emergencyService;
  Timer? _debounceTimer;

  PlaceSuggestionsNotifier(this._emergencyService) : super([]);

  void searchPlaces(String input) {
    _debounceTimer?.cancel();

    if (input.isEmpty) {
      state = [];
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final suggestions = await _emergencyService.getPlaceSuggestions(input);
        state = suggestions;
      } catch (e) {
        state = [];
      }
    });
  }

  void clearSuggestions() {
    state = [];
    _debounceTimer?.cancel();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

// Emergency form state
class EmergencyFormState {
  final String callerName;
  final String callerPhone;
  final String description;
  final EmergencyPriority priority;
  final PlaceDetails? selectedPlace;
  final bool isValid;
  final String? error;

  EmergencyFormState({
    this.callerName = '',
    this.callerPhone = '',
    this.description = '',
    this.priority = EmergencyPriority.medium,
    this.selectedPlace,
    this.isValid = false,
    this.error,
  });

  EmergencyFormState copyWith({
    String? callerName,
    String? callerPhone,
    String? description,
    EmergencyPriority? priority,
    PlaceDetails? selectedPlace,
    bool? isValid,
    String? error,
  }) {
    return EmergencyFormState(
      callerName: callerName ?? this.callerName,
      callerPhone: callerPhone ?? this.callerPhone,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      selectedPlace: selectedPlace ?? this.selectedPlace,
      isValid: isValid ?? this.isValid,
      error: error ?? this.error,
    );
  }
}

// Emergency form notifier
class EmergencyFormNotifier extends StateNotifier<EmergencyFormState> {
  EmergencyFormNotifier() : super(EmergencyFormState());

  void updateCallerName(String name) {
    state = state.copyWith(callerName: name);
    _validateForm();
  }

  void updateCallerPhone(String phone) {
    state = state.copyWith(callerPhone: phone);
    _validateForm();
  }

  void updateDescription(String description) {
    state = state.copyWith(description: description);
    _validateForm();
  }

  void updatePriority(EmergencyPriority priority) {
    state = state.copyWith(priority: priority);
    _validateForm();
  }

  void updateSelectedPlace(PlaceDetails? place) {
    state = state.copyWith(selectedPlace: place);
    _validateForm();
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  void resetForm() {
    state = EmergencyFormState();
  }

  void _validateForm() {
    final isValid = state.callerName.isNotEmpty &&
        state.callerPhone.isNotEmpty &&
        state.description.isNotEmpty &&
        state.selectedPlace != null;

    state = state.copyWith(isValid: isValid);
  }
}

// Emergency assignment state
class EmergencyAssignmentState {
  final bool isLoading;
  final AmbulanceModel? nearestAmbulance;
  final double? distance;
  final String? error;
  final bool isAssigned;

  EmergencyAssignmentState({
    this.isLoading = false,
    this.nearestAmbulance,
    this.distance,
    this.error,
    this.isAssigned = false,
  });

  EmergencyAssignmentState copyWith({
    bool? isLoading,
    AmbulanceModel? nearestAmbulance,
    double? distance,
    String? error,
    bool? isAssigned,
  }) {
    return EmergencyAssignmentState(
      isLoading: isLoading ?? this.isLoading,
      nearestAmbulance: nearestAmbulance ?? this.nearestAmbulance,
      distance: distance ?? this.distance,
      error: error ?? this.error,
      isAssigned: isAssigned ?? this.isAssigned,
    );
  }
}

// Emergency assignment notifier
class EmergencyAssignmentNotifier
    extends StateNotifier<EmergencyAssignmentState> {
  final EmergencyService _emergencyService;

  EmergencyAssignmentNotifier(this._emergencyService)
      : super(EmergencyAssignmentState());

  Future<void> findNearestAmbulance({
    required String hospitalId,
    required double patientLat,
    required double patientLng,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final ambulance = await _emergencyService.findNearestAmbulance(
        hospitalId: hospitalId,
        patientLat: patientLat,
        patientLng: patientLng,
      );

      if (ambulance != null &&
          ambulance.latitude != null &&
          ambulance.longitude != null) {
        // Calculate distance
        final distance = EmergencyService.calculateHaversineDistance(
          patientLat,
          patientLng,
          ambulance.latitude!,
          ambulance.longitude!,
        );

        state = state.copyWith(
          isLoading: false,
          nearestAmbulance: ambulance,
          distance: distance,
          isAssigned: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'No available ambulances found',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> assignAmbulance({
    required String emergencyId,
    required String ambulanceId,
    required String driverId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await _emergencyService.assignAmbulanceToEmergency(
        emergencyId: emergencyId,
        ambulanceId: ambulanceId,
        driverId: driverId,
      );

      state = state.copyWith(
        isLoading: false,
        isAssigned: success,
      );

      return success;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  void clearAssignment() {
    state = EmergencyAssignmentState();
  }
}

// Emergency actions class for CRUD operations
class EmergencyActions {
  final EmergencyService _service;
  final Ref _ref;

  EmergencyActions(this._service, this._ref);

  Future<String?> createEmergency(EmergencyModel emergency) async {
    try {
      _ref.read(emergencyLoadingProvider.notifier).state = true;
      _ref.read(emergencyErrorProvider.notifier).state = null;

      final id = await _service.createEmergency(emergency);
      return id;
    } catch (e) {
      _ref.read(emergencyErrorProvider.notifier).state = e.toString();
      return null;
    } finally {
      _ref.read(emergencyLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> updateEmergency(
      String emergencyId, Map<String, dynamic> updates) async {
    try {
      _ref.read(emergencyLoadingProvider.notifier).state = true;
      _ref.read(emergencyErrorProvider.notifier).state = null;

      await _service.updateEmergency(emergencyId, updates);
      return true;
    } catch (e) {
      _ref.read(emergencyErrorProvider.notifier).state = e.toString();
      return false;
    } finally {
      _ref.read(emergencyLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> updateEmergencyStatus({
    required String emergencyId,
    required EmergencyStatus status,
    DateTime? estimatedArrival,
    DateTime? actualArrival,
  }) async {
    try {
      _ref.read(emergencyLoadingProvider.notifier).state = true;
      _ref.read(emergencyErrorProvider.notifier).state = null;

      await _service.updateEmergencyStatus(
        emergencyId: emergencyId,
        newStatus: status,
        estimatedArrival: estimatedArrival,
        actualArrival: actualArrival,
      );
      return true;
    } catch (e) {
      _ref.read(emergencyErrorProvider.notifier).state = e.toString();
      return false;
    } finally {
      _ref.read(emergencyLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> completeEmergency(String emergencyId) async {
    try {
      _ref.read(emergencyLoadingProvider.notifier).state = true;
      _ref.read(emergencyErrorProvider.notifier).state = null;

      await _service.completeEmergency(emergencyId);
      return true;
    } catch (e) {
      _ref.read(emergencyErrorProvider.notifier).state = e.toString();
      return false;
    } finally {
      _ref.read(emergencyLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> cancelAssignment(String emergencyId) async {
    try {
      _ref.read(emergencyLoadingProvider.notifier).state = true;
      _ref.read(emergencyErrorProvider.notifier).state = null;

      await _service.cancelEmergencyAssignment(emergencyId);
      return true;
    } catch (e) {
      _ref.read(emergencyErrorProvider.notifier).state = e.toString();
      return false;
    } finally {
      _ref.read(emergencyLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> deleteEmergency(String emergencyId) async {
    try {
      _ref.read(emergencyLoadingProvider.notifier).state = true;
      _ref.read(emergencyErrorProvider.notifier).state = null;

      await _service.deleteEmergency(emergencyId);
      return true;
    } catch (e) {
      _ref.read(emergencyErrorProvider.notifier).state = e.toString();
      return false;
    } finally {
      _ref.read(emergencyLoadingProvider.notifier).state = false;
    }
  }
}

// Emergency actions provider
final emergencyActionsProvider = Provider<EmergencyActions>((ref) {
  final service = ref.watch(emergencyServiceProvider);
  return EmergencyActions(service, ref);
});
