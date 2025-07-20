// lib/providers/route_providers.dart
import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/route_model.dart';
import '../services/route_service.dart';

// Route service provider
final routeServiceProvider = Provider<RouteService>((ref) => RouteService());

// =============================================================================
// HOSPITAL DASHBOARD PROVIDERS
// =============================================================================

/// All routes for hospital dashboard (shows all routes with their status)
final hospitalRoutesProvider =
    StreamProvider.family<List<AmbulanceRouteModel>, String>(
  (ref, hospitalId) {
    final routeService = ref.watch(routeServiceProvider);
    return routeService.getHospitalRoutes(hospitalId);
  },
);

/// Active routes for hospital (not completed yet - active + cleared)
final hospitalActiveRoutesProvider =
    StreamProvider.family<List<AmbulanceRouteModel>, String>(
  (ref, hospitalId) {
    final routeService = ref.watch(routeServiceProvider);
    return routeService.getHospitalActiveRoutes(hospitalId);
  },
);

/// Route history for hospital (completed routes)
final hospitalRouteHistoryProvider =
    StreamProvider.family<List<AmbulanceRouteModel>, String>(
  (ref, hospitalId) {
    final routeService = ref.watch(routeServiceProvider);
    return routeService.getHospitalRouteHistory(hospitalId);
  },
);

// =============================================================================
// POLICE DASHBOARD PROVIDERS
// =============================================================================

/// Pending routes for police (routes needing clearance - active status)
final policePendingRoutesProvider = StreamProvider<List<AmbulanceRouteModel>>(
  (ref) {
    final routeService = ref.watch(routeServiceProvider);
    return routeService.getPolicePendingRoutes();
  },
);

/// Active routes for police (cleared but not completed - cleared status)
final policeActiveRoutesProvider = StreamProvider<List<AmbulanceRouteModel>>(
  (ref) {
    final routeService = ref.watch(routeServiceProvider);
    return routeService.getPoliceActiveRoutes();
  },
);

/// Route history for police (completed routes)
final policeRouteHistoryProvider = StreamProvider<List<AmbulanceRouteModel>>(
  (ref) {
    final routeService = ref.watch(routeServiceProvider);
    return routeService.getPoliceRouteHistory();
  },
);

/// All routes for police dashboard (active + cleared for map view)
final policeAllRoutesProvider = StreamProvider<List<AmbulanceRouteModel>>(
  (ref) {
    final routeService = ref.watch(routeServiceProvider);
    return routeService.getPoliceAllRoutes();
  },
);

// =============================================================================
// LEGACY PROVIDERS (for backwards compatibility)
// =============================================================================

/// Legacy active routes provider (redirects to hospital active routes)
final activeRoutesProvider =
    StreamProvider.family<List<AmbulanceRouteModel>, String>(
  (ref, hospitalId) {
    return ref.watch(hospitalActiveRoutesProvider(hospitalId).stream);
  },
);

/// Legacy all active routes provider (redirects to police all routes)
final allActiveRoutesProvider = StreamProvider<List<AmbulanceRouteModel>>(
  (ref) {
    return ref.watch(policeAllRoutesProvider.stream);
  },
);

// =============================================================================
// UTILITY PROVIDERS
// =============================================================================

/// Route by ID provider
final routeByIdProvider = StreamProvider.family<AmbulanceRouteModel?, String>(
  (ref, routeId) {
    final routeService = ref.watch(routeServiceProvider);
    return Stream.fromFuture(routeService.getRoute(routeId));
  },
);

/// Route for emergency provider
final routeForEmergencyProvider =
    StreamProvider.family<AmbulanceRouteModel?, String>(
  (ref, emergencyId) {
    final routeService = ref.watch(routeServiceProvider);
    return Stream.fromFuture(routeService.getRouteForEmergency(emergencyId));
  },
);

/// Routes by status provider
final routesByStatusProvider =
    StreamProvider.family<List<AmbulanceRouteModel>, RouteStatus>(
  (ref, status) {
    final routeService = ref.watch(routeServiceProvider);
    return routeService.getRoutesByStatus(status);
  },
);

/// Routes by multiple statuses provider
final routesByStatusesProvider =
    StreamProvider.family<List<AmbulanceRouteModel>, List<RouteStatus>>(
  (ref, statuses) {
    final routeService = ref.watch(routeServiceProvider);
    return routeService.getRoutesByStatuses(statuses);
  },
);

// =============================================================================
// DRIVER DASHBOARD PROVIDERS
// =============================================================================

/// Routes for a specific driver
final routesByDriverProvider =
    StreamProvider.family<List<AmbulanceRouteModel>, String>(
  (ref, driverId) {
    final routeService = ref.watch(routeServiceProvider);
    return routeService.getRoutesByDriver(driverId);
  },
);

/// Current active route for driver
final currentRouteForDriverProvider =
    StreamProvider.family<AmbulanceRouteModel?, String>(
  (ref, driverId) {
    final routeService = ref.watch(routeServiceProvider);
    return routeService.getCurrentRouteForDriver(driverId);
  },
);

/// Route history for driver (completed routes)
final driverRouteHistoryProvider =
    StreamProvider.family<List<AmbulanceRouteModel>, String>(
  (ref, driverId) {
    final routeService = ref.watch(routeServiceProvider);
    return routeService.getDriverRouteHistory(driverId);
  },
);

// =============================================================================
// FILTERING AND SORTING
// =============================================================================

/// Dashboard type enum for filtering
enum DashboardType {
  hospital,
  police,
}

/// Route view type for dashboards
enum RouteViewType {
  // Hospital views
  hospitalAll, // All routes regardless of status
  hospitalActive, // Active routes (active + cleared)
  hospitalHistory, // Completed routes

  // Police views
  policePending, // Routes needing clearance (active)
  policeActive, // Routes cleared but not completed (cleared)
  policeHistory, // Completed routes
  policeAll, // All police routes (active + cleared)
}

/// Enhanced route filter state
class RouteFilter {
  final RouteStatus? status;
  final String? priority;
  final String searchQuery;
  final RouteSortOption sortBy;
  final DashboardType? dashboardType;
  final RouteViewType? viewType;
  final String? policeOfficerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  RouteFilter({
    this.status,
    this.priority,
    this.searchQuery = '',
    this.sortBy = RouteSortOption.newest,
    this.dashboardType,
    this.viewType,
    this.policeOfficerId,
    this.dateFrom,
    this.dateTo,
  });

  RouteFilter copyWith({
    RouteStatus? status,
    String? priority,
    String? searchQuery,
    RouteSortOption? sortBy,
    DashboardType? dashboardType,
    RouteViewType? viewType,
    String? policeOfficerId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    return RouteFilter(
      status: status ?? this.status,
      priority: priority ?? this.priority,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      dashboardType: dashboardType ?? this.dashboardType,
      viewType: viewType ?? this.viewType,
      policeOfficerId: policeOfficerId ?? this.policeOfficerId,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
    );
  }

  /// Clear all filters
  RouteFilter cleared() {
    return RouteFilter(
      dashboardType: dashboardType,
      viewType: viewType,
    );
  }
}

/// Route sort options
enum RouteSortOption {
  newest,
  oldest,
  priority,
  eta,
  distance,
  status,
  clearedDate,
  completedDate,
}

/// Route filter provider
final routeFilterProvider = StateProvider<RouteFilter>((ref) => RouteFilter());

/// Filtered routes provider for hospital dashboard
final filteredHospitalRoutesProvider =
    Provider.family<List<AmbulanceRouteModel>, RouteFilter>(
  (ref, filter) {
    late AsyncValue<List<AmbulanceRouteModel>> routesAsync;

    // Get appropriate routes based on view type
    switch (filter.viewType) {
      case RouteViewType.hospitalActive:
        routesAsync = ref.watch(hospitalActiveRoutesProvider('default'));
        break;
      case RouteViewType.hospitalHistory:
        routesAsync = ref.watch(hospitalRouteHistoryProvider('default'));
        break;
      case RouteViewType.hospitalAll:
      default:
        routesAsync = ref.watch(hospitalRoutesProvider('default'));
        break;
    }

    return routesAsync.when(
      data: (routes) => _applyFiltersAndSorting(routes, filter),
      loading: () => <AmbulanceRouteModel>[],
      error: (error, stack) => <AmbulanceRouteModel>[],
    );
  },
);

/// Filtered routes provider for police dashboard
final filteredPoliceRoutesProvider =
    Provider.family<List<AmbulanceRouteModel>, RouteFilter>(
  (ref, filter) {
    late AsyncValue<List<AmbulanceRouteModel>> routesAsync;

    // Get appropriate routes based on view type
    switch (filter.viewType) {
      case RouteViewType.policePending:
        routesAsync = ref.watch(policePendingRoutesProvider);
        break;
      case RouteViewType.policeActive:
        routesAsync = ref.watch(policeActiveRoutesProvider);
        break;
      case RouteViewType.policeHistory:
        routesAsync = ref.watch(policeRouteHistoryProvider);
        break;
      case RouteViewType.policeAll:
      default:
        routesAsync = ref.watch(policeAllRoutesProvider);
        break;
    }

    return routesAsync.when(
      data: (routes) => _applyFiltersAndSorting(routes, filter),
      loading: () => <AmbulanceRouteModel>[],
      error: (error, stack) => <AmbulanceRouteModel>[],
    );
  },
);

/// Legacy filtered routes provider (for backwards compatibility)
final filteredRoutesProvider =
    Provider.family<List<AmbulanceRouteModel>, RouteFilter>(
  (ref, filter) {
    // Default to police all routes for legacy compatibility
    final routesAsync = ref.watch(policeAllRoutesProvider);

    return routesAsync.when(
      data: (routes) => _applyFiltersAndSorting(routes, filter),
      loading: () => <AmbulanceRouteModel>[],
      error: (error, stack) => <AmbulanceRouteModel>[],
    );
  },
);

// =============================================================================
// STATISTICS PROVIDERS
// =============================================================================

/// Hospital route statistics
final hospitalRouteStatisticsProvider =
    Provider.family<Map<String, int>, String>((ref, hospitalId) {
  final allRoutesAsync = ref.watch(hospitalRoutesProvider(hospitalId));
  final activeRoutesAsync = ref.watch(hospitalActiveRoutesProvider(hospitalId));
  final historyRoutesAsync =
      ref.watch(hospitalRouteHistoryProvider(hospitalId));

  return allRoutesAsync.when(
    data: (allRoutes) {
      final activeRoutes = activeRoutesAsync.maybeWhen(
        data: (routes) => routes,
        orElse: () => <AmbulanceRouteModel>[],
      );
      final historyRoutes = historyRoutesAsync.maybeWhen(
        data: (routes) => routes,
        orElse: () => <AmbulanceRouteModel>[],
      );

      return {
        'total': allRoutes.length,
        'active': activeRoutes.length,
        'enRoute': allRoutes.where((r) => r.status.isActiveForHospital).length,
        'completed': historyRoutes.length,
        'critical':
            allRoutes.where((r) => r.emergencyPriority == 'critical').length,
        'high': allRoutes.where((r) => r.emergencyPriority == 'high').length,
        'cleared':
            allRoutes.where((r) => r.status == RouteStatus.cleared).length,
      };
    },
    loading: () => <String, int>{},
    error: (error, stack) => <String, int>{},
  );
});

/// Police route statistics
final policeRouteStatisticsProvider = Provider<Map<String, int>>((ref) {
  final pendingAsync = ref.watch(policePendingRoutesProvider);
  final activeAsync = ref.watch(policeActiveRoutesProvider);
  final historyAsync = ref.watch(policeRouteHistoryProvider);

  return pendingAsync.when(
    data: (pendingRoutes) {
      final activeRoutes = activeAsync.maybeWhen(
        data: (routes) => routes,
        orElse: () => <AmbulanceRouteModel>[],
      );
      final historyRoutes = historyAsync.maybeWhen(
        data: (routes) => routes,
        orElse: () => <AmbulanceRouteModel>[],
      );

      final allCurrentRoutes = [...pendingRoutes, ...activeRoutes];

      return {
        'pending': pendingRoutes.length,
        'active': activeRoutes.length,
        'completed': historyRoutes.length,
        'total': allCurrentRoutes.length,
        'critical': allCurrentRoutes
            .where((r) => r.emergencyPriority == 'critical')
            .length,
        'high':
            allCurrentRoutes.where((r) => r.emergencyPriority == 'high').length,
        'timeout': allCurrentRoutes
            .where((r) => r.status == RouteStatus.timeout)
            .length,
      };
    },
    loading: () => <String, int>{},
    error: (error, stack) => <String, int>{},
  );
});

/// Legacy route statistics provider (redirects to police stats)
final routeStatisticsProvider = Provider<Map<String, int>>((ref) {
  return ref.watch(policeRouteStatisticsProvider);
});

// =============================================================================
// STATE MANAGEMENT
// =============================================================================

/// Route calculation state
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

/// Route calculation notifier
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

/// Route calculation provider
final routeCalculationProvider =
    StateNotifierProvider<RouteCalculationNotifier, RouteCalculationState>(
  (ref) => RouteCalculationNotifier(ref.watch(routeServiceProvider)),
);

/// Route status update state
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

/// Route status update notifier
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
    String? completionReason,
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      await _routeService.updateRouteStatus(
        routeId: routeId,
        newStatus: newStatus,
        policeOfficerId: policeOfficerId,
        policeOfficerName: policeOfficerName,
        notes: notes,
        completionReason: completionReason,
      );

      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      log('Error updating route status: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> completeRoute({
    required String routeId,
    required String completedBy,
    required String completedByName,
    String? completionReason,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      await _routeService.completeRoute(
        routeId: routeId,
        completedBy: completedBy,
        completedByName: completedByName,
        completionReason: completionReason,
        notes: notes,
      );

      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      log('Error completing route: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() {
    state = RouteStatusUpdateState();
  }
}

/// Route status update provider
final routeStatusUpdateProvider =
    StateNotifierProvider<RouteStatusUpdateNotifier, RouteStatusUpdateState>(
  (ref) => RouteStatusUpdateNotifier(ref.watch(routeServiceProvider)),
);

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/// Apply filters and sorting to route list
List<AmbulanceRouteModel> _applyFiltersAndSorting(
  List<AmbulanceRouteModel> routes,
  RouteFilter filter,
) {
  var filteredRoutes = routes;

  // Filter by status
  if (filter.status != null) {
    filteredRoutes =
        filteredRoutes.where((route) => route.status == filter.status).toList();
  }

  // Filter by priority
  if (filter.priority != null) {
    filteredRoutes = filteredRoutes
        .where((route) => route.emergencyPriority == filter.priority)
        .toList();
  }

  // Filter by police officer
  if (filter.policeOfficerId != null) {
    filteredRoutes = filteredRoutes
        .where((route) => route.policeOfficerId == filter.policeOfficerId)
        .toList();
  }

  // Filter by date range
  if (filter.dateFrom != null) {
    filteredRoutes = filteredRoutes
        .where((route) => route.createdAt.isAfter(filter.dateFrom!))
        .toList();
  }
  if (filter.dateTo != null) {
    filteredRoutes = filteredRoutes
        .where((route) => route.createdAt.isBefore(filter.dateTo!))
        .toList();
  }

  // Filter by search query
  if (filter.searchQuery.isNotEmpty) {
    final query = filter.searchQuery.toLowerCase();
    filteredRoutes = filteredRoutes.where((route) {
      return route.ambulanceLicensePlate.toLowerCase().contains(query) ||
          route.patientLocation.toLowerCase().contains(query) ||
          route.emergencyPriority.toLowerCase().contains(query) ||
          (route.policeOfficerName?.toLowerCase().contains(query) ?? false);
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
        final priorityOrder = {'critical': 4, 'high': 3, 'medium': 2, 'low': 1};
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
    case RouteSortOption.status:
      filteredRoutes.sort((a, b) => a.status.value.compareTo(b.status.value));
      break;
    case RouteSortOption.clearedDate:
      filteredRoutes.sort((a, b) {
        if (a.clearedAt == null && b.clearedAt == null) return 0;
        if (a.clearedAt == null) return 1;
        if (b.clearedAt == null) return -1;
        return b.clearedAt!.compareTo(a.clearedAt!);
      });
      break;
    case RouteSortOption.completedDate:
      filteredRoutes.sort((a, b) {
        if (a.completedAt == null && b.completedAt == null) return 0;
        if (a.completedAt == null) return 1;
        if (b.completedAt == null) return -1;
        return b.completedAt!.compareTo(a.completedAt!);
      });
      break;
  }

  return filteredRoutes;
}
