// lib/services/connectivity_service.dart
import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _firestoreTestTimer;

  bool _isOnline = true;
  bool _hasNetworkConnection = true;
  bool _hasFirestoreConnection = true;

  // Stream controller for connectivity updates
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    try {
      // Check initial connectivity
      final result = await _connectivity.checkConnectivity();
      _hasNetworkConnection = result != ConnectivityResult.none;

      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: (error) {
          log('Connectivity subscription error: $error');
        },
      );

      // Start Firestore connectivity testing
      _startFirestoreConnectivityTest();

      // Update initial online status
      _updateOnlineStatus();

      log('Connectivity service initialized');
    } catch (e) {
      log('Failed to initialize connectivity service: $e');
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    final wasConnected = _hasNetworkConnection;
    _hasNetworkConnection = result != ConnectivityResult.none;

    log('Network connectivity changed: $result (connected: $_hasNetworkConnection)');

    if (!wasConnected && _hasNetworkConnection) {
      // Network restored - test Firestore immediately
      _testFirestoreConnectivity();
    } else if (wasConnected && !_hasNetworkConnection) {
      // Network lost
      _hasFirestoreConnection = false;
      _updateOnlineStatus();
    }
  }

  /// Start periodic Firestore connectivity testing
  void _startFirestoreConnectivityTest() {
    _firestoreTestTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _testFirestoreConnectivity(),
    );
  }

  /// Test Firestore connectivity
  Future<void> _testFirestoreConnectivity() async {
    if (!_hasNetworkConnection) {
      _hasFirestoreConnection = false;
      _updateOnlineStatus();
      return;
    }

    try {
      // Use a lightweight operation that doesn't require special permissions
      // This creates a temporary document that will be deleted
      final testRef = _firestore.collection('_connectivity_test').doc();

      // Try to write and read a small document
      await testRef.set({
        'timestamp': FieldValue.serverTimestamp(),
        'test': true,
      });

      // Read it back to confirm round-trip connectivity
      await testRef.get(const GetOptions(source: Source.server));

      // Clean up the test document
      await testRef.delete();

      if (!_hasFirestoreConnection) {
        _hasFirestoreConnection = true;
        _updateOnlineStatus();
        log('Firestore connectivity restored');
      }
    } catch (e) {
      if (_hasFirestoreConnection) {
        _hasFirestoreConnection = false;
        _updateOnlineStatus();
        log('Firestore connectivity lost: $e');
      }
    }
  }

  /// Update overall online status
  void _updateOnlineStatus() {
    final wasOnline = _isOnline;
    _isOnline = _hasNetworkConnection && _hasFirestoreConnection;

    if (wasOnline != _isOnline) {
      _connectivityController.add(_isOnline);
      log('Online status changed: $_isOnline');
    }
  }

  /// Get current online status
  bool get isOnline => _isOnline;

  /// Get network connection status
  bool get hasNetworkConnection => _hasNetworkConnection;

  /// Get Firestore connection status
  bool get hasFirestoreConnection => _hasFirestoreConnection;

  /// Stream of connectivity changes
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  /// Force connectivity check
  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _hasNetworkConnection = result != ConnectivityResult.none;

    if (_hasNetworkConnection) {
      await _testFirestoreConnectivity();
    } else {
      _hasFirestoreConnection = false;
    }

    _updateOnlineStatus();
    return _isOnline;
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _firestoreTestTimer?.cancel();
    _connectivityController.close();
  }
}
