// lib/providers/emergency_providers.dart
import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ambulance_model.dart';
import '../models/emergency_model.dart';
import '../services/ambulance_assignment_service.dart';
import '../services/emergency_service.dart';

// Emergency sort options enum
enum EmergencySortOption {
  newest,
  oldest,
  priority,
  status,
}

// Assignment step enumeration for better state tracking
enum AssignmentStep {
  initial,
  searching,
  selecting,
  assigning,
  completing,
  completed,
  failed,
}

final emergencySortOptionProvider =
    StateProvider<EmergencySortOption>((ref) => EmergencySortOption.newest);

// Error state provider for emergency operations
final emergencyErrorProvider = StateProvider<String?>((ref) => null);

// Emergency service provider
final emergencyServiceProvider = Provider<EmergencyService>((ref) {
  return EmergencyService();
});

final placeSuggestionsProvider =
    StateNotifierProvider<PlaceSuggestionsNotifier, List<PlaceSuggestion>>(
  (ref) {
    final emergencyService = ref.watch(emergencyServiceProvider);
    return PlaceSuggestionsNotifier(emergencyService);
  },
);

final emergencyFormProvider =
    StateNotifierProvider<EmergencyFormNotifier, EmergencyFormState>(
  (ref) => EmergencyFormNotifier(),
);

final ambulanceAssignmentServiceProvider =
    Provider<AmbulanceAssignmentService>((ref) {
  return AmbulanceAssignmentService();
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
            // Sort by urgency level (critical = 4, high = 3, medium = 2, low = 1)
            sorted.sort((a, b) =>
                b.priority.urgencyLevel.compareTo(a.priority.urgencyLevel));
            break;
          case EmergencySortOption.status:
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

// Fixed: Complete emergency statistics provider implementation
final emergencyStatsProvider = FutureProvider.family<Map<String, int>, String>(
  (ref, hospitalId) async {
    final emergencyService = ref.watch(emergencyServiceProvider);

    try {
      // Get all emergencies for the hospital
      final emergenciesSnapshot = await FirebaseFirestore.instance
          .collection('emergencies')
          .where('hospitalId', isEqualTo: hospitalId)
          .get();

      final emergencies = emergenciesSnapshot.docs
          .map((doc) => EmergencyModel.fromFirestore(doc))
          .toList();

      // Calculate stats
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      int active = 0;
      int pending = 0;
      int critical = 0;
      int high = 0;
      int medium = 0;
      int low = 0;
      int completedToday = 0;
      int totalCompleted = 0;
      int todayTotal = 0;
      int activeTotal = 0;
      int completed = 0;
      int cancelled = 0;
      int assigned = 0;
      int enRoute = 0;
      int arrived = 0;

      for (final emergency in emergencies) {
        // Count today's emergencies (created today)
        if (emergency.createdAt.isAfter(today) &&
            emergency.createdAt.isBefore(tomorrow)) {
          todayTotal++;
        }

        // Count by status
        switch (emergency.status) {
          case EmergencyStatus.pending:
            pending++;
            activeTotal++;
            break;
          case EmergencyStatus.assigned:
            assigned++;
            activeTotal++;
            break;
          case EmergencyStatus.enRoute:
            enRoute++;
            activeTotal++;
            break;
          case EmergencyStatus.arrived:
            arrived++;
            activeTotal++;
            break;
          case EmergencyStatus.completed:
            completed++;
            totalCompleted++;
            // Count completed today
            if (emergency.actualArrival != null &&
                emergency.actualArrival!.isAfter(today) &&
                emergency.actualArrival!.isBefore(tomorrow)) {
              completedToday++;
            }
            break;
          case EmergencyStatus.cancelled:
            cancelled++;
            break;
        }

        // Count by priority (all emergencies, not just active)
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

      return {
        'todayTotal': todayTotal,
        'activeTotal': activeTotal,
        'pending': pending,
        'critical': critical,

        // Additional detailed stats
        'high': high,
        'medium': medium,
        'low': low,
        'total': emergencies.length,
        'completed': completed,
        'cancelled': cancelled,
        'assigned': assigned,
        'enRoute': enRoute,
        'arrived': arrived,
        'totalCompleted': totalCompleted,
        'completedToday': completedToday,

        // Calculated metrics
        'activePercentage': emergencies.isEmpty
            ? 0
            : ((activeTotal / emergencies.length) * 100).round(),
        'completionRate': emergencies.isEmpty
            ? 0
            : ((totalCompleted / emergencies.length) * 100).round(),
      };
    } catch (e) {
      dev.log('Error getting emergency stats: $e');
      return {
        'todayTotal': 0,
        'activeTotal': 0,
        'pending': 0,
        'critical': 0,
        'high': 0,
        'medium': 0,
        'low': 0,
        'total': 0,
        'completed': 0,
        'cancelled': 0,
        'assigned': 0,
        'enRoute': 0,
        'arrived': 0,
        'totalCompleted': 0,
        'completedToday': 0,
        'activePercentage': 0,
        'completionRate': 0,
      };
    }
  },
);

// Helper function to calculate average response time
Future<int> _calculateAverageResponseTime(String hospitalId) async {
  try {
    final now = DateTime.now();
    final last30Days = now.subtract(const Duration(days: 30));

    final completedEmergencies = await FirebaseFirestore.instance
        .collection('emergencies')
        .where('assignedHospitalId', isEqualTo: hospitalId)
        .where('status', isEqualTo: EmergencyStatus.completed.value)
        .where('completedAt', isGreaterThan: Timestamp.fromDate(last30Days))
        .get();

    if (completedEmergencies.docs.isEmpty) return 0;

    int totalResponseTime = 0;
    int count = 0;

    for (final doc in completedEmergencies.docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final dispatchedAt = (data['dispatchedAt'] as Timestamp?)?.toDate();

      if (createdAt != null && dispatchedAt != null) {
        totalResponseTime += dispatchedAt.difference(createdAt).inMinutes;
        count++;
      }
    }

    return count > 0 ? (totalResponseTime / count).round() : 0;
  } catch (e) {
    return 0;
  }
}

// Emergency search query provider
final emergencySearchQueryProvider = StateProvider<String>((ref) => '');

// Filtered emergencies provider
final filteredEmergenciesProvider =
    StreamProvider.family<List<EmergencyModel>, String>(
  (ref, hospitalId) {
    final emergenciesAsync = ref.watch(emergenciesProvider(hospitalId));
    final searchQuery = ref.watch(emergencySearchQueryProvider);

    return emergenciesAsync.when(
      data: (emergencies) {
        if (searchQuery.isEmpty) {
          return Stream.value(emergencies);
        }

        final filtered = emergencies.where((emergency) {
          final query = searchQuery.toLowerCase();
          return emergency.callerName.toLowerCase().contains(query) ||
              emergency.callerPhone.toLowerCase().contains(query) ||
              emergency.description.toLowerCase().contains(query) ||
              emergency.patientAddressString.toLowerCase().contains(query);
        }).toList();

        return Stream.value(filtered);
      },
      loading: () => Stream.value(<EmergencyModel>[]),
      error: (error, stack) => Stream.value(<EmergencyModel>[]),
    );
  },
);

// Today's emergency stats provider (real-time)
final todayEmergencyStatsProvider =
    StreamProvider.family<Map<String, int>, String>(
  (ref, hospitalId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return FirebaseFirestore.instance
        .collection('emergencies')
        .where('hospitalId', isEqualTo: hospitalId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
        .where('createdAt', isLessThan: Timestamp.fromDate(tomorrow))
        .snapshots()
        .map((snapshot) {
      final emergencies = snapshot.docs
          .map((doc) => EmergencyModel.fromFirestore(doc))
          .toList();

      int active = 0;
      int critical = 0;
      int pending = 0;
      int completed = 0;

      for (final emergency in emergencies) {
        if (emergency.isActive) active++;
        if (emergency.priority == EmergencyPriority.critical) critical++;
        if (emergency.status == EmergencyStatus.pending) pending++;
        if (emergency.status == EmergencyStatus.completed) completed++;
      }

      return {
        'total': emergencies.length,
        'active': active,
        'critical': critical,
        'pending': pending,
        'completed': completed,
      };
    });
  },
);

// Priority distribution provider
final emergencyPriorityDistributionProvider =
    StreamProvider.family<Map<EmergencyPriority, int>, String>(
  (ref, hospitalId) {
    return FirebaseFirestore.instance
        .collection('emergencies')
        .where('hospitalId', isEqualTo: hospitalId)
        .where('status', whereIn: [
          EmergencyStatus.pending.value,
          EmergencyStatus.assigned.value,
          EmergencyStatus.enRoute.value,
          EmergencyStatus.arrived.value,
        ])
        .snapshots()
        .map((snapshot) {
          final emergencies = snapshot.docs
              .map((doc) => EmergencyModel.fromFirestore(doc))
              .toList();

          final distribution = <EmergencyPriority, int>{};

          for (final priority in EmergencyPriority.values) {
            distribution[priority] =
                emergencies.where((e) => e.priority == priority).length;
          }

          return distribution;
        });
  },
);

// Response time analytics provider
final emergencyResponseTimeProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, hospitalId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('emergencies')
          .where('hospitalId', isEqualTo: hospitalId)
          .where('status', isEqualTo: EmergencyStatus.completed.value)
          .where('assignedAt', isNotEqualTo: null)
          .limit(100) // Last 100 completed emergencies
          .get();

      final emergencies = snapshot.docs
          .map((doc) => EmergencyModel.fromFirestore(doc))
          .toList();

      if (emergencies.isEmpty) {
        return {
          'averageResponseTime': 0,
          'averageTotalTime': 0,
          'fastestResponse': 0,
          'slowestResponse': 0,
          'count': 0,
        };
      }

      final responseTimes = emergencies
          .where((e) => e.responseTime != null)
          .map((e) => e.responseTime!.inMinutes)
          .toList();

      final totalTimes = emergencies
          .where((e) => e.totalTime != null)
          .map((e) => e.totalTime!.inMinutes)
          .toList();

      return {
        'averageResponseTime': responseTimes.isEmpty
            ? 0
            : (responseTimes.reduce((a, b) => a + b) / responseTimes.length)
                .round(),
        'averageTotalTime': totalTimes.isEmpty
            ? 0
            : (totalTimes.reduce((a, b) => a + b) / totalTimes.length).round(),
        'fastestResponse': responseTimes.isEmpty
            ? 0
            : responseTimes.reduce((a, b) => a < b ? a : b),
        'slowestResponse': responseTimes.isEmpty
            ? 0
            : responseTimes.reduce((a, b) => a > b ? a : b),
        'count': emergencies.length,
      };
    } catch (e) {
      return {
        'averageResponseTime': 0,
        'averageTotalTime': 0,
        'fastestResponse': 0,
        'slowestResponse': 0,
        'count': 0,
      };
    }
  },
);

// Emergency counts by status provider
final emergencyCountsByStatusProvider =
    StreamProvider.family<Map<EmergencyStatus, int>, String>(
  (ref, hospitalId) {
    final emergenciesAsync = ref.watch(emergenciesProvider(hospitalId));

    return emergenciesAsync.when(
      data: (emergencies) {
        final counts = <EmergencyStatus, int>{};

        for (final status in EmergencyStatus.values) {
          counts[status] = emergencies.where((e) => e.status == status).length;
        }

        return Stream.value(counts);
      },
      loading: () => Stream.value(<EmergencyStatus, int>{}),
      error: (error, stack) => Stream.value(<EmergencyStatus, int>{}),
    );
  },
);

// Emergency counts by priority provider
final emergencyCountsByPriorityProvider =
    StreamProvider.family<Map<EmergencyPriority, int>, String>(
  (ref, hospitalId) {
    final emergenciesAsync = ref.watch(emergenciesProvider(hospitalId));

    return emergenciesAsync.when(
      data: (emergencies) {
        final counts = <EmergencyPriority, int>{};

        for (final priority in EmergencyPriority.values) {
          counts[priority] =
              emergencies.where((e) => e.priority == priority).length;
        }

        return Stream.value(counts);
      },
      loading: () => Stream.value(<EmergencyPriority, int>{}),
      error: (error, stack) => Stream.value(<EmergencyPriority, int>{}),
    );
  },
);

// Recent emergencies provider (last 24 hours)
final recentEmergenciesProvider =
    StreamProvider.family<List<EmergencyModel>, String>(
  (ref, hospitalId) {
    final emergencyService = ref.watch(emergencyServiceProvider);

    final yesterday = DateTime.now().subtract(const Duration(hours: 24));

    return FirebaseFirestore.instance
        .collection('emergencies')
        .where('assignedHospitalId', isEqualTo: hospitalId)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(yesterday))
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EmergencyModel.fromFirestore(doc))
            .toList());
  },
);

class EmergencyFormState {
  final String callerName;
  final String callerPhone;
  final String description;
  final EmergencyPriority priority;
  final PlaceDetails? selectedPlace;

  const EmergencyFormState({
    this.callerName = '',
    this.callerPhone = '',
    this.description = '',
    this.priority = EmergencyPriority.medium,
    this.selectedPlace,
  });

  EmergencyFormState copyWith({
    String? callerName,
    String? callerPhone,
    String? description,
    EmergencyPriority? priority,
    PlaceDetails? selectedPlace,
  }) {
    return EmergencyFormState(
      callerName: callerName ?? this.callerName,
      callerPhone: callerPhone ?? this.callerPhone,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      selectedPlace: selectedPlace ?? this.selectedPlace,
    );
  }
}

class EmergencyFormNotifier extends StateNotifier<EmergencyFormState> {
  EmergencyFormNotifier() : super(const EmergencyFormState());

  void updateCallerName(String name) {
    state = state.copyWith(callerName: name);
  }

  void updateCallerPhone(String phone) {
    state = state.copyWith(callerPhone: phone);
  }

  void updateDescription(String description) {
    state = state.copyWith(description: description);
  }

  void updatePriority(EmergencyPriority priority) {
    state = state.copyWith(priority: priority);
  }

  void updateSelectedPlace(PlaceDetails? place) {
    state = state.copyWith(selectedPlace: place);
  }

  void resetForm() {
    state = const EmergencyFormState();
  }
}

class PlaceSuggestionsNotifier extends StateNotifier<List<PlaceSuggestion>> {
  PlaceSuggestionsNotifier(this._emergencyService) : super([]);

  final EmergencyService _emergencyService;

  Future<void> searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      state = [];
      return;
    }

    try {
      final suggestions = await _emergencyService.searchPlaces(query);
      state = suggestions;
    } catch (e) {
      print('Error searching places: $e');
      state = [];
    }
  }

  void clearSuggestions() {
    state = [];
  }
}

final selectedPlaceProvider = StateProvider<PlaceDetails?>((ref) => null);

// Emergency assignment state
class EmergencyAssignmentState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;
  final bool isAssigned;
  final List<AmbulanceModel>? nearbyAmbulances;
  final AmbulanceModel? selectedAmbulance;
  final double? distance;
  final int? estimatedTime;
  final AssignmentStep currentStep;
  final Map<String, dynamic>? assignmentDetails;
  final DateTime? lastUpdated;

  EmergencyAssignmentState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.isAssigned = false,
    this.nearbyAmbulances,
    this.selectedAmbulance,
    this.distance,
    this.estimatedTime,
    this.currentStep = AssignmentStep.initial,
    this.assignmentDetails,
    this.lastUpdated,
  });

  EmergencyAssignmentState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    bool? isAssigned,
    List<AmbulanceModel>? nearbyAmbulances,
    AmbulanceModel? selectedAmbulance,
    double? distance,
    int? estimatedTime,
    AssignmentStep? currentStep,
    Map<String, dynamic>? assignmentDetails,
    DateTime? lastUpdated,
  }) {
    return EmergencyAssignmentState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
      isAssigned: isAssigned ?? this.isAssigned,
      nearbyAmbulances: nearbyAmbulances ?? this.nearbyAmbulances,
      selectedAmbulance: selectedAmbulance ?? this.selectedAmbulance,
      distance: distance ?? this.distance,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      currentStep: currentStep ?? this.currentStep,
      assignmentDetails: assignmentDetails ?? this.assignmentDetails,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }

  // Helper getters
  bool get hasNearbyAmbulances => nearbyAmbulances?.isNotEmpty ?? false;

  bool get hasSelectedAmbulance => selectedAmbulance != null;

  bool get canAssign => hasSelectedAmbulance && !isLoading && !isAssigned;

  bool get isSearching => isLoading && currentStep == AssignmentStep.searching;

  bool get isAssigning => isLoading && currentStep == AssignmentStep.assigning;

  String? get selectedAmbulanceId => selectedAmbulance?.id;

  String get statusMessage {
    if (error != null) return error!;
    if (isLoading) {
      switch (currentStep) {
        case AssignmentStep.searching:
          return 'Searching for available ambulances...';
        case AssignmentStep.assigning:
          return 'Assigning ambulance and creating route...';
        case AssignmentStep.completing:
          return 'Completing assignment...';
        default:
          return 'Processing...';
      }
    }
    if (isAssigned) return 'Ambulance successfully assigned';
    if (hasNearbyAmbulances)
      return '${nearbyAmbulances!.length} ambulances found nearby';
    return 'Ready to search for ambulances';
  }
}

// Emergency assignment state notifier
class EmergencyAssignmentNotifier
    extends StateNotifier<EmergencyAssignmentState> {
  final AmbulanceAssignmentService _assignmentService;

  EmergencyAssignmentNotifier(this._assignmentService)
      : super(EmergencyAssignmentState());

  /// Clear assignment state (called in initState)
  void clearAssignment() {
    state = EmergencyAssignmentState(
      currentStep: AssignmentStep.initial,
      lastUpdated: null,
    );
  }

  /// Reset to initial state
  void resetState() {
    clearAssignment();
  }

  /// Update current step
  void _updateStep(AssignmentStep step) {
    state = state.copyWith(
      currentStep: step,
      lastUpdated: DateTime.now(),
    );
  }

  /// Set loading state with step
  void _setLoading(bool loading, {AssignmentStep? step}) {
    state = state.copyWith(
      isLoading: loading,
      error: null,
      currentStep: step,
      lastUpdated: DateTime.now(),
    );
  }

  /// Set error state
  void _setError(String error, {AssignmentStep? step}) {
    state = state.copyWith(
      isLoading: false,
      error: error,
      currentStep: step ?? AssignmentStep.failed,
      lastUpdated: DateTime.now(),
    );
  }

  /// Set success state
  void _setSuccess({
    bool? isAssigned,
    AmbulanceModel? selectedAmbulance,
    Map<String, dynamic>? details,
    AssignmentStep? step,
  }) {
    state = state.copyWith(
      isLoading: false,
      isSuccess: true,
      error: null,
      isAssigned: isAssigned ?? state.isAssigned,
      selectedAmbulance: selectedAmbulance ?? state.selectedAmbulance,
      assignmentDetails: details,
      currentStep: step ?? AssignmentStep.completed,
      lastUpdated: DateTime.now(),
    );
  }

  /// Find nearest ambulances for an emergency
  Future<void> findNearestAmbulance({
    required String hospitalId,
    required double patientLat,
    required double patientLng,
  }) async {
    _setLoading(true, step: AssignmentStep.searching);

    try {
      // Get all available ambulances for the hospital
      final ambulancesSnapshot = await FirebaseFirestore.instance
          .collection('ambulances')
          .where('hospitalId', isEqualTo: hospitalId)
          .where('status', isEqualTo: AmbulanceStatus.available.value)
          .where('isActive', isEqualTo: true)
          .get();

      if (ambulancesSnapshot.docs.isEmpty) {
        _setError('No available ambulances found');
        return;
      }

      final ambulances = ambulancesSnapshot.docs
          .map((doc) => AmbulanceModel.fromFirestore(doc))
          .toList();

      // Filter ambulances with valid location data
      final ambulancesWithLocation = ambulances
          .where((ambulance) =>
              ambulance.latitude != null &&
              ambulance.longitude != null &&
              ambulance.currentDriverId != null)
          .toList();

      if (ambulancesWithLocation.isEmpty) {
        _setError('No ambulances with location data and drivers found');
        return;
      }

      // Calculate distances and sort by proximity
      final ambulancesWithDistance = ambulancesWithLocation.map((ambulance) {
        final distance = _calculateHaversineDistance(
          patientLat,
          patientLng,
          ambulance.latitude!,
          ambulance.longitude!,
        );
        return MapEntry(ambulance, distance);
      }).toList();

      // Sort by distance (nearest first)
      ambulancesWithDistance.sort((a, b) => a.value.compareTo(b.value));

      // Get top 5 nearest ambulances
      final nearestAmbulances =
          ambulancesWithDistance.take(5).map((entry) => entry.key).toList();

      // Calculate estimated time for the nearest ambulance
      final nearestDistance = ambulancesWithDistance.first.value;
      final estimatedTime = _calculateEstimatedTime(nearestDistance);

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        nearbyAmbulances: nearestAmbulances,
        selectedAmbulance: nearestAmbulances.first,
        distance: nearestDistance,
        estimatedTime: estimatedTime,
        currentStep: AssignmentStep.selecting,
        assignmentDetails: {
          'searchRadius': nearestDistance,
          'totalFound': ambulances.length,
          'withLocation': ambulancesWithLocation.length,
          'searchTime': DateTime.now().toIso8601String(),
        },
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      _setError('Failed to find ambulances: $e');
    }
  }

  /// Auto-assign the nearest available ambulance
  Future<bool> autoAssignNearestAmbulance({
    required String emergencyId,
    required String hospitalId,
  }) async {
    _setLoading(true, step: AssignmentStep.searching);

    try {
      // Get emergency details
      final emergencyDoc = await FirebaseFirestore.instance
          .collection('emergencies')
          .doc(emergencyId)
          .get();

      if (!emergencyDoc.exists) {
        _setError('Emergency not found');
        return false;
      }

      final emergency = EmergencyModel.fromFirestore(emergencyDoc);
      _updateStep(AssignmentStep.assigning);

      // Find nearest ambulance using the assignment service
      final assignmentResult = await _assignmentService.findNearestAmbulance(
        patientLat: emergency.patientLat,
        patientLon: emergency.patientLng,
        hospitalId: hospitalId,
        priority: emergency.priority,
      );

      if (assignmentResult == null) {
        _setError('No available ambulances found for assignment');
        return false;
      }

      _updateStep(AssignmentStep.completing);

      // Use the enhanced assignment method with route creation
      final success =
          await _assignmentService.assignAmbulanceToEmergencyWithRoute(
        emergencyId: emergencyId,
        ambulanceId: assignmentResult.ambulance.id,
        driverId: assignmentResult.ambulance.currentDriverId!,
        distance: assignmentResult.distance,
        estimatedArrivalTime: assignmentResult.estimatedArrivalTime,
      );

      if (success) {
        _setSuccess(
          isAssigned: true,
          selectedAmbulance: assignmentResult.ambulance,
          step: AssignmentStep.completed,
          details: {
            'assignmentType': 'auto',
            'ambulanceId': assignmentResult.ambulance.id,
            'driverId': assignmentResult.ambulance.currentDriverId,
            'distance': assignmentResult.distance,
            'estimatedTime': assignmentResult.estimatedArrivalTime,
            'assignedAt': DateTime.now().toIso8601String(),
          },
        );

        // Update distance and time
        state = state.copyWith(
          distance: assignmentResult.distance,
          estimatedTime: assignmentResult.estimatedArrivalTime,
        );

        return true;
      } else {
        _setError('Failed to assign ambulance');
        return false;
      }
    } catch (e) {
      _setError('Auto-assignment failed: $e');
      return false;
    }
  }

  /// Manually assign a specific ambulance
  Future<bool> assignAmbulance({
    required String emergencyId,
    required String ambulanceId,
    required String driverId,
  }) async {
    _setLoading(true, step: AssignmentStep.assigning);

    try {
      // Get emergency and ambulance details for distance calculation
      final emergencyDoc = await FirebaseFirestore.instance
          .collection('emergencies')
          .doc(emergencyId)
          .get();

      final ambulanceDoc = await FirebaseFirestore.instance
          .collection('ambulances')
          .doc(ambulanceId)
          .get();

      if (!emergencyDoc.exists || !ambulanceDoc.exists) {
        _setError('Emergency or ambulance not found');
        return false;
      }

      final emergency = EmergencyModel.fromFirestore(emergencyDoc);
      final ambulance = AmbulanceModel.fromFirestore(ambulanceDoc);

      // Validate ambulance availability
      if (ambulance.status != AmbulanceStatus.available) {
        _setError('Ambulance is not available for assignment');
        return false;
      }

      if (ambulance.currentDriverId == null) {
        _setError('Ambulance has no driver assigned');
        return false;
      }

      _updateStep(AssignmentStep.completing);

      // Calculate distance and estimated time
      double distance = 0.0;
      int estimatedTime = 15; // Default 15 minutes

      if (ambulance.latitude != null && ambulance.longitude != null) {
        distance = _calculateHaversineDistance(
          emergency.patientLat,
          emergency.patientLng,
          ambulance.latitude!,
          ambulance.longitude!,
        );
        estimatedTime = _calculateEstimatedTime(distance);
      }

      // Use the enhanced assignment method with route creation
      final success =
          await _assignmentService.assignAmbulanceToEmergencyWithRoute(
        emergencyId: emergencyId,
        ambulanceId: ambulanceId,
        driverId: driverId,
        distance: distance,
        estimatedArrivalTime: estimatedTime,
      );

      if (success) {
        _setSuccess(
          isAssigned: true,
          selectedAmbulance: ambulance,
          step: AssignmentStep.completed,
          details: {
            'assignmentType': 'manual',
            'ambulanceId': ambulanceId,
            'driverId': driverId,
            'distance': distance,
            'estimatedTime': estimatedTime,
            'assignedAt': DateTime.now().toIso8601String(),
          },
        );

        // Update distance and time
        state = state.copyWith(
          distance: distance,
          estimatedTime: estimatedTime,
        );

        return true;
      } else {
        _setError('Failed to assign ambulance');
        return false;
      }
    } catch (e) {
      _setError('Assignment failed: $e');
      return false;
    }
  }

  /// Update selected ambulance
  void selectAmbulance(AmbulanceModel ambulance) {
    if (state.nearbyAmbulances?.contains(ambulance) == true) {
      // Calculate distance for the selected ambulance
      final emergency = state.assignmentDetails;
      if (emergency != null &&
          ambulance.latitude != null &&
          ambulance.longitude != null) {
        // If we have patient coordinates, calculate distance
        // For now, just update the selection
        state = state.copyWith(
          selectedAmbulance: ambulance,
          currentStep: AssignmentStep.selecting,
          lastUpdated: DateTime.now(),
        );
      } else {
        state = state.copyWith(
          selectedAmbulance: ambulance,
          lastUpdated: DateTime.now(),
        );
      }
    }
  }

  /// Cancel assignment with cleanup
  Future<bool> cancelAssignment({
    required String emergencyId,
    required String ambulanceId,
    String? reason,
  }) async {
    _setLoading(true, step: AssignmentStep.completing);

    try {
      await _assignmentService.cancelAssignmentWithRoute(
        emergencyId: emergencyId,
        ambulanceId: ambulanceId,
        reason: reason,
      );

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        isAssigned: false,
        selectedAmbulance: null,
        currentStep: AssignmentStep.initial,
        assignmentDetails: {
          'cancellationReason': reason,
          'cancelledAt': DateTime.now().toIso8601String(),
        },
        lastUpdated: DateTime.now(),
      );

      return true;
    } catch (e) {
      _setError('Failed to cancel assignment: $e');
      return false;
    }
  }

  double _calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // Earth's radius in meters

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c; // Distance in meters
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  int _calculateEstimatedTime(double distanceInMeters) {
    // Assume average speed of 60 km/h for emergency vehicles
    const double averageSpeedKmh = 60.0;
    const double averageSpeedMs = averageSpeedKmh * 1000 / 3600; // m/s

    final double timeInSeconds = distanceInMeters / averageSpeedMs;
    final int timeInMinutes = (timeInSeconds / 60).round();

    // Minimum 2 minutes, maximum 60 minutes
    return timeInMinutes.clamp(2, 60);
  }
}

// Emergency assignment provider
final emergencyAssignmentProvider = StateNotifierProvider<
    EmergencyAssignmentNotifier, EmergencyAssignmentState>(
  (ref) {
    final assignmentService = ref.watch(ambulanceAssignmentServiceProvider);
    return EmergencyAssignmentNotifier(assignmentService);
  },
);

// Available ambulances for a hospital
final availableAmbulancesProvider =
    StreamProvider.family<List<AmbulanceModel>, String>(
  (ref, hospitalId) {
    return FirebaseFirestore.instance
        .collection('ambulances')
        .where('hospitalId', isEqualTo: hospitalId)
        .where('status', isEqualTo: AmbulanceStatus.available.value)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AmbulanceModel.fromFirestore(doc))
            .toList());
  },
);

// Assignment history for an emergency
final emergencyAssignmentHistoryProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, emergencyId) {
    return FirebaseFirestore.instance
        .collection('emergency_assignments')
        .where('emergencyId', isEqualTo: emergencyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  },
);

// Location statistics provider (for maps)
final locationStatsProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, hospitalId) async {
    try {
      // Get active ambulances count
      final ambulancesSnapshot = await FirebaseFirestore.instance
          .collection('ambulances')
          .where('hospitalId', isEqualTo: hospitalId)
          .where('status', whereIn: ['available', 'busy', 'enRoute']).get();

      return {
        'activelyTracked': ambulancesSnapshot.docs.length,
        'totalAmbulances': ambulancesSnapshot.docs.length,
      };
    } catch (e) {
      return {
        'activelyTracked': 0,
        'totalAmbulances': 0,
      };
    }
  },
);

class EmergencyActions {
  final EmergencyService _service;
  final Ref _ref;

  EmergencyActions(this._service, this._ref);

  Future<String?> createEmergency(EmergencyModel emergency) async {
    try {
      final emergencyId = await _service.createEmergency(emergency);
      return emergencyId;
    } catch (e) {
      print('Error creating emergency: $e');
      throw Exception('Failed to create emergency: $e');
    }
  }

  Future<bool> updateEmergency(
      String emergencyId, Map<String, dynamic> updates) async {
    try {
      await _service.updateEmergency(emergencyId, updates);
      return true;
    } catch (e) {
      print('Error updating emergency: $e');
      return false;
    }
  }

  Future<bool> completeEmergency(String emergencyId) async {
    try {
      await _service.completeEmergency(emergencyId);
      return true;
    } catch (e) {
      print('Error completing emergency: $e');
      return false;
    }
  }

  Future<bool> deleteEmergency(String emergencyId) async {
    try {
      await _service.deleteEmergency(emergencyId);
      return true;
    } catch (e) {
      print('Error deleting emergency: $e');
      return false;
    }
  }

  Future<bool> updateEmergencyStatus(
      String emergencyId, EmergencyStatus status) async {
    try {
      await _service.updateEmergencyStatus(
        emergencyId: emergencyId,
        newStatus: status,
      );
      return true;
    } catch (e) {
      print('Error updating emergency status: $e');
      return false;
    }
  }
}

// Emergency actions provider
final emergencyActionsProvider = Provider<EmergencyActions>((ref) {
  final service = ref.watch(emergencyServiceProvider);
  return EmergencyActions(service, ref);
});

extension EmergencySortOptionExtension on EmergencySortOption {
  String get displayName {
    switch (this) {
      case EmergencySortOption.newest:
        return 'Newest First';
      case EmergencySortOption.oldest:
        return 'Oldest First';
      case EmergencySortOption.priority:
        return 'By Priority';
      case EmergencySortOption.status:
        return 'By Status';
    }
  }

  IconData get icon {
    switch (this) {
      case EmergencySortOption.newest:
        return Icons.arrow_downward;
      case EmergencySortOption.oldest:
        return Icons.arrow_upward;
      case EmergencySortOption.priority:
        return Icons.priority_high;
      case EmergencySortOption.status:
        return Icons.list_alt;
    }
  }
}
