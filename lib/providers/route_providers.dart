// lib/providers/route_providers.dart
import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/route_model.dart';
import '../services/route_service.dart';

// Route service provider
final routeServiceProvider = Provider<RouteService>((ref) => RouteService());

// Active routes provider (for hospital dashboard)
final activeRoutesProvider =
    StreamProvider.family<List<AmbulanceRouteModel>, String>(
  (ref, hospitalId) {
    final routeService = ref.watch(routeServiceProvider);
    return routeService.getActiveRoutes(hospitalId);
  },
);

// All active routes provider (for police dashboard)
final allActiveRoutesProvider = StreamProvider<List<AmbulanceRouteModel>>(
  (ref) {
    final routeService = ref.watch(routeServiceProvider);
    return routeService.getAllActiveRoutes();
  },
);

// Route by ID provider
final routeByIdProvider = StreamProvider.family<AmbulanceRouteModel?, String>(
  (ref, routeId) {
    final routeService = ref.watch(routeServiceProvider);
    return Stream.fromFuture(routeService.getRoute(routeId));
  },
);

// Route for emergency provider
final routeForEmergencyProvider =
    StreamProvider.family<AmbulanceRouteModel?, String>(
  (ref, emergencyId) {
    final routeService = ref.watch(routeServiceProvider);
    return Stream.fromFuture(routeService.getRouteForEmergency(emergencyId));
  },
);

// Route calculation state
class RouteCalculationState {
  final bool isLoading;
  final AmbulanceRouteModel? route;
  final String? error;

  RouteCalculationState({
    this.isLoading = false,
    this.route,
    this.error,
  });

  RouteCalculationState copyWith({
    bool? isLoading,
    AmbulanceRouteModel? route,
    String? error,
  }) {
    return RouteCalculationState(
      isLoading: isLoading ?? this.isLoading,
      route: route ?? this.route,
      error: error ?? this.error,
    );
  }
}

// Route calculation notifier
class RouteCalculationNotifier extends StateNotifier<RouteCalculationState> {
  final RouteService _routeService;

  RouteCalculationNotifier(this._routeService) : super(RouteCalculationState());

  Future<void> calculateRoute({
    required String ambulanceId,
    required String emergencyId,
    required String driverId,
    required double ambulanceLat,
    required double ambulanceLng,
    required double patientLat,
    required double patientLng,
    required dynamic emergency,
    required dynamic ambulance,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final route = await _routeService.calculateAmbulanceRoute(
        ambulanceId: ambulanceId,
        emergencyId: emergencyId,
        driverId: driverId,
        ambulanceLat: ambulanceLat,
        ambulanceLng: ambulanceLng,
        patientLat: patientLat,
        patientLng: patientLng,
        emergency: emergency,
        ambulance: ambulance,
      );

      state = state.copyWith(isLoading: false, route: route);
    } catch (e) {
      log('Error calculating route: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearRoute() {
    state = RouteCalculationState();
  }
}

// Route calculation provider
final routeCalculationProvider =
    StateNotifierProvider<RouteCalculationNotifier, RouteCalculationState>(
  (ref) => RouteCalculationNotifier(ref.watch(routeServiceProvider)),
);

// Route status update state
class RouteStatusUpdateState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;

  RouteStatusUpdateState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
  });

  RouteStatusUpdateState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? error,
  }) {
    return RouteStatusUpdateState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error ?? this.error,
    );
  }
}

// Route status update notifier
class RouteStatusUpdateNotifier extends StateNotifier<RouteStatusUpdateState> {
  final RouteService _routeService;

  RouteStatusUpdateNotifier(this._routeService)
      : super(RouteStatusUpdateState());

  Future<void> updateRouteStatus({
    required String routeId,
    required RouteStatus newStatus,
    required String policeOfficerId,
    required String policeOfficerName,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      await _routeService.updateRouteStatus(
        routeId: routeId,
        newStatus: newStatus,
        policeOfficerId: policeOfficerId,
        policeOfficerName: policeOfficerName,
        notes: notes,
      );

      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      log('Error updating route status: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() {
    state = RouteStatusUpdateState();
  }
}

// Route status update provider
final routeStatusUpdateProvider =
    StateNotifierProvider<RouteStatusUpdateNotifier, RouteStatusUpdateState>(
  (ref) => RouteStatusUpdateNotifier(ref.watch(routeServiceProvider)),
);

// Filtered routes provider for police dashboard
final filteredRoutesProvider =
    Provider.family<List<AmbulanceRouteModel>, RouteFilter>(
  (ref, filter) {
    final routesAsync = ref.watch(allActiveRoutesProvider);

    return routesAsync.when(
      data: (routes) {
        var filteredRoutes = routes;

        // Filter by status
        if (filter.status != null) {
          filteredRoutes = filteredRoutes
              .where((route) => route.status == filter.status)
              .toList();
        }

        // Filter by priority
        if (filter.priority != null) {
          filteredRoutes = filteredRoutes
              .where((route) => route.emergencyPriority == filter.priority)
              .toList();
        }

        // Filter by search query
        if (filter.searchQuery.isNotEmpty) {
          final query = filter.searchQuery.toLowerCase();
          filteredRoutes = filteredRoutes.where((route) {
            return route.ambulanceLicensePlate.toLowerCase().contains(query) ||
                route.patientLocation.toLowerCase().contains(query) ||
                route.emergencyPriority.toLowerCase().contains(query);
          }).toList();
        }

        // Sort routes
        switch (filter.sortBy) {
          case RouteSortOption.newest:
            filteredRoutes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            break;
          case RouteSortOption.oldest:
            filteredRoutes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            break;
          case RouteSortOption.priority:
            filteredRoutes.sort((a, b) {
              final priorityOrder = {
                'critical': 4,
                'high': 3,
                'medium': 2,
                'low': 1
              };
              return (priorityOrder[b.emergencyPriority] ?? 0)
                  .compareTo(priorityOrder[a.emergencyPriority] ?? 0);
            });
            break;
          case RouteSortOption.eta:
            filteredRoutes.sort((a, b) => a.etaMinutes.compareTo(b.etaMinutes));
            break;
          case RouteSortOption.distance:
            filteredRoutes
                .sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
            break;
        }

        return filteredRoutes;
      },
      loading: () => <AmbulanceRouteModel>[],
      error: (error, stack) => <AmbulanceRouteModel>[],
    );
  },
);

// Route filter state
class RouteFilter {
  final RouteStatus? status;
  final String? priority;
  final String searchQuery;
  final RouteSortOption sortBy;

  RouteFilter({
    this.status,
    this.priority,
    this.searchQuery = '',
    this.sortBy = RouteSortOption.newest,
  });

  RouteFilter copyWith({
    RouteStatus? status,
    String? priority,
    String? searchQuery,
    RouteSortOption? sortBy,
  }) {
    return RouteFilter(
      status: status ?? this.status,
      priority: priority ?? this.priority,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

// Route sort options
enum RouteSortOption {
  newest,
  oldest,
  priority,
  eta,
  distance,
}

// Route filter provider
final routeFilterProvider = StateProvider<RouteFilter>((ref) => RouteFilter());

// Route statistics provider
final routeStatisticsProvider = Provider<Map<String, int>>((ref) {
  final routesAsync = ref.watch(allActiveRoutesProvider);

  return routesAsync.when(
    data: (routes) {
      final stats = <String, int>{
        'total': routes.length,
        'active': routes.where((r) => r.status == RouteStatus.active).length,
        'cleared': routes.where((r) => r.status == RouteStatus.cleared).length,
        'timeout': routes.where((r) => r.status == RouteStatus.timeout).length,
        'critical':
            routes.where((r) => r.emergencyPriority == 'critical').length,
        'high': routes.where((r) => r.emergencyPriority == 'high').length,
      };
      return stats;
    },
    loading: () => <String, int>{},
    error: (error, stack) => <String, int>{},
  );
});
