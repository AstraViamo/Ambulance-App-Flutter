// lib/services/background_location_service.dart
import 'dart:async';
import 'dart:developer';
import 'dart:isolate';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      log('Background task started: $task');

      switch (task) {
        case 'locationUpdate':
          await _performLocationUpdate(inputData);
          break;
        case 'markStaleLocations':
          await _markStaleLocations();
          break;
        default:
          log('Unknown background task: $task');
      }

      return Future.value(true);
    } catch (e) {
      log('Background task error: $e');
      return Future.value(false);
    }
  });
}

Future<void> _performLocationUpdate(Map<String, dynamic>? inputData) async {
  if (inputData == null) return;

  final ambulanceId = inputData['ambulanceId'] as String?;
  final driverId = inputData['driverId'] as String?;
  final status = inputData['status'] as String?;

  if (ambulanceId == null || driverId == null || status == null) {
    log('Invalid input data for location update');
    return;
  }

  try {
    // Check location permission
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      log('Location permission denied in background');
      return;
    }

    // Get current position
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 30),
    );

    // Update Firestore
    final firestore = FirebaseFirestore.instance;

    final batch = firestore.batch();

    // Update ambulance document
    final ambulanceRef = firestore.collection('ambulances').doc(ambulanceId);
    batch.update(ambulanceRef, {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'lastLocationUpdate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'locationAccuracy': position.accuracy,
      'speed': position.speed,
      'heading': position.heading,
      'isStale': false,
    });

    // Add to location history
    final historyRef = ambulanceRef.collection('location_history').doc();
    batch.set(historyRef, {
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
    });

    await batch.commit();
    log('Background location update successful');

    // Send update to UI if needed
    _sendLocationUpdateToUI(position, ambulanceId);
  } catch (e) {
    log('Background location update failed: $e');
  }
}

Future<void> _markStaleLocations() async {
  try {
    final firestore = FirebaseFirestore.instance;
    final threshold = DateTime.now().subtract(const Duration(minutes: 2));

    final query = await firestore
        .collection('ambulances')
        .where('lastLocationUpdate', isLessThan: Timestamp.fromDate(threshold))
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

void _sendLocationUpdateToUI(Position position, String ambulanceId) {
  try {
    final SendPort? sendPort =
        IsolateNameServer.lookupPortByName('location_isolate');
    sendPort?.send({
      'type': 'location_update',
      'ambulanceId': ambulanceId,
      'position': {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    });
  } catch (e) {
    log('Failed to send location update to UI: $e');
  }
}

class BackgroundLocationService {
  static final BackgroundLocationService _instance =
      BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  static const String _locationUpdateTask = 'locationUpdate';
  static const String _staleMarkingTask = 'markStaleLocations';

  bool _isInitialized = false;
  bool _isBackgroundTrackingActive = false;
  ReceivePort? _receivePort;

  /// Initialize the background service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false, // Set to true for debugging
      );

      // Register periodic task for marking stale locations
      await Workmanager().registerPeriodicTask(
        _staleMarkingTask,
        _staleMarkingTask,
        frequency: const Duration(minutes: 5),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );

      _setupIsolateListener();
      _isInitialized = true;

      log('Background location service initialized');
    } catch (e) {
      log('Failed to initialize background service: $e');
    }
  }

  /// Setup isolate communication
  void _setupIsolateListener() {
    _receivePort = ReceivePort();
    IsolateNameServer.registerPortWithName(
        _receivePort!.sendPort, 'location_isolate');

    _receivePort!.listen((dynamic data) {
      if (data is Map<String, dynamic>) {
        final type = data['type'] as String?;
        if (type == 'location_update') {
          _handleLocationUpdate(data);
        }
      }
    });
  }

  void _handleLocationUpdate(Map<String, dynamic> data) {
    // Handle location updates from background isolate
    // This can be used to update UI or perform additional processing
    log('Received background location update: ${data['ambulanceId']}');
  }

  /// Start background location tracking
  Future<bool> startBackgroundTracking({
    required String ambulanceId,
    required String driverId,
    required String status,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Check if we can run background tasks
      final isBackgroundExecutionEnabled = await _checkBackgroundExecution();
      if (!isBackgroundExecutionEnabled) {
        log('Background execution not enabled');
        return false;
      }

      // Cancel any existing tracking
      await stopBackgroundTracking();

      // Register periodic location update task
      await Workmanager().registerPeriodicTask(
        _locationUpdateTask,
        _locationUpdateTask,
        frequency: const Duration(seconds: 30),
        initialDelay: const Duration(seconds: 5),
        inputData: {
          'ambulanceId': ambulanceId,
          'driverId': driverId,
          'status': status,
        },
        constraints: Constraints(
          networkType: NetworkType.not_required,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
        ),
      );

      _isBackgroundTrackingActive = true;
      log('Background location tracking started for ambulance: $ambulanceId');
      return true;
    } catch (e) {
      log('Failed to start background tracking: $e');
      return false;
    }
  }

  /// Stop background location tracking
  Future<void> stopBackgroundTracking() async {
    if (!_isBackgroundTrackingActive) return;

    try {
      await Workmanager().cancelByUniqueName(_locationUpdateTask);
      _isBackgroundTrackingActive = false;
      log('Background location tracking stopped');
    } catch (e) {
      log('Error stopping background tracking: $e');
    }
  }

  /// Update status for background tracking
  Future<void> updateBackgroundStatus({
    required String ambulanceId,
    required String driverId,
    required String newStatus,
  }) async {
    if (!_isBackgroundTrackingActive) return;

    try {
      // Cancel current task and restart with new status
      await Workmanager().cancelByUniqueName(_locationUpdateTask);

      await Workmanager().registerPeriodicTask(
        _locationUpdateTask,
        _locationUpdateTask,
        frequency: const Duration(seconds: 30),
        inputData: {
          'ambulanceId': ambulanceId,
          'driverId': driverId,
          'status': newStatus,
        },
        constraints: Constraints(
          networkType: NetworkType.not_required,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
        ),
      );

      log('Background tracking status updated to: $newStatus');
    } catch (e) {
      log('Failed to update background status: $e');
    }
  }

  /// Check if background execution is available
  Future<bool> _checkBackgroundExecution() async {
    try {
      // Check location permissions
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      return true;
    } catch (e) {
      log('Error checking background execution capability: $e');
      return false;
    }
  }

  /// Get background tracking status
  bool get isBackgroundTrackingActive => _isBackgroundTrackingActive;

  /// Clean up resources
  void dispose() {
    _receivePort?.close();
    IsolateNameServer.removePortNameMapping('location_isolate');
  }
}

// Battery optimization helper
class BatteryOptimizationHelper {
  static const MethodChannel _channel = MethodChannel('battery_optimization');

  /// Check if battery optimization is disabled for the app
  static Future<bool> isBatteryOptimizationDisabled() async {
    try {
      final bool isDisabled =
          await _channel.invokeMethod('isBatteryOptimizationDisabled');
      return isDisabled;
    } on PlatformException catch (e) {
      log('Failed to check battery optimization: ${e.message}');
      return false;
    }
  }

  /// Request to disable battery optimization
  static Future<bool> requestDisableBatteryOptimization() async {
    try {
      final bool result =
          await _channel.invokeMethod('requestDisableBatteryOptimization');
      return result;
    } on PlatformException catch (e) {
      log('Failed to request battery optimization disable: ${e.message}');
      return false;
    }
  }

  /// Open battery optimization settings
  static Future<void> openBatteryOptimizationSettings() async {
    try {
      await _channel.invokeMethod('openBatteryOptimizationSettings');
    } on PlatformException catch (e) {
      log('Failed to open battery optimization settings: ${e.message}');
    }
  }
}

// Location tracking configuration
class LocationTrackingConfig {
  static const Duration updateInterval = Duration(seconds: 30);
  static const Duration staleThreshold = Duration(minutes: 2);
  static const double minimumDistance = 10.0; // meters
  static const LocationAccuracy accuracy = LocationAccuracy.high;
  static const Duration timeLimit = Duration(seconds: 30);

  // Battery optimization settings
  static const bool requiresBatteryNotLow = false;
  static const bool requiresCharging = false;
  static const bool requiresDeviceIdle = false;

  // Network requirements
  static const NetworkType networkType = NetworkType.not_required;
}
