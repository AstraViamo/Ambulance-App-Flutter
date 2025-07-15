// lib/screens/enhanced_hospital_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/emergency_model.dart';
import '../models/route_model.dart';
import '../providers/auth_provider.dart';
import '../providers/emergency_providers.dart';
import '../providers/route_providers.dart';
import '../utils/polyline_decoder.dart';
import 'emergency_details_screen.dart';
import 'emergency_list_screen.dart';
import 'live_emergency_map_screen.dart';

class HospitalDashboard extends ConsumerStatefulWidget {
  const HospitalDashboard({Key? key}) : super(key: key);

  @override
  ConsumerState<HospitalDashboard> createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends ConsumerState<HospitalDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  GoogleMapController? _mapController;
  String? hospitalId;

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  AmbulanceRouteModel? _selectedRoute;

  // Default map location (Nairobi)
  static const LatLng _defaultLocation = LatLng(-1.2921, 36.8219);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHospitalId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadHospitalId() async {
    final currentUser = await ref.read(currentUserProvider.future);
    if (currentUser != null && mounted) {
      setState(() {
        hospitalId = currentUser.roleSpecificData.hospitalId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (hospitalId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final emergencyStats = ref.watch(emergencyStatsProvider(hospitalId!));
    final routeStats = ref.watch(routeStatisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hospital Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              ref.invalidate(emergencyStatsProvider);
              ref.invalidate(activeRoutesProvider);
            },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: _showNotifications,
            tooltip: 'Notifications',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Active Routes', icon: Icon(Icons.route)),
            Tab(text: 'Route Map', icon: Icon(Icons.map)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildActiveRoutesTab(),
          _buildRouteMapTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final emergencyStats = ref.watch(emergencyStatsProvider(hospitalId!));

    return emergencyStats.when(
      data: (stats) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emergency Statistics
            _buildStatsGrid(stats),
            const SizedBox(height: 24),

            // Quick Actions
            _buildQuickActionsSection(),
            const SizedBox(height: 24),

            // Recent Emergencies
            _buildRecentEmergenciesSection(),
            const SizedBox(height: 24),

            // Active Routes Summary
            _buildActiveRoutesSummary(),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(emergencyStatsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRoutesTab() {
    final activeRoutesAsync = ref.watch(activeRoutesProvider(hospitalId!));

    return activeRoutesAsync.when(
      data: (routes) {
        if (routes.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.route, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No active routes',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Active ambulance routes will appear here',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: routes.length,
          itemBuilder: (context, index) {
            final route = routes[index];
            return _buildRouteCard(route);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading routes: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(activeRoutesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteMapTab() {
    final activeRoutesAsync = ref.watch(activeRoutesProvider(hospitalId!));

    return activeRoutesAsync.when(
      data: (routes) {
        _updateMapData(routes);
        return Column(
          children: [
            // Map controls
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Text(
                    'Active Routes: ${routes.length}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => ref.invalidate(activeRoutesProvider),
                    tooltip: 'Refresh Routes',
                  ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen),
                    onPressed: _fitMapToRoutes,
                    tooltip: 'Fit to Routes',
                  ),
                ],
              ),
            ),

            // Map
            Expanded(
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _defaultLocation,
                  zoom: 11,
                ),
                polylines: _polylines,
                markers: _markers,
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                  if (routes.isNotEmpty) {
                    _fitMapToRoutes();
                  }
                },
                onTap: (_) {
                  setState(() {
                    _selectedRoute = null;
                  });
                },
                mapType: MapType.normal,
                trafficEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
              ),
            ),

            // Selected route panel
            if (_selectedRoute != null) _buildSelectedRoutePanel(),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildStatsGrid(Map<String, int> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Emergency Statistics',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Today',
              stats['todayTotal']?.toString() ?? '0',
              Colors.blue.shade700,
              Icons.today,
            ),
            _buildStatCard(
              'Active',
              stats['activeTotal']?.toString() ?? '0',
              Colors.orange.shade700,
              Icons.emergency,
            ),
            _buildStatCard(
              'Critical',
              stats['critical']?.toString() ?? '0',
              Colors.red.shade700,
              Icons.priority_high,
            ),
            _buildStatCard(
              'Completed',
              stats['completed']?.toString() ?? '0',
              Colors.green.shade700,
              Icons.check_circle,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2,
          children: [
            _buildActionCard(
              'New Emergency',
              Icons.add_alert,
              Colors.red,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmergencyListScreen(),
                ),
              ),
            ),
            _buildActionCard(
              'Live Map',
              Icons.map,
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LiveEmergencyMapScreen(),
                ),
              ),
            ),
            _buildActionCard(
              'All Emergencies',
              Icons.list,
              Colors.green,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmergencyListScreen(),
                ),
              ),
            ),
            _buildActionCard(
              'Route History',
              Icons.history,
              Colors.purple,
              () => _tabController.animateTo(1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentEmergenciesSection() {
    final recentEmergencies = ref.watch(sortedEmergenciesProvider(hospitalId!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Recent Emergencies',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmergencyListScreen(),
                ),
              ),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        recentEmergencies.when(
          data: (emergencies) {
            final recent = emergencies.take(3).toList();
            if (recent.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('No recent emergencies'),
                ),
              );
            }

            return Column(
              children: recent
                  .map((emergency) => _buildEmergencyTile(emergency))
                  .toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Text('Error: $error'),
        ),
      ],
    );
  }

  Widget _buildActiveRoutesSummary() {
    final activeRoutesAsync = ref.watch(activeRoutesProvider(hospitalId!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Active Routes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        activeRoutesAsync.when(
          data: (routes) {
            if (routes.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('No active routes'),
                ),
              );
            }

            return Column(
              children: routes
                  .take(2)
                  .map((route) => _buildRouteSummaryTile(route))
                  .toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Text('Error: $error'),
        ),
      ],
    );
  }

  Widget _buildEmergencyTile(EmergencyModel emergency) {
    final priorityColor = Color(emergency.priority.colorValue);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: priorityColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.emergency, color: priorityColor),
        ),
        title: Text(emergency.callerName),
        subtitle: Text(emergency.patientAddressString),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: priorityColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            emergency.priority.displayName,
            style: TextStyle(
              color: priorityColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmergencyDetailsScreen(emergency: emergency),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteSummaryTile(AmbulanceRouteModel route) {
    final priorityColor = route.emergencyPriority == 'critical'
        ? Colors.red
        : route.emergencyPriority == 'high'
            ? Colors.orange
            : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: priorityColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.local_hospital, color: priorityColor),
        ),
        title: Text('Ambulance ${route.ambulanceLicensePlate}'),
        subtitle: Text(route.patientLocation),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              route.formattedETA,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              route.formattedDistance,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        onTap: () => _tabController.animateTo(2),
      ),
    );
  }

  Widget _buildRouteCard(AmbulanceRouteModel route) {
    final priorityColor = route.emergencyPriority == 'critical'
        ? Colors.red
        : route.emergencyPriority == 'high'
            ? Colors.orange
            : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: priorityColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    route.emergencyPriority.toUpperCase(),
                    style: TextStyle(
                      color: priorityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ambulance ${route.ambulanceLicensePlate}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(route.status.colorValue).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(route.status.colorValue).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    route.status.displayName,
                    style: TextStyle(
                      color: Color(route.status.colorValue),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    route.patientLocation,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildRouteStatChip(
                  icon: Icons.straighten,
                  label: route.formattedDistance,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildRouteStatChip(
                  icon: Icons.schedule,
                  label: route.formattedETA,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildRouteStatChip(
                  icon: Icons.access_time,
                  label: route.formattedDuration,
                  color: Colors.purple,
                ),
              ],
            ),
            if (route.policeOfficerName != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Traffic cleared by ${route.policeOfficerName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
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

  Widget _buildRouteStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedRoutePanel() {
    if (_selectedRoute == null) return const SizedBox.shrink();

    final route = _selectedRoute!;
    final priorityColor = route.emergencyPriority == 'critical'
        ? Colors.red
        : route.emergencyPriority == 'high'
            ? Colors.orange
            : Colors.blue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: priorityColor.withOpacity(0.3)),
                ),
                child: Text(
                  route.emergencyPriority.toUpperCase(),
                  style: TextStyle(
                    color: priorityColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ambulance ${route.ambulanceLicensePlate}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedRoute = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  route.patientLocation,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildRouteStatChip(
                icon: Icons.straighten,
                label: route.formattedDistance,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              _buildRouteStatChip(
                icon: Icons.schedule,
                label: route.formattedETA,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              _buildRouteStatChip(
                icon: Icons.access_time,
                label: route.formattedDuration,
                color: Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateMapData(List<AmbulanceRouteModel> routes) {
    _polylines.clear();
    _markers.clear();

    for (final route in routes) {
      // Decode and add polyline
      if (route.encodedPolyline.isNotEmpty) {
        try {
          final points = PolylineDecoder.decode(route.encodedPolyline);
          final polylineColor = route.emergencyPriority == 'critical'
              ? Colors.red
              : route.emergencyPriority == 'high'
                  ? Colors.orange
                  : Colors.blue;

          _polylines.add(
            Polyline(
              polylineId: PolylineId('route_${route.id}'),
              points: points
                  .map((point) => LatLng(point.latitude, point.longitude))
                  .toList(),
              color: polylineColor,
              width: 5,
              patterns: route.status == RouteStatus.active
                  ? []
                  : [PatternItem.dash(20), PatternItem.gap(10)],
              onTap: () {
                setState(() {
                  _selectedRoute = route;
                });
              },
            ),
          );
        } catch (e) {
          print('Error decoding polyline: $e');
        }
      }

      // Add markers
      _markers.addAll({
        Marker(
          markerId: MarkerId('start_${route.id}'),
          position: LatLng(route.startLat, route.startLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: 'Ambulance ${route.ambulanceLicensePlate}',
            snippet: 'Status: ${route.status.displayName}',
          ),
          onTap: () {
            setState(() {
              _selectedRoute = route;
            });
          },
        ),
        Marker(
          markerId: MarkerId('end_${route.id}'),
          position: LatLng(route.endLat, route.endLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            route.emergencyPriority == 'critical'
                ? BitmapDescriptor.hueRed
                : BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: '${route.emergencyPriority.toUpperCase()} Emergency',
            snippet: route.patientLocation,
          ),
          onTap: () {
            setState(() {
              _selectedRoute = route;
            });
          },
        ),
      });
    }

    if (mounted) setState(() {});
  }

  void _fitMapToRoutes() {
    final activeRoutesAsync = ref.read(activeRoutesProvider(hospitalId!));

    activeRoutesAsync.whenData((routes) {
      if (_mapController == null || routes.isEmpty) return;

      double minLat = routes.first.startLat;
      double maxLat = routes.first.startLat;
      double minLng = routes.first.startLng;
      double maxLng = routes.first.startLng;

      for (final route in routes) {
        minLat = [minLat, route.startLat, route.endLat]
            .reduce((a, b) => a < b ? a : b);
        maxLat = [maxLat, route.startLat, route.endLat]
            .reduce((a, b) => a > b ? a : b);
        minLng = [minLng, route.startLng, route.endLng]
            .reduce((a, b) => a < b ? a : b);
        maxLng = [maxLng, route.startLng, route.endLng]
            .reduce((a, b) => a > b ? a : b);
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    });
  }

  void _showNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notifications feature coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
