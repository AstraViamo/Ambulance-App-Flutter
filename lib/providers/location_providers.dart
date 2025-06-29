// lib/providers/location_providers.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/ambulance_model.dart';
import '../services/location_service.dart';

// Location service provider
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// Tracking state provider
final trackingStateProvider =
    StateNotifierProvider<TrackingStateNotifier, TrackingState>((ref) {
  return TrackingStateNotifier(ref.watch(locationServiceProvider));
});

// Location permission provider
final locationPermissionProvider =
    FutureProvider<LocationPermission>((ref) async {
  return await Geolocator.checkPermission();
});

// Current location provider
final currentLocationProvider = StreamProvider<Position?>((ref) {
  const locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );

  return Geolocator.getPositionStream(locationSettings: locationSettings);
});

// Real-time ambulance locations provider
final ambulanceLocationsProvider =
    StreamProvider.family<List<AmbulanceLocation>, String>(
  (ref, hospitalId) {
    return FirebaseFirestore.instance
        .collection('ambulances')
        .where('hospitalId', isEqualTo: hospitalId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return AmbulanceLocation.fromMap(doc.id, data);
      }).toList();
    });
  },
);

// Ambulance location history provider
final ambulanceLocationHistoryProvider =
    StreamProvider.family<List<LocationHistoryEntry>, String>(
  (ref, ambulanceId) {
    return FirebaseFirestore.instance
        .collection('ambulances')
        .doc(ambulanceId)
        .collection('location_history')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return LocationHistoryEntry.fromMap(doc.id, doc.data());
      }).toList();
    });
  },
);

// Location stats provider
final locationStatsProvider = StreamProvider.family<LocationStats, String>(
  (ref, hospitalId) {
    return FirebaseFirestore.instance
        .collection('ambulances')
        .where('hospitalId', isEqualTo: hospitalId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      int totalAmbulances = 0;
      int activelyTracked = 0;
      int staleLocations = 0;
      int onlineDrivers = 0;

      final now = DateTime.now();
      const staleThreshold = Duration(minutes: 2);

      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalAmbulances++;

        if (data['lastLocationUpdate'] != null) {
          activelyTracked++;

          final lastUpdate = (data['lastLocationUpdate'] as Timestamp).toDate();
          if (now.difference(lastUpdate) > staleThreshold) {
            staleLocations++;
          }
        }

        if (data['currentDriverId'] != null && data['status'] != 'offline') {
          onlineDrivers++;
        }
      }

      return LocationStats(
        totalAmbulances: totalAmbulances,
        activelyTracked: activelyTracked,
        staleLocations: staleLocations,
        onlineDrivers: onlineDrivers,
      );
    });
  },
);

// Selected ambulance for tracking provider
final selectedTrackingAmbulanceProvider = StateProvider<String?>((ref) => null);

// Map bounds provider for optimization
final mapBoundsProvider = StateProvider<MapBounds?>((ref) => null);

// Visible ambulances (within map bounds) provider
final visibleAmbulancesProvider =
    Provider.family<List<AmbulanceLocation>, String>(
  (ref, hospitalId) {
    final allAmbulances = ref.watch(ambulanceLocationsProvider(hospitalId));
    final bounds = ref.watch(mapBoundsProvider);

    return allAmbulances.when(
      data: (ambulances) {
        if (bounds == null) return ambulances;

        return ambulances.where((ambulance) {
          if (ambulance.latitude == null || ambulance.longitude == null) {
            return false;
          }

          return ambulance.latitude! >= bounds.southWest.latitude &&
              ambulance.latitude! <= bounds.northEast.latitude &&
              ambulance.longitude! >= bounds.southWest.longitude &&
              ambulance.longitude! <= bounds.northEast.longitude;
        }).toList();
      },
      loading: () => [],
      error: (_, __) => [],
    );
  },
);

// Tracking state notifier
class TrackingStateNotifier extends StateNotifier<TrackingState> {
  final LocationService _locationService;
  Timer? _statusUpdateTimer;
  StreamSubscription? _authStateSubscription;

  TrackingStateNotifier(this._locationService)
      : super(TrackingState.initial()) {
    // Listen to auth state changes and stop tracking on signout
    _initializeAuthListener();
  }

  void _initializeAuthListener() {
    // Note: In a real implementation, you'd inject the auth service
    // For now, this is a placeholder for the auth state listener
    // You should inject FirebaseAuth and listen to authStateChanges
  }

  Future<bool> startTracking({
    required String ambulanceId,
    required String driverId,
    required String initialStatus,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final success = await _locationService.startTracking(
      ambulanceId: ambulanceId,
      driverId: driverId,
      initialStatus: initialStatus,
    );

    if (success) {
      state = state.copyWith(
        isTracking: true,
        isLoading: false,
        ambulanceId: ambulanceId,
        driverId: driverId,
        currentStatus: initialStatus,
      );

      _startStatusUpdates();
    } else {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to start location tracking. Please check permissions.',
      );
    }

    return success;
  }

  Future<void> stopTracking() async {
    try {
      await _locationService.stopTracking();
      _statusUpdateTimer?.cancel();
      _statusUpdateTimer = null;

      state = TrackingState.initial();
    } catch (e) {
      state = state.copyWith(
        error: 'Error stopping tracking: $e',
        isLoading: false,
      );
    }
  }

  Future<void> updateStatus(String newStatus) async {
    if (state.ambulanceId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      await _locationService.updateStatus(
        ambulanceId: state.ambulanceId!,
        status: newStatus,
      );

      state = state.copyWith(
        currentStatus: newStatus,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update status: $e',
      );
    }
  }

  void _startStatusUpdates() {
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        state = state.copyWith(
          queuedUpdates: _locationService.queuedUpdatesCount,
          isOnline: _locationService.isOnline,
          lastUpdateTime: DateTime.now(),
        );
      }
    });
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _statusUpdateTimer?.cancel();
    _authStateSubscription?.cancel();
    super.dispose();
  }
}

// Data models
class TrackingState {
  final bool isTracking;
  final bool isLoading;
  final String? ambulanceId;
  final String? driverId;
  final String? currentStatus;
  final String? error;
  final int queuedUpdates;
  final bool isOnline;
  final DateTime? lastUpdateTime;

  TrackingState({
    required this.isTracking,
    required this.isLoading,
    this.ambulanceId,
    this.driverId,
    this.currentStatus,
    this.error,
    this.queuedUpdates = 0,
    this.isOnline = true,
    this.lastUpdateTime,
  });

  factory TrackingState.initial() {
    return TrackingState(
      isTracking: false,
      isLoading: false,
    );
  }

  TrackingState copyWith({
    bool? isTracking,
    bool? isLoading,
    String? ambulanceId,
    String? driverId,
    String? currentStatus,
    String? error,
    int? queuedUpdates,
    bool? isOnline,
    DateTime? lastUpdateTime,
  }) {
    return TrackingState(
      isTracking: isTracking ?? this.isTracking,
      isLoading: isLoading ?? this.isLoading,
      ambulanceId: ambulanceId ?? this.ambulanceId,
      driverId: driverId ?? this.driverId,
      currentStatus: currentStatus ?? this.currentStatus,
      error: error ?? this.error,
      queuedUpdates: queuedUpdates ?? this.queuedUpdates,
      isOnline: isOnline ?? this.isOnline,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
    );
  }
}

class AmbulanceLocation {
  final String id;
  final String licensePlate;
  final String model;
  final AmbulanceStatus status;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final DateTime? lastLocationUpdate;
  final String? currentDriverId;
  final bool isStale;

  AmbulanceLocation({
    required this.id,
    required this.licensePlate,
    required this.model,
    required this.status,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    this.lastLocationUpdate,
    this.currentDriverId,
    this.isStale = false,
  });

  factory AmbulanceLocation.fromMap(String id, Map<String, dynamic> data) {
    return AmbulanceLocation(
      id: id,
      licensePlate: data['licensePlate'] ?? '',
      model: data['model'] ?? '',
      status: AmbulanceStatus.fromString(data['status'] ?? 'offline'),
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      accuracy: data['locationAccuracy']?.toDouble(),
      speed: data['speed']?.toDouble(),
      heading: data['heading']?.toDouble(),
      lastLocationUpdate: data['lastLocationUpdate'] != null
          ? (data['lastLocationUpdate'] as Timestamp).toDate()
          : null,
      currentDriverId: data['currentDriverId'],
      isStale: data['isStale'] ?? false,
    );
  }

  bool get hasLocation => latitude != null && longitude != null;

  String get statusDisplayName => status.displayName;

  Color get statusColor => Color(AmbulanceStatus.getStatusColor(status));

  String get lastUpdateFormatted {
    if (lastLocationUpdate == null) return 'No location data';

    final now = DateTime.now();
    final difference = now.difference(lastLocationUpdate!);

    if (difference.inSeconds < 30) {
      return 'Just now';
    } else if (difference.inMinutes < 1) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class LocationHistoryEntry {
  final String id;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final DateTime timestamp;
  final String status;
  final String driverId;

  LocationHistoryEntry({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    required this.timestamp,
    required this.status,
    required this.driverId,
  });

  factory LocationHistoryEntry.fromMap(String id, Map<String, dynamic> data) {
    return LocationHistoryEntry(
      id: id,
      latitude: data['latitude'].toDouble(),
      longitude: data['longitude'].toDouble(),
      accuracy: data['accuracy']?.toDouble(),
      speed: data['speed']?.toDouble(),
      heading: data['heading']?.toDouble(),
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.parse(data['lastUpdateTime']),
      status: data['status'] ?? 'unknown',
      driverId: data['driverId'] ?? '',
    );
  }
}

class LocationStats {
  final int totalAmbulances;
  final int activelyTracked;
  final int staleLocations;
  final int onlineDrivers;

  LocationStats({
    required this.totalAmbulances,
    required this.activelyTracked,
    required this.staleLocations,
    required this.onlineDrivers,
  });

  double get trackingPercentage {
    if (totalAmbulances == 0) return 0.0;
    return (activelyTracked / totalAmbulances) * 100;
  }

  double get stalePercentage {
    if (activelyTracked == 0) return 0.0;
    return (staleLocations / activelyTracked) * 100;
  }
}

class MapBounds {
  final MapLatLng northEast;
  final MapLatLng southWest;

  MapBounds({
    required this.northEast,
    required this.southWest,
  });
}

class MapLatLng {
  final double latitude;
  final double longitude;

  MapLatLng(this.latitude, this.longitude);
}
