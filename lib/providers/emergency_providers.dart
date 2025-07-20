// lib/providers/emergency_providers.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ambulance_model.dart';
import '../models/emergency_model.dart';
import '../services/ambulance_assignment_service.dart';
import '../services/emergency_service.dart';

// Emergency service provider
final emergencyServiceProvider = Provider<EmergencyService>((ref) {
  return EmergencyService();
});

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

// Fixed: Complete emergency statistics provider implementation
final emergencyStatsProvider = FutureProvider.family<Map<String, int>, String>(
  (ref, hospitalId) async {
    final emergencyService = ref.watch(emergencyServiceProvider);

    try {
      // Get all emergencies for the hospital
      final emergenciesSnapshot = await FirebaseFirestore.instance
          .collection('emergencies')
          .where('assignedHospitalId', isEqualTo: hospitalId)
          .get();

      final emergencies = emergenciesSnapshot.docs
          .map((doc) => EmergencyModel.fromFirestore(doc))
          .toList();

      // Calculate stats
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

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
            break;
          case EmergencyStatus.assigned:
          case EmergencyStatus.enRoute:
          case EmergencyStatus.arrived:
            active++;
            break;
          case EmergencyStatus.completed:
            totalCompleted++;
            if (emergency.actualArrival != null &&
                emergency.actualArrival!.isAfter(today)) {
              completedToday++;
            }
            break;
          case EmergencyStatus.cancelled:
            // Don't count cancelled emergencies in main stats
            break;
        }

        // Count by priority
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
        'total': emergencies.length,
        'active': active,
        'pending': pending,
        'critical': critical,
        'high': high,
        'medium': medium,
        'low': low,
        'completedToday': completedToday,
        'totalCompleted': totalCompleted,
        'averageResponseTime': await _calculateAverageResponseTime(hospitalId),
      };
    } catch (e) {
      // Return default stats on error
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
        'averageResponseTime': 0,
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

// Emergency assignment state
class EmergencyAssignmentState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  EmergencyAssignmentState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });

  EmergencyAssignmentState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) {
    return EmergencyAssignmentState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

// Emergency assignment state notifier
class EmergencyAssignmentNotifier
    extends StateNotifier<EmergencyAssignmentState> {
  final AmbulanceAssignmentService _assignmentService;

  EmergencyAssignmentNotifier(this._assignmentService)
      : super(EmergencyAssignmentState());

  Future<void> assignAmbulance({
    required String emergencyId,
    required String ambulanceId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get emergency and ambulance details first
      final emergencyDoc = await FirebaseFirestore.instance
          .collection('emergencies')
          .doc(emergencyId)
          .get();

      final ambulanceDoc = await FirebaseFirestore.instance
          .collection('ambulances')
          .doc(ambulanceId)
          .get();

      if (!emergencyDoc.exists || !ambulanceDoc.exists) {
        throw Exception('Emergency or ambulance not found');
      }

      final emergency = EmergencyModel.fromFirestore(emergencyDoc);
      final ambulance = AmbulanceModel.fromFirestore(ambulanceDoc);

      // Calculate distance and estimated arrival time
      double distance = 0.0;
      int estimatedArrivalTime = 15; // Default 15 minutes

      if (ambulance.latitude != null && ambulance.longitude != null) {
        // Calculate actual distance using Haversine formula
        distance = _assignmentService.calculateHaversineDistance(
          lat1: ambulance.latitude!,
          lon1: ambulance.longitude!,
          lat2: emergency.patientLat,
          lon2: emergency.patientLng,
        );

        // Estimate travel time (assuming 60 km/h average speed in emergency)
        estimatedArrivalTime = ((distance / 1000) / 60 * 60).round();

        // Ensure minimum time is 2 minutes
        if (estimatedArrivalTime < 2) estimatedArrivalTime = 2;
      }

      // Now call with all required parameters
      final result = await _assignmentService.assignAmbulanceToEmergency(
        emergencyRequestId:
            emergencyId, // Note: parameter name is emergencyRequestId
        ambulanceId: ambulanceId,
        driverId:
            ambulance.currentDriverId ?? '', // Get driver ID from ambulance
        distance: distance,
        estimatedArrivalTime: estimatedArrivalTime,
      );

      if (result != null) {
        state = state.copyWith(isLoading: false, isSuccess: true);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to assign ambulance',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void resetState() {
    state = EmergencyAssignmentState();
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
