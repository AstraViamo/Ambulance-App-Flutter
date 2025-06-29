// lib/screens/enhanced_driver_dashboard_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/ambulance_model.dart';
import '../providers/auth_provider.dart';
import '../providers/driver_providers.dart';
import '../providers/location_providers.dart';
import 'login_screen.dart';

class DriverDashboardScreen extends ConsumerStatefulWidget {
  const DriverDashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DriverDashboardScreen> createState() =>
      _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends ConsumerState<DriverDashboardScreen>
    with WidgetsBindingObserver {
  String? driverId;
  String? currentAmbulanceId;
  Timer? _uiUpdateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDriverData();
    _startUIUpdates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes for background tracking
    switch (state) {
      case AppLifecycleState.paused:
        // App moved to background - tracking continues
        break;
      case AppLifecycleState.resumed:
        // App brought to foreground - refresh UI
        _refreshData();
        break;
      case AppLifecycleState.detached:
        // App being terminated - stop tracking
        _stopTracking();
        break;
      default:
        break;
    }
  }

  Future<void> _loadDriverData() async {
    final currentUser = await ref.read(currentUserProvider.future);
    if (currentUser != null) {
      setState(() {
        driverId = currentUser.id;
      });

      // Find current ambulance assignment
      final ambulancesAsync = ref.read(driverAmbulancesProvider(driverId!));
      ambulancesAsync.whenData((ambulances) {
        for (var ambulanceData in ambulances) {
          if (ambulanceData['currentDriverId'] == driverId) {
            currentAmbulanceId = ambulanceData['id'];
            break;
          }
        }
        setState(() {});
      });

      // Set initial availability state
      final isAvailable = currentUser.roleSpecificData.isAvailable ?? false;
      ref.read(currentDriverAvailabilityProvider.notifier).state = isAvailable;
    }
  }

  void _startUIUpdates() {
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      // Refresh tracking state periodically
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _refreshData() {
    if (driverId != null) {
      ref.refresh(driverAmbulancesProvider(driverId!));
      ref.refresh(driverStatsProvider(driverId!));
    }
  }

  Future<void> _stopTracking() async {
    final trackingNotifier = ref.read(trackingStateProvider.notifier);
    await trackingNotifier.stopTracking();
  }

  @override
  Widget build(BuildContext context) {
    if (driverId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Driver Dashboard',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.orange.shade700,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final driverAmbulancesAsync =
        ref.watch(driverAmbulancesProvider(driverId!));
    final driverStatsAsync = ref.watch(driverStatsProvider(driverId!));
    final trackingState = ref.watch(trackingStateProvider);
    final isAvailable = ref.watch(currentDriverAvailabilityProvider);
    final isLoading = ref.watch(driverLoadingProvider);
    final error = ref.watch(driverErrorProvider);
    final currentLocation = ref.watch(currentLocationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange.shade700,
        elevation: 0,
        actions: [
          // Location tracking indicator
          if (trackingState.isTracking)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Icon(
                trackingState.isOnline ? Icons.gps_fixed : Icons.gps_off,
                color: trackingState.isOnline
                    ? Colors.greenAccent
                    : Colors.redAccent,
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.person, color: Colors.white),
            onSelected: (value) async {
              if (value == 'logout') {
                _showLogoutDialog();
              } else if (value == 'location_settings') {
                _showLocationSettings();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'location_settings',
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Location Settings'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshData();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card with Location Tracking
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.orange.shade700.withOpacity(0.1),
                      Colors.orange.shade700.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(
                        Icons.local_shipping,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome back!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const Text(
                      'Ambulance Driver',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Availability Toggle
                    _buildAvailabilityToggle(isAvailable, isLoading),

                    const SizedBox(height: 16),

                    // Location Tracking Status
                    _buildLocationTrackingStatus(
                        trackingState, currentLocation),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Error message
              if (error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(error,
                              style: TextStyle(color: Colors.red.shade700))),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            ref.read(driverErrorProvider.notifier).state = null,
                      ),
                    ],
                  ),
                ),

              // Tracking error message
              if (trackingState.error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trackingState.error!,
                          style: TextStyle(color: Colors.orange.shade700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => ref
                            .read(trackingStateProvider.notifier)
                            .clearError(),
                      ),
                    ],
                  ),
                ),

              // Statistics Section
              driverStatsAsync.when(
                data: (stats) => _buildStatsSection(stats),
                loading: () => const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => Container(
                  height: 120,
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text('Error loading stats: $error',
                        style: const TextStyle(color: Colors.red)),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Assigned Ambulances Section
              Row(
                children: [
                  Icon(Icons.local_shipping, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  const Text(
                    'My Ambulances',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Ambulances List
              driverAmbulancesAsync.when(
                data: (ambulances) {
                  if (ambulances.isEmpty) {
                    return _buildNoAmbulancesCard();
                  }
                  return _buildAmbulancesList(ambulances, trackingState);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Error loading ambulances: $error'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityToggle(bool isAvailable, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.green.shade50 : Colors.grey.shade50,
        border: Border.all(
          color: isAvailable ? Colors.green.shade200 : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isAvailable ? Colors.green : Colors.grey,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isAvailable ? Icons.work : Icons.work_off,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAvailable ? 'On Shift' : 'Off Shift',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isAvailable
                        ? Colors.green.shade700
                        : Colors.grey.shade700,
                  ),
                ),
                Text(
                  isAvailable
                      ? 'You are available for assignments'
                      : 'You are not available for assignments',
                  style: TextStyle(
                    fontSize: 12,
                    color: isAvailable
                        ? Colors.green.shade600
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isAvailable,
            onChanged: isLoading ? null : (value) => _toggleAvailability(value),
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTrackingStatus(
      TrackingState trackingState, AsyncValue<Position?> currentLocation) {
    final isTracking = trackingState.isTracking;
    final isOnline = trackingState.isOnline;
    final queuedUpdates = trackingState.queuedUpdates;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isTracking
            ? (isOnline ? Colors.blue.shade50 : Colors.orange.shade50)
            : Colors.grey.shade50,
        border: Border.all(
          color: isTracking
              ? (isOnline ? Colors.blue.shade200 : Colors.orange.shade200)
              : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isTracking
                      ? (isOnline ? Colors.blue : Colors.orange)
                      : Colors.grey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isTracking
                      ? (isOnline ? Icons.gps_fixed : Icons.gps_not_fixed)
                      : Icons.gps_off,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTracking
                          ? (isOnline
                              ? 'Location Tracking Active'
                              : 'Tracking (Offline)')
                          : 'Location Tracking Stopped',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isTracking
                            ? (isOnline
                                ? Colors.blue.shade700
                                : Colors.orange.shade700)
                            : Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      isTracking
                          ? (isOnline
                              ? 'Sending location every 30 seconds'
                              : 'Queued updates: $queuedUpdates')
                          : 'Location sharing is disabled',
                      style: TextStyle(
                        fontSize: 12,
                        color: isTracking
                            ? (isOnline
                                ? Colors.blue.shade600
                                : Colors.orange.shade600)
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isTracking && trackingState.lastUpdateTime != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Last update: ${_formatTime(trackingState.lastUpdateTime!)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
          if (currentLocation.hasValue && currentLocation.value != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Current: ${currentLocation.value!.latitude.toStringAsFixed(6)}, ${currentLocation.value!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsSection(Map<String, dynamic> stats) {
    return Row(
      children: [
        _buildStatCard(
          'Total',
          stats['totalAmbulances'].toString(),
          Colors.blue.shade700,
          Icons.local_shipping,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          'Available',
          stats['availableAmbulances'].toString(),
          Colors.green.shade700,
          Icons.check_circle,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          'On Duty',
          stats['onDutyAmbulances'].toString(),
          Colors.orange.shade700,
          Icons.emergency,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoAmbulancesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Ambulances Assigned',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contact your hospital administrator to get assigned to ambulances',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAmbulancesList(
      List<Map<String, dynamic>> ambulances, TrackingState trackingState) {
    return Column(
      children: ambulances.map((ambulanceData) {
        final ambulance = AmbulanceModel.fromMap(
          ambulanceData['id'] as String,
          ambulanceData,
        );
        return _buildAmbulanceCard(
            ambulance, trackingState, ambulances.length > 1);
      }).toList(),
    );
  }

  Widget _buildAmbulanceCard(
      AmbulanceModel ambulance, TrackingState trackingState, bool canSwitch) {
    final statusColor = Color(AmbulanceStatus.getStatusColor(ambulance.status));
    final isCurrentAmbulance = ambulance.currentDriverId == driverId;
    final isTrackedAmbulance = trackingState.ambulanceId == ambulance.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isCurrentAmbulance ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentAmbulance
            ? BorderSide(color: Colors.orange.shade700, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.local_shipping,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            ambulance.licensePlate,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isCurrentAmbulance) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade700,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'CURRENT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          if (isTrackedAmbulance) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade700,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'TRACKING',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        ambulance.model,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    ambulance.statusDisplayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (isCurrentAmbulance) ...[
              const SizedBox(height: 16),

              // Location tracking controls
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: trackingState.isLoading
                          ? null
                          : () => _toggleLocationTracking(ambulance),
                      icon: Icon(
                        trackingState.isTracking
                            ? Icons.gps_off
                            : Icons.gps_fixed,
                      ),
                      label: Text(
                        trackingState.isTracking
                            ? 'Stop Tracking'
                            : 'Start Tracking',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: trackingState.isTracking
                            ? Colors.red.shade600
                            : Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  if (trackingState.isTracking) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showStatusChangeDialog(ambulance),
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Change Status'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.orange.shade700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (canSwitch && !isCurrentAmbulance) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _switchToAmbulance(ambulance),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Switch to This Ambulance'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.orange.shade700),
                  ),
                ),
              ),
            ],
            if (isCurrentAmbulance &&
                ambulance.status == AmbulanceStatus.available &&
                !trackingState.isTracking) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Start location tracking to receive emergency assignments',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ago';
    }
  }

  Future<void> _toggleAvailability(bool isAvailable) async {
    final actions = ref.read(driverActionsProvider);
    final success = await actions.updateAvailability(driverId!, isAvailable);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isAvailable ? 'You are now on shift' : 'You are now off shift'),
          backgroundColor: isAvailable ? Colors.green : Colors.orange,
        ),
      );

      // Stop tracking if going off shift
      if (!isAvailable) {
        final trackingNotifier = ref.read(trackingStateProvider.notifier);
        await trackingNotifier.stopTracking();
      }

      // Refresh stats
      ref.refresh(driverStatsProvider(driverId!));
    }
  }

  Future<void> _toggleLocationTracking(AmbulanceModel ambulance) async {
    final trackingNotifier = ref.read(trackingStateProvider.notifier);
    final trackingState = ref.read(trackingStateProvider);

    if (trackingState.isTracking) {
      await trackingNotifier.stopTracking();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location tracking stopped'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      final success = await trackingNotifier.startTracking(
        ambulanceId: ambulance.id,
        driverId: driverId!,
        initialStatus: ambulance.status.value,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location tracking started'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showStatusChangeDialog(AmbulanceModel ambulance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Status for ${ambulance.licensePlate}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.circle, color: Colors.green),
              title: const Text('Available'),
              subtitle: const Text('Ready for emergency response'),
              onTap: () =>
                  _updateAmbulanceStatus(ambulance, AmbulanceStatus.available),
            ),
            ListTile(
              leading: Icon(Icons.circle, color: Colors.blue),
              title: const Text('On Duty'),
              subtitle: const Text('Currently responding to emergency'),
              onTap: () =>
                  _updateAmbulanceStatus(ambulance, AmbulanceStatus.onDuty),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateAmbulanceStatus(
      AmbulanceModel ambulance, AmbulanceStatus newStatus) async {
    Navigator.pop(context);

    final trackingNotifier = ref.read(trackingStateProvider.notifier);
    await trackingNotifier.updateStatus(newStatus.value);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to ${newStatus.displayName}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _switchToAmbulance(AmbulanceModel ambulance) async {
    // Find current ambulance
    final ambulancesAsync = ref.read(driverAmbulancesProvider(driverId!));
    final ambulances = ambulancesAsync.value ?? [];

    String? currentAmbulanceId;
    for (var ambulanceData in ambulances) {
      if (ambulanceData['currentDriverId'] == driverId) {
        currentAmbulanceId = ambulanceData['id'];
        break;
      }
    }

    if (currentAmbulanceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No current ambulance found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final actions = ref.read(driverActionsProvider);
    final success = await actions.switchAmbulance(
      driverId!,
      currentAmbulanceId,
      ambulance.id,
    );

    if (success && mounted) {
      // Stop current tracking and start new tracking
      final trackingNotifier = ref.read(trackingStateProvider.notifier);
      await trackingNotifier.stopTracking();

      setState(() {
        this.currentAmbulanceId = ambulance.id;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${ambulance.licensePlate}'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh data
      ref.refresh(driverAmbulancesProvider(driverId!));
      ref.refresh(driverStatsProvider(driverId!));
    }
  }

  void _showLocationSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue),
            SizedBox(width: 8),
            Text('Location Settings'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Location Tracking Information:'),
            const SizedBox(height: 12),
            _buildInfoRow('Update Interval', '30 seconds'),
            _buildInfoRow('Minimum Distance', '10 meters'),
            _buildInfoRow('Accuracy', 'High (GPS)'),
            const SizedBox(height: 16),
            const Text(
              'Background location permission is required for continuous tracking when the app is minimized.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _requestLocationPermissions();
            },
            child: const Text('Check Permissions'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Future<void> _requestLocationPermissions() async {
    final locationService = ref.read(locationServiceProvider);
    final currentLocation = await locationService.getCurrentLocation();

    if (currentLocation != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permissions are properly configured'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permissions need to be granted'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text('Sign Out'),
            ],
          ),
          content: const Text(
              'Are you sure you want to sign out? This will stop location tracking.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                try {
                  // Stop tracking before signing out to prevent errors
                  final trackingNotifier =
                      ref.read(trackingStateProvider.notifier);
                  await trackingNotifier.stopTracking();

                  // Add a small delay to ensure tracking is fully stopped
                  await Future.delayed(const Duration(milliseconds: 500));

                  final authService = ref.read(authServiceProvider);
                  await authService.signOut();

                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error signing out: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }
}
