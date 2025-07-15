// lib/screens/police_route_map_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/route_model.dart';
import '../providers/route_providers.dart';
import '../utils/polyline_decoder.dart';
import 'police_route_details_screen.dart';

class PoliceRouteMapScreen extends ConsumerStatefulWidget {
  const PoliceRouteMapScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PoliceRouteMapScreen> createState() =>
      _PoliceRouteMapScreenState();
}

class _PoliceRouteMapScreenState extends ConsumerState<PoliceRouteMapScreen> {
  GoogleMapController? _mapController;
  Timer? _refreshTimer;

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  AmbulanceRouteModel? _selectedRoute;

  // Map state
  bool _showActiveOnly = true;
  bool _showHighPriorityOnly = false;

  // Default map location (Nairobi)
  static const LatLng _defaultLocation = LatLng(-1.2921, 36.8219);

  @override
  void initState() {
    super.initState();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        ref.invalidate(allActiveRoutesProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(allActiveRoutesProvider);
    final routeStats = ref.watch(routeStatisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Route Map',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.indigo.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              ref.invalidate(allActiveRoutesProvider);
              _updateMapData();
            },
            tooltip: 'Refresh Routes',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            tooltip: 'Filter Routes',
            onSelected: (value) => _applyFilter(value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'active_only',
                child: Row(
                  children: [
                    Icon(
                      _showActiveOnly
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    const Text('Active Routes Only'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'high_priority',
                child: Row(
                  children: [
                    Icon(
                      _showHighPriorityOnly
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    const Text('High Priority Only'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick stats bar
          _buildStatsBar(routeStats),

          // Map
          Expanded(
            child: routesAsync.when(
              data: (routes) {
                _updateMapData(routes);
                return _buildMap();
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
                      onPressed: () => ref.invalidate(allActiveRoutesProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Selected route info panel
          if (_selectedRoute != null) _buildSelectedRoutePanel(),
        ],
      ),
    );
  }

  Widget _buildStatsBar(Map<String, int> stats) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          _buildStatChip('Total', stats['total'] ?? 0, Colors.indigo),
          const SizedBox(width: 8),
          _buildStatChip('Active', stats['active'] ?? 0, Colors.blue),
          const SizedBox(width: 8),
          _buildStatChip('Cleared', stats['cleared'] ?? 0, Colors.green),
          const SizedBox(width: 8),
          _buildStatChip('Critical', stats['critical'] ?? 0, Colors.red),
          const Spacer(),
          Text(
            'Last updated: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: _defaultLocation,
        zoom: 11,
      ),
      polylines: _polylines,
      markers: _markers,
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              _buildRouteInfoChip(
                icon: Icons.straighten,
                label: route.formattedDistance,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              _buildRouteInfoChip(
                icon: Icons.schedule,
                label: route.formattedETA,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              _buildRouteInfoChip(
                icon: Icons.access_time,
                label: route.formattedDuration,
                color: Colors.purple,
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => _openRouteDetails(route),
                style: ElevatedButton.styleFrom(
                  backgroundColor: priorityColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Details'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfoChip({
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

  void _updateMapData([List<AmbulanceRouteModel>? routes]) {
    if (routes == null) return;

    // Filter routes based on current filters
    var filteredRoutes = routes;

    if (_showActiveOnly) {
      filteredRoutes = filteredRoutes
          .where((route) => route.status == RouteStatus.active)
          .toList();
    }

    if (_showHighPriorityOnly) {
      filteredRoutes =
          filteredRoutes.where((route) => route.isHighPriority).toList();
    }

    // Clear existing polylines and markers
    _polylines.clear();
    _markers.clear();

    // Add route polylines and markers
    for (int i = 0; i < filteredRoutes.length; i++) {
      final route = filteredRoutes[i];

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
              width: route.status == RouteStatus.active ? 5 : 3,
              patterns: route.status == RouteStatus.active
                  ? []
                  : [PatternItem.dash(20), PatternItem.gap(10)],
              onTap: () {
                setState(() {
                  _selectedRoute = route;
                });
                _focusOnRoute(route);
              },
            ),
          );
        } catch (e) {
          print('Error decoding polyline for route ${route.id}: $e');
        }
      }

      // Add start marker (ambulance)
      _markers.add(
        Marker(
          markerId: MarkerId('start_${route.id}'),
          position: LatLng(route.startLat, route.startLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            route.status == RouteStatus.active
                ? BitmapDescriptor.hueBlue
                : BitmapDescriptor.hueGreen,
          ),
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
      );

      // Add end marker (patient location)
      _markers.add(
        Marker(
          markerId: MarkerId('end_${route.id}'),
          position: LatLng(route.endLat, route.endLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            route.emergencyPriority == 'critical'
                ? BitmapDescriptor.hueRed
                : route.emergencyPriority == 'high'
                    ? BitmapDescriptor.hueOrange
                    : BitmapDescriptor.hueGreen,
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
      );
    }

    setState(() {});

    // Auto-fit map to show all routes if this is the first load
    if (filteredRoutes.isNotEmpty && _mapController != null) {
      _fitMapToAllRoutes(filteredRoutes);
    }
  }

  void _applyFilter(String filterType) {
    setState(() {
      switch (filterType) {
        case 'active_only':
          _showActiveOnly = !_showActiveOnly;
          break;
        case 'high_priority':
          _showHighPriorityOnly = !_showHighPriorityOnly;
          break;
      }
    });

    // Refresh map data with new filters
    final routesAsync = ref.read(allActiveRoutesProvider);
    routesAsync.whenData((routes) => _updateMapData(routes));
  }

  void _focusOnRoute(AmbulanceRouteModel route) {
    if (_mapController == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        route.startLat < route.endLat ? route.startLat : route.endLat,
        route.startLng < route.endLng ? route.startLng : route.endLng,
      ),
      northeast: LatLng(
        route.startLat > route.endLat ? route.startLat : route.endLat,
        route.startLng > route.endLng ? route.startLng : route.endLng,
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  void _fitMapToAllRoutes(List<AmbulanceRouteModel> routes) {
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
  }

  void _openRouteDetails(AmbulanceRouteModel route) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PoliceRouteDetailsScreen(route: route),
      ),
    );
  }
}
