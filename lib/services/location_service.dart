// lib/services/location_service.dart
import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'connectivity_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConnectivityService _connectivityService = ConnectivityService();

  Timer? _locationTimer;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isTracking = false;

  // Configuration
  static const Duration _updateInterval = Duration(seconds: 30);
  static const double _minimumDistance = 10.0; // meters
  static const Duration _staleThreshold = Duration(minutes: 2);

  // Queue for offline updates
  final List<Map<String, dynamic>> _queuedUpdates = [];
  bool _isOnline = true;

  // Last known position to avoid unnecessary updates
  Position? _lastPosition;
  DateTime? _lastUpdateTime;

  /// Check and request location permissions
  Future<bool> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        log('Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      log('Location permissions are permanently denied');
      return false;
    }

    // Check background location permission (for Android)
    final backgroundPermission = await Permission.locationAlways.status;
    if (backgroundPermission != PermissionStatus.granted) {
      final result = await Permission.locationAlways.request();
      if (result != PermissionStatus.granted) {
        log('Background location permission denied');
        // Still allow foreground tracking
      }
    }

    return true;
  }

  /// Check if location services are enabled
  Future<bool> _checkLocationService() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      log('Location services are disabled');
      return false;
    }
    return true;
  }

  /// Calculate distance between two positions
  double _calculateDistance(Position pos1, Position pos2) {
    return Geolocator.distanceBetween(
      pos1.latitude,
      pos1.longitude,
      pos2.latitude,
      pos2.longitude,
    );
  }

  /// Check if significant movement occurred
  bool _hasSignificantMovement(Position newPosition) {
    if (_lastPosition == null) return true;

    final distance = _calculateDistance(_lastPosition!, newPosition);
    return distance >= _minimumDistance;
  }

  /// Update ambulance location in Firestore
  Future<void> _updateLocationInFirestore({
    required String ambulanceId,
    required String driverId,
    required Position position,
    required String status,
    bool forceUpdate = false,
  }) async {
    try {
      // Skip update if no significant movement and not forced
      if (!forceUpdate && !_hasSignificantMovement(position)) {
        log('Skipping update - no significant movement');
        return;
      }

      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': FieldValue.serverTimestamp(),
        'lastUpdateTime': DateTime.now().toIso8601String(),
        'driverId': driverId,
        'status': status,
        'isStale': false,
      };

      if (_isOnline) {
        // Update ambulance document
        await _firestore.collection('ambulances').doc(ambulanceId).update({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'lastLocationUpdate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'locationAccuracy': position.accuracy,
          'speed': position.speed,
          'heading': position.heading,
        });

        // Create location history entry
        await _firestore
            .collection('ambulances')
            .doc(ambulanceId)
            .collection('location_history')
            .add(locationData);

        // Process any queued updates
        await _processQueuedUpdates(ambulanceId, driverId, status);

        _lastPosition = position;
        _lastUpdateTime = DateTime.now();

        log('Location updated successfully: ${position.latitude}, ${position.longitude}');
      } else {
        // Queue update for later
        _queuedUpdates.add({
          'ambulanceId': ambulanceId,
          'locationData': locationData,
          'timestamp': DateTime.now(),
        });
        log('Location update queued (offline)');
      }
    } catch (e) {
      log('Error updating location: $e');

      // If online but failed, might be temporary - queue it
      if (_isOnline) {
        _queuedUpdates.add({
          'ambulanceId': ambulanceId,
          'locationData': {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'timestamp': FieldValue.serverTimestamp(),
            'lastUpdateTime': DateTime.now().toIso8601String(),
            'driverId': driverId,
            'status': status,
          },
          'timestamp': DateTime.now(),
        });
      }
    }
  }

  /// Process queued location updates
  Future<void> _processQueuedUpdates(
    String ambulanceId,
    String driverId,
    String status,
  ) async {
    if (_queuedUpdates.isEmpty) return;

    log('Processing ${_queuedUpdates.length} queued updates');

    final batch = _firestore.batch();
    int batchCount = 0;
    const maxBatchSize = 500; // Firestore batch limit

    for (int i = _queuedUpdates.length - 1; i >= 0; i--) {
      final update = _queuedUpdates[i];

      try {
        // Update main ambulance document (only latest)
        if (i == _queuedUpdates.length - 1) {
          final ambulanceRef =
              _firestore.collection('ambulances').doc(ambulanceId);
          batch.update(ambulanceRef, {
            'latitude': update['locationData']['latitude'],
            'longitude': update['locationData']['longitude'],
            'lastLocationUpdate': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          batchCount++;
        }

        // Add to location history
        final historyRef = _firestore
            .collection('ambulances')
            .doc(ambulanceId)
            .collection('location_history')
            .doc();

        batch.set(historyRef, update['locationData']);
        batchCount++;

        // Execute batch if near limit
        if (batchCount >= maxBatchSize - 10) {
          await batch.commit();
          batchCount = 0;
        }

        _queuedUpdates.removeAt(i);
      } catch (e) {
        log('Error processing queued update: $e');
        break;
      }
    }

    // Commit remaining updates
    if (batchCount > 0) {
      await batch.commit();
    }

    log('Finished processing queued updates');
  }

  /// Start location tracking for ambulance driver
  Future<bool> startTracking({
    required String ambulanceId,
    required String driverId,
    required String initialStatus,
  }) async {
    if (_isTracking) {
      log('Location tracking already started');
      return true;
    }

    // Check permissions and services
    if (!await _checkPermissions() || !await _checkLocationService()) {
      return false;
    }

    try {
      _isTracking = true;

      // Initialize connectivity service
      await _connectivityService.initialize();
      _isOnline = _connectivityService.isOnline;

      // Listen to connectivity changes
      _connectivitySubscription =
          _connectivityService.onConnectivityChanged.listen(
        (isOnline) {
          _isOnline = isOnline;
          if (isOnline) {
            log('Connectivity restored - processing queued updates');
            _processQueuedUpdates(ambulanceId, driverId, initialStatus);
          } else {
            log('Connectivity lost - will queue updates');
          }
        },
      );

      // Configure location settings for optimal battery/accuracy balance
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Only report location changes > 5 meters
      );

      // Start periodic location updates
      _locationTimer = Timer.periodic(_updateInterval, (timer) async {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );

          await _updateLocationInFirestore(
            ambulanceId: ambulanceId,
            driverId: driverId,
            position: position,
            status: initialStatus,
          );
        } catch (e) {
          log('Error getting current position: $e');
        }
      });

      // Also listen to position stream for more responsive updates
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) async {
          // Only update if significant time has passed or significant movement
          final now = DateTime.now();
          if (_lastUpdateTime == null ||
              now.difference(_lastUpdateTime!).inSeconds >= 25 ||
              _hasSignificantMovement(position)) {
            await _updateLocationInFirestore(
              ambulanceId: ambulanceId,
              driverId: driverId,
              position: position,
              status: initialStatus,
            );
          }
        },
        onError: (error) {
          log('Position stream error: $error');
        },
      );

      log('Location tracking started for ambulance: $ambulanceId');
      return true;
    } catch (e) {
      log('Error starting location tracking: $e');
      _isTracking = false;
      return false;
    }
  }

  /// Stop location tracking
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    try {
      _locationTimer?.cancel();
      _locationTimer = null;

      await _positionSubscription?.cancel();
      _positionSubscription = null;

      await _connectivitySubscription?.cancel();
      _connectivitySubscription = null;

      // Don't dispose the connectivity service if it might be used elsewhere
      // _connectivityService.dispose();

      _isTracking = false;
      _lastPosition = null;
      _lastUpdateTime = null;

      // Clear queued updates when stopping tracking
      _queuedUpdates.clear();

      log('Location tracking stopped');
    } catch (e) {
      log('Error stopping location tracking: $e');
    }
  }

  /// Update ambulance status
  Future<void> updateStatus({
    required String ambulanceId,
    required String status,
  }) async {
    try {
      await _firestore.collection('ambulances').doc(ambulanceId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      log('Status updated to: $status');
    } catch (e) {
      log('Error updating status: $e');
    }
  }

  /// Monitor connectivity and update online status
  void _monitorConnectivity() {
    // Simple connectivity check - test with a lightweight Firestore operation
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        // Test connectivity with a simple document read instead of a query
        // This avoids the permission denied error from querying collections
        await _firestore
            .collection('ambulances')
            .limit(1)
            .get(const GetOptions(source: Source.server));

        if (!_isOnline) {
          _isOnline = true;
          log('Connectivity restored');
        }
      } catch (e) {
        if (_isOnline) {
          _isOnline = false;
          log('Connectivity lost');
        }
      }
    });
  }

  /// Mark stale locations
  static Future<void> markStaleLocations() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final threshold = DateTime.now().subtract(_staleThreshold);

      final query = await firestore
          .collection('ambulances')
          .where('lastLocationUpdate',
              isLessThan: Timestamp.fromDate(threshold))
          .where('isActive', isEqualTo: true)
          .get();

      final batch = firestore.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {'isStale': true});
      }

      if (query.docs.isNotEmpty) {
        await batch.commit();
        log('Marked ${query.docs.length} ambulances as stale');
      }
    } catch (e) {
      log('Error marking stale locations: $e');
    }
  }

  /// Get current location once
  Future<Position?> getCurrentLocation() async {
    try {
      if (!await _checkPermissions() || !await _checkLocationService()) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      log('Error getting current location: $e');
      return null;
    }
  }

  /// Check if tracking is active
  bool get isTracking => _isTracking;

  /// Get queue status
  int get queuedUpdatesCount => _queuedUpdates.length;

  /// Get online status
  bool get isOnline => _isOnline;
}
