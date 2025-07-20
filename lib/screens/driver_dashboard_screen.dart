// lib/screens/driver_dashboard_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/route_model.dart';
import '../providers/auth_provider.dart';
import '../providers/location_providers.dart';
import '../providers/route_providers.dart';
import 'driver_navigation_screen.dart';
import 'login_screen.dart';
import 'route_details_screen.dart';

class DriverDashboardScreen extends ConsumerStatefulWidget {
  const DriverDashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DriverDashboardScreen> createState() =>
      _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends ConsumerState<DriverDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _locationTimer;
  Position? _currentPosition;
  String? driverId;
  String? _currentAmbulanceId;
  AmbulanceRouteModel? _currentRoute;
  List<AmbulanceRouteModel> _routeHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCurrentRoute();
    _loadRouteHistory();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentRoute() async {
    try {
      final currentUser = ref.read(currentUserProvider);
      await currentUser.when(
        data: (user) async {
          if (user != null) {
            driverId = user.id;
            _currentAmbulanceId =
                user.roleSpecificData.assignedAmbulances?.isNotEmpty == true
                    ? user.roleSpecificData.assignedAmbulances!.first
                    : null;
            // Get current active route for this driver
            final currentRouteStream =
                ref.read(currentRouteForDriverProvider(user.id));
            currentRouteStream.when(
              data: (route) {
                if (mounted) {
                  setState(() {
                    _currentRoute = route;
                  });
                }
              },
              loading: () {},
              error: (error, stack) {
                print('Error loading current route: $error');
              },
            );
          }
        },
        loading: () {},
        error: (error, stack) {
          print('Error getting current user: $error');
        },
      );
    } catch (e) {
      print('Error loading current route: $e');
    }
  }

  Future<void> _loadRouteHistory() async {
    try {
      if (driverId != null) {
        final historyStream = ref.read(driverRouteHistoryProvider(driverId!));
        historyStream.when(
          data: (routes) {
            if (mounted) {
              setState(() {
                _routeHistory = routes;
              });
            }
          },
          loading: () {},
          error: (error, stack) {
            print('Error loading route history: $error');
          },
        );
      }
    } catch (e) {
      print('Error loading route history: $e');
    }
  }

  void _startLocationUpdates() {
    _updateLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateLocation();
    });
  }

  Future<void> _updateLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestPermission = await Geolocator.requestPermission();
        if (requestPermission == LocationPermission.denied) {
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });

        // Update location in provider
        if (driverId != null) {
          final trackingNotifier = ref.read(trackingStateProvider.notifier);
          final trackingState = ref.read(trackingStateProvider);

          // If not already tracking, start tracking
          if (!trackingState.isTracking && _currentAmbulanceId != null) {
            await trackingNotifier.startTracking(
              ambulanceId: _currentAmbulanceId!,
              driverId: driverId!,
              initialStatus: 'available',
            );
          }
          // Location updates will happen automatically when tracking is active
        }
      }
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final trackingState = ref.watch(trackingStateProvider);

    return currentUser.when(
      data: (user) {
        if (user == null) {
          return const LoginScreen();
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Driver Dashboard',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.orange.shade700,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  _loadCurrentRoute();
                  _loadRouteHistory();
                  _updateLocation();
                },
                tooltip: 'Refresh',
              ),
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () => _showNotifications(),
                tooltip: 'Notifications',
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.person, color: Colors.white),
                onSelected: (value) async {
                  if (value == 'logout') {
                    _showLogoutDialog(context, ref);
                  } else if (value == 'settings') {
                    _showComingSoon(context, 'Settings');
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Settings'),
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
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
                Tab(text: 'Current Route', icon: Icon(Icons.route)),
                Tab(text: 'Navigation', icon: Icon(Icons.navigation)),
                Tab(text: 'History', icon: Icon(Icons.history)),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(user, trackingState),
              _buildCurrentRouteTab(),
              _buildNavigationTab(),
              _buildHistoryTab(),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(currentUserProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(dynamic user, dynamic trackingState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Driver Status Card
          _buildDriverStatusCard(user, trackingState),
          const SizedBox(height: 16),

          // Current Route Summary
          if (_currentRoute != null) ...[
            _buildCurrentRouteSummary(),
            const SizedBox(height: 16),
          ],

          // Quick Actions
          _buildQuickActions(),
          const SizedBox(height: 16),

          // Location Status
          _buildLocationStatusCard(),
        ],
      ),
    );
  }

  Widget _buildDriverStatusCard(dynamic user, dynamic trackingState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.orange.shade100,
                  child: Icon(
                    Icons.local_shipping,
                    color: Colors.orange.shade700,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${user.firstName} ${user.lastName}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Ambulance Driver',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _currentRoute != null
                        ? Colors.green.shade100
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _currentRoute != null ? 'On Route' : 'Available',
                    style: TextStyle(
                      color: _currentRoute != null
                          ? Colors.green.shade700
                          : Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentRouteSummary() {
    if (_currentRoute == null) return Container();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Current Route',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emergency ID: ${_currentRoute!.emergencyId}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status: ${_currentRoute!.status.name}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _navigateToRoute(),
                      icon: const Icon(Icons.navigation),
                      label: const Text('Navigate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showRouteDetails(),
                      icon: const Icon(Icons.info, size: 16),
                      label: const Text('Details'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'Emergency Call',
                icon: Icons.emergency,
                color: Colors.red,
                onTap: () => _callEmergency(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title: 'Dispatch',
                icon: Icons.headset_mic,
                color: Colors.blue,
                onTap: () => _contactDispatch(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'Report Issue',
                icon: Icons.report_problem,
                color: Colors.orange,
                onTap: () => _reportIssue(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title:
                    _currentRoute != null ? 'Complete Route' : 'Go Available',
                icon: _currentRoute != null ? Icons.flag : Icons.check_circle,
                color: Colors.green,
                onTap: () =>
                    _currentRoute != null ? _completeRoute() : _goAvailable(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.green.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Location Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_currentPosition != null) ...[
              _buildLocationItem(
                'Latitude',
                _currentPosition!.latitude.toStringAsFixed(6),
                Icons.my_location,
              ),
              _buildLocationItem(
                'Longitude',
                _currentPosition!.longitude.toStringAsFixed(6),
                Icons.location_on,
              ),
              _buildLocationItem(
                'Accuracy',
                '${_currentPosition!.accuracy.toStringAsFixed(1)}m',
                Icons.gps_fixed,
              ),
              _buildLocationItem(
                'Last Updated',
                _formatTime(DateTime.now()),
                Icons.access_time,
              ),
            ] else ...[
              Row(
                children: [
                  Icon(Icons.gps_off, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Location not available',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildCurrentRouteTab() {
    if (_currentRoute == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.route,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Route',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You will see your current emergency route here when assigned',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRouteDetailsCard(),
          const SizedBox(height: 16),
          _buildRouteActions(),
        ],
      ),
    );
  }

  Widget _buildRouteDetailsCard() {
    if (_currentRoute == null) return Container();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Route Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRouteInfoRow('Emergency ID', _currentRoute!.emergencyId),
            _buildRouteInfoRow('Status', _currentRoute!.status.value),
            _buildRouteInfoRow(
                'Created', _formatTime(_currentRoute!.createdAt)),
            if (_currentRoute!.estimatedArrival != null)
              _buildRouteInfoRow(
                  'ETA', _formatTime(_currentRoute!.estimatedArrival!)),
            if (_currentRoute!.patientLocation.isNotEmpty)
              _buildRouteInfoRow('Destination', _currentRoute!.patientLocation),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Route Actions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _navigateToRoute(),
                icon: const Icon(Icons.navigation),
                label: const Text('Navigate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _contactDispatch(),
                icon: const Icon(Icons.headset_mic),
                label: const Text('Dispatch'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_currentRoute!.status != RouteStatus.completed)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _completeRoute(),
              icon: const Icon(Icons.flag),
              label: const Text('Mark as Arrived'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
      ],
    );
  }

  // FIXED: Add missing _buildNavigationTab method
  Widget _buildNavigationTab() {
    if (_currentRoute == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.navigation,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Route',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Navigation will be available when you have an active route',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.navigation, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        'Turn-by-Turn Navigation',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map,
                            size: 48,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Map View Coming Soon',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openExternalNavigation(),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open in Maps'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _shareLocation(),
                          icon: const Icon(Icons.share_location),
                          label: const Text('Share Location'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Route Progress',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_currentPosition != null) ...[
                    LinearProgressIndicator(
                      value:
                          0.3, // This would be calculated based on actual route progress
                      backgroundColor: Colors.grey.shade300,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '30% Complete', // This would be calculated
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ] else ...[
                    Text(
                      'Location required for progress tracking',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // FIXED: Add missing _buildHistoryTab method
  Widget _buildHistoryTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search route history...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _loadRouteHistory(),
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: _routeHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Route History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your completed routes will appear here',
                        style: TextStyle(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _routeHistory.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final route = _routeHistory[index];
                    return _buildRouteHistoryCard(route);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRouteHistoryCard(AmbulanceRouteModel route) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Icon(
            Icons.check,
            color: Colors.green.shade700,
          ),
        ),
        title: Text('Emergency ${route.emergencyId}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Completed: ${_formatTime(route.updatedAt)}'),
            if (route.estimatedArrival != null)
              Text(
                  'Duration: ${_calculateDuration(route.createdAt, route.estimatedArrival!)}'),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () => _showRouteDetailsDialog(route),
        ),
        onTap: () => _showRouteDetailsDialog(route),
      ),
    );
  }

  // Action methods
  void _navigateToRoute() {
    if (_currentRoute != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DriverNavigationScreen(route: _currentRoute!),
        ),
      );
    }
  }

  void _showRouteDetails() {
    if (_currentRoute != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RouteDetailsScreen(route: _currentRoute!),
        ),
      );
    }
  }

  void _showRouteDetailsDialog(AmbulanceRouteModel route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Route Details - ${route.emergencyId}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogInfoRow('Status', route.status.name),
            _buildDialogInfoRow('Created', _formatTime(route.createdAt)),
            _buildDialogInfoRow('Updated', _formatTime(route.updatedAt)),
            if (route.estimatedArrival != null)
              _buildDialogInfoRow(
                  'Completed', _formatTime(route.estimatedArrival!)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (route.status != RouteStatus.completed)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RouteDetailsScreen(route: route),
                  ),
                );
              },
              child: const Text('View Details'),
            ),
        ],
      ),
    );
  }

  Widget _buildDialogInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _openExternalNavigation() {
    // This would open external navigation apps like Google Maps
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening external navigation...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareLocation() {
    if (_currentPosition != null) {
      // This would share the current location
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location shared: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _callEmergency() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Call'),
        content:
            const Text('Are you sure you want to call emergency services?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement actual emergency call functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Calling emergency services...')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Call', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _contactDispatch() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Dispatch'),
        content: const Text('Would you like to contact the dispatch center?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement dispatch contact functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contacting dispatch...')),
              );
            },
            child: const Text('Contact'),
          ),
        ],
      ),
    );
  }

  void _reportIssue() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('What type of issue would you like to report?'),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showIssueForm('Vehicle Problem');
                  },
                  child: const Text('Vehicle Problem'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showIssueForm('Traffic Issue');
                  },
                  child: const Text('Traffic Issue'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showIssueForm('Route Problem');
                  },
                  child: const Text('Route Problem'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showIssueForm('Other');
                  },
                  child: const Text('Other'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showIssueForm(String issueType) {
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Report $issueType'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Issue Type: $issueType'),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Please describe the issue...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement issue reporting functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$issueType reported successfully')),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _completeRoute() {
    if (_currentRoute == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Route'),
        content: const Text(
            'Are you sure you want to mark this route as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();

              try {
                final currentUser = await ref.read(currentUserProvider.future);
                if (currentUser == null) return;

                // Update route status to completed
                await ref
                    .read(routeStatusUpdateProvider.notifier)
                    .updateRouteStatus(
                      routeId: _currentRoute!.id,
                      newStatus: RouteStatus.completed,
                      policeOfficerId: currentUser.id,
                      policeOfficerName:
                          '${currentUser.firstName} ${currentUser.lastName}',
                      notes: 'Route completed by driver',
                    );

                setState(() {
                  _currentRoute = null;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Route completed successfully')),
                );

                // Refresh route history
                _loadRouteHistory();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error completing route: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child:
                const Text('Complete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _goAvailable() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go Available'),
        content:
            const Text('Mark yourself as available for new emergency routes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement go available functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('You are now available for routes')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Go Available',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsScreen(),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature coming soon!')),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                // ✅ Use AuthService directly for sign out
                final authService = ref.read(authServiceProvider);
                await authService.signOut();
              } catch (e) {
                // Handle sign out error
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error signing out: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String _calculateDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

// Create NotificationsScreen if it doesn't exist
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No notifications',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'You\'ll see important updates here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
