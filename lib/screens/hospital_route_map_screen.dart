// lib/screens/hospital_route_map_screen.dart
import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/route_model.dart';
import '../providers/route_providers.dart';
import '../utils/polyline_decoder.dart';
import 'route_details_screen.dart';

class HospitalRouteMapScreen extends ConsumerStatefulWidget {
  final String hospitalId;

  const HospitalRouteMapScreen({
    Key? key,
    required this.hospitalId,
  }) : super(key: key);

  @override
  ConsumerState<HospitalRouteMapScreen> createState() =>
      _HospitalRouteMapScreenState();
}

class _HospitalRouteMapScreenState
    extends ConsumerState<HospitalRouteMapScreen> {
  GoogleMapController? _mapController;
  Timer? _refreshTimer;

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  AmbulanceRouteModel? _selectedRoute;

  // Map state
  bool _showActiveOnly = true;
  bool _showCompletedRoutes = false;
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
        ref.invalidate(hospitalRoutesProvider);
        ref.invalidate(hospitalActiveRoutesProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hospitalStats =
        ref.watch(hospitalRouteStatisticsProvider(widget.hospitalId));
    final routesAsync = _showActiveOnly
        ? ref.watch(hospitalActiveRoutesProvider(widget.hospitalId))
        : ref.watch(hospitalRoutesProvider(widget.hospitalId));

    return Scaffold(
      body: Column(
        children: [
          // Header with statistics
          _buildHeader(hospitalStats),

          // Map
          Expanded(
            child: Stack(
              children: [
                // Google Map
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: const CameraPosition(
                    target: _defaultLocation,
                    zoom: 12.0,
                  ),
                  polylines: _polylines,
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                  trafficEnabled: true,
                  buildingsEnabled: true,
                  mapType: MapType.normal,
                  onTap: (_) => setState(() => _selectedRoute = null),
                ),

                // Filter controls
                Positioned(
                  top: 16,
                  right: 16,
                  child: _buildFilterControls(),
                ),

                // Route details panel
                if (_selectedRoute != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildRouteDetailsPanel(_selectedRoute!),
                  ),

                // Loading overlay
                routesAsync.when(
                  data: (routes) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _updateMapData(routes);
                    });
                    return const SizedBox.shrink();
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stack) => Center(
                    child: Card(
                      margin: const EdgeInsets.all(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error,
                                color: Colors.red, size: 48),
                            const SizedBox(height: 8),
                            Text('Error loading routes: $error'),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () {
                                ref.invalidate(hospitalRoutesProvider);
                                ref.invalidate(hospitalActiveRoutesProvider);
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Center on routes button
          FloatingActionButton(
            heroTag: 'center',
            onPressed: _centerOnAllRoutes,
            backgroundColor: Colors.red.shade700,
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
          const SizedBox(height: 8),
          // Refresh button
          FloatingActionButton(
            heroTag: 'refresh',
            onPressed: () {
              ref.invalidate(hospitalRoutesProvider);
              ref.invalidate(hospitalActiveRoutesProvider);
              _updateMapData([]);
            },
            backgroundColor: Colors.blue.shade700,
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Map<String, int> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.map, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Route Map',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  'Updated: ${DateTime.now().toString().substring(11, 19)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatChip('Total', stats['total'] ?? 0, Colors.white),
                  const SizedBox(width: 8),
                  _buildStatChip(
                      'Active', stats['active'] ?? 0, Colors.orange.shade200),
                  const SizedBox(width: 8),
                  _buildStatChip(
                      'En Route', stats['enRoute'] ?? 0, Colors.blue.shade200),
                  const SizedBox(width: 8),
                  _buildStatChip(
                      'Cleared', stats['cleared'] ?? 0, Colors.green.shade200),
                  const SizedBox(width: 8),
                  _buildStatChip(
                      'Critical', stats['critical'] ?? 0, Colors.red.shade200),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color == Colors.white
                  ? Colors.red.shade700
                  : Colors.red.shade700,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color == Colors.white
                  ? Colors.red.shade700
                  : Colors.red.shade700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterControls() {
    return Column(
      children: [
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title:
                    const Text('Active Only', style: TextStyle(fontSize: 14)),
                value: _showActiveOnly,
                onChanged: (value) {
                  setState(() => _showActiveOnly = value);
                },
                dense: true,
                activeColor: Colors.red.shade700,
              ),
              SwitchListTile(
                title: const Text('Show Completed',
                    style: TextStyle(fontSize: 14)),
                value: _showCompletedRoutes,
                onChanged: (value) {
                  setState(() => _showCompletedRoutes = value);
                },
                dense: true,
                activeColor: Colors.green.shade700,
              ),
              SwitchListTile(
                title: const Text('High Priority Only',
                    style: TextStyle(fontSize: 14)),
                value: _showHighPriorityOnly,
                onChanged: (value) {
                  setState(() => _showHighPriorityOnly = value);
                },
                dense: true,
                activeColor: Colors.orange.shade700,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRouteDetailsPanel(AmbulanceRouteModel route) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_shipping,
                  color: Color(route.status.colorValue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.ambulanceLicensePlate,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        route.status.displayName,
                        style: TextStyle(
                          color: Color(route.status.colorValue),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: route.isHighPriority ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    route.emergencyPriority.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Destination: ${route.patientLocation}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.straighten, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  route.formattedDistance,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  route.formattedDuration,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (route.status != RouteStatus.completed) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.timer, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'ETA: ${route.formattedETA}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _selectedRoute = null),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openRouteDetails(route),
                    icon: const Icon(Icons.info, size: 16),
                    label: const Text('Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
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

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _updateMapData(List<AmbulanceRouteModel> routes) {
    if (_mapController == null) return;

    // Apply filters
    List<AmbulanceRouteModel> filteredRoutes = routes.where((route) {
      // Filter by active status
      if (_showActiveOnly && !route.status.isActiveForHospital) return false;

      // Filter by completed status
      if (!_showCompletedRoutes && route.status == RouteStatus.completed)
        return false;

      // Filter by priority
      if (_showHighPriorityOnly && !route.isHighPriority) return false;

      return true;
    }).toList();

    _polylines.clear();
    _markers.clear();

    for (final route in filteredRoutes) {
      try {
        // Add route polyline using existing PolylineDecoder
        final polylinePoints = PolylineDecoder.decode(route.encodedPolyline);
        final polyline = Polyline(
          polylineId: PolylineId(route.id),
          points: polylinePoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList(),
          color: _getRouteColor(route),
          width: route.isHighPriority ? 6 : 4,
          patterns: route.status == RouteStatus.completed
              ? [PatternItem.dash(10), PatternItem.gap(5)]
              : [],
        );
        _polylines.add(polyline);

        // Add start marker (ambulance position)
        final startMarker = Marker(
          markerId: MarkerId('${route.id}_start'),
          position: LatLng(route.startLat, route.startLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            route.status == RouteStatus.active
                ? BitmapDescriptor.hueBlue
                : route.status == RouteStatus.cleared
                    ? BitmapDescriptor.hueGreen
                    : BitmapDescriptor.hueCyan,
          ),
          infoWindow: InfoWindow(
            title: 'Ambulance ${route.ambulanceLicensePlate}',
            snippet: '${route.status.displayName} • ${route.formattedETA}',
          ),
          onTap: () {
            setState(() {
              _selectedRoute = route;
            });
          },
        );
        _markers.add(startMarker);

        // Add destination marker (patient location)
        final endMarker = Marker(
          markerId: MarkerId('${route.id}_end'),
          position: LatLng(route.endLat, route.endLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            route.emergencyPriority == 'critical'
                ? BitmapDescriptor.hueRed
                : route.emergencyPriority == 'high'
                    ? BitmapDescriptor.hueOrange
                    : BitmapDescriptor.hueYellow,
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
        );
        _markers.add(endMarker);
      } catch (e) {
        log('Error processing route ${route.id}: $e');
      }
    }

    setState(() {});

    // Auto-fit map to show all routes if this is the first load
    if (filteredRoutes.isNotEmpty && _mapController != null) {
      _fitMapToAllRoutes(filteredRoutes);
    }
  }

  Color _getRouteColor(AmbulanceRouteModel route) {
    if (route.status == RouteStatus.completed) {
      return Colors.grey;
    } else if (route.isHighPriority) {
      return route.status == RouteStatus.cleared ? Colors.green : Colors.red;
    } else {
      return route.status == RouteStatus.cleared
          ? Colors.lightGreen
          : Colors.orange;
    }
  }

  void _centerOnAllRoutes() {
    final routesAsync = _showActiveOnly
        ? ref.read(hospitalActiveRoutesProvider(widget.hospitalId))
        : ref.read(hospitalRoutesProvider(widget.hospitalId));

    routesAsync.whenData((routes) {
      final filteredRoutes = routes.where((route) {
        if (_showActiveOnly && !route.status.isActiveForHospital) return false;
        if (!_showCompletedRoutes && route.status == RouteStatus.completed)
          return false;
        if (_showHighPriorityOnly && !route.isHighPriority) return false;
        return true;
      }).toList();

      _fitMapToAllRoutes(filteredRoutes);
    });
  }

  void _fitMapToAllRoutes(List<AmbulanceRouteModel> routes) {
    if (_mapController == null || routes.isEmpty) {
      // If no routes, center on default location
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_defaultLocation, 12.0),
      );
      return;
    }

    if (routes.length == 1) {
      // If only one route, focus on that route
      final route = routes.first;
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
      return;
    }

    // Multiple routes - calculate bounds to include all
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

    // Add some padding
    const padding = 0.01;
    final bounds = LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  void _openRouteDetails(AmbulanceRouteModel route) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteDetailsScreen(route: route),
      ),
    );
  }
}
