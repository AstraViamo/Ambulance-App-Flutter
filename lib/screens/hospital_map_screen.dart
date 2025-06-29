// lib/screens/hospital_map_screen.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/ambulance_model.dart';
import '../providers/auth_provider.dart';
import '../providers/location_providers.dart';

class HospitalMapScreen extends ConsumerStatefulWidget {
  const HospitalMapScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HospitalMapScreen> createState() => _HospitalMapScreenState();
}

class _HospitalMapScreenState extends ConsumerState<HospitalMapScreen> {
  GoogleMapController? _mapController;
  String? hospitalId;
  Timer? _refreshTimer;

  // Map state
  final Set<Marker> _markers = {};
  final Map<String, BitmapDescriptor> _markerIcons = {};
  bool _isMapReady = false;
  bool _showAllAmbulances = true;
  AmbulanceStatus? _filterStatus;

  // Clustering
  double _currentZoom = 12.0;
  final double _clusterZoomThreshold = 12.0;

  // Default map location (Nairobi)
  static const LatLng _defaultLocation = LatLng(-1.2921, 36.8219);

  @override
  void initState() {
    super.initState();
    _loadHospitalId();
    _initializeMarkerIcons();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadHospitalId() async {
    final currentUser = await ref.read(currentUserProvider.future);
    if (currentUser != null) {
      setState(() {
        hospitalId = currentUser.roleSpecificData.hospitalId;
      });
    }
  }

  Future<void> _initializeMarkerIcons() async {
    // Create custom marker icons for different ambulance statuses
    _markerIcons[AmbulanceStatus.available.value] =
        await _createMarkerIcon(Colors.green, Icons.local_shipping);
    _markerIcons[AmbulanceStatus.onDuty.value] =
        await _createMarkerIcon(Colors.blue, Icons.emergency);
    _markerIcons[AmbulanceStatus.maintenance.value] =
        await _createMarkerIcon(Colors.orange, Icons.build);
    _markerIcons[AmbulanceStatus.offline.value] =
        await _createMarkerIcon(Colors.grey, Icons.local_shipping);
    _markerIcons['stale'] = await _createMarkerIcon(Colors.red, Icons.warning);
  }

  Future<BitmapDescriptor> _createMarkerIcon(Color color, IconData icon) async {
    // In a real implementation, you would create custom marker icons
    // For now, we'll use the default markers with different colors
    switch (color) {
      case Colors.green:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case Colors.blue:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case Colors.orange:
        return BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange);
      case Colors.red:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_isMapReady && hospitalId != null) {
        _updateMarkers();
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    setState(() {
      _isMapReady = true;
    });

    if (hospitalId != null) {
      _updateMarkers();
    }
  }

  void _onCameraMove(CameraPosition position) {
    _currentZoom = position.zoom;

    // Update map bounds for optimization
    ref.read(mapBoundsProvider.notifier).state = MapBounds(
      northEast: MapLatLng(
        position.target.latitude + 0.01,
        position.target.longitude + 0.01,
      ),
      southWest: MapLatLng(
        position.target.latitude - 0.01,
        position.target.longitude - 0.01,
      ),
    );
  }

  Future<void> _updateMarkers() async {
    if (!_isMapReady || hospitalId == null) return;

    final ambulanceLocationsAsync =
        ref.read(ambulanceLocationsProvider(hospitalId!));

    ambulanceLocationsAsync.when(
      data: (ambulances) {
        _createMarkersFromAmbulances(ambulances);
      },
      loading: () {},
      error: (error, stack) {
        debugPrint('Error loading ambulance locations: $error');
      },
    );
  }

  void _createMarkersFromAmbulances(List<AmbulanceLocation> ambulances) {
    final newMarkers = <Marker>{};

    // Filter ambulances based on current filter
    final filteredAmbulances = ambulances.where((ambulance) {
      if (!_showAllAmbulances && _filterStatus != null) {
        return ambulance.status == _filterStatus;
      }
      return ambulance.hasLocation;
    }).toList();

    // Check if we need clustering
    if (_currentZoom < _clusterZoomThreshold &&
        filteredAmbulances.length > 10) {
      _createClusteredMarkers(filteredAmbulances, newMarkers);
    } else {
      _createIndividualMarkers(filteredAmbulances, newMarkers);
    }

    setState(() {
      _markers.clear();
      _markers.addAll(newMarkers);
    });
  }

  void _createIndividualMarkers(
      List<AmbulanceLocation> ambulances, Set<Marker> markers) {
    final now = DateTime.now();
    const staleThreshold = Duration(minutes: 2);

    for (final ambulance in ambulances) {
      if (!ambulance.hasLocation) continue;

      final isStale = ambulance.lastLocationUpdate != null &&
          now.difference(ambulance.lastLocationUpdate!) > staleThreshold;

      final markerId = MarkerId(ambulance.id);
      final position = LatLng(ambulance.latitude!, ambulance.longitude!);

      // Choose appropriate icon
      BitmapDescriptor icon;
      if (isStale) {
        icon = _markerIcons['stale'] ?? BitmapDescriptor.defaultMarker;
      } else {
        icon = _markerIcons[ambulance.status.value] ??
            BitmapDescriptor.defaultMarker;
      }

      final marker = Marker(
        markerId: markerId,
        position: position,
        icon: icon,
        infoWindow: InfoWindow(
          title: ambulance.licensePlate,
          snippet:
              '${ambulance.statusDisplayName} • ${ambulance.lastUpdateFormatted}',
          onTap: () => _showAmbulanceDetails(ambulance),
        ),
        rotation: ambulance.heading ?? 0.0,
        onTap: () => _onMarkerTapped(ambulance),
      );

      markers.add(marker);
    }
  }

  void _createClusteredMarkers(
      List<AmbulanceLocation> ambulances, Set<Marker> markers) {
    // Simple clustering algorithm - group ambulances by grid cells
    const double clusterDistance = 0.01; // Approximately 1km
    final Map<String, List<AmbulanceLocation>> clusters = {};

    for (final ambulance in ambulances) {
      if (!ambulance.hasLocation) continue;

      final clusterKey =
          '${(ambulance.latitude! / clusterDistance).floor()}_${(ambulance.longitude! / clusterDistance).floor()}';

      clusters.putIfAbsent(clusterKey, () => []).add(ambulance);
    }

    clusters.forEach((key, clusterAmbulances) {
      if (clusterAmbulances.length == 1) {
        // Single ambulance - create regular marker
        _createIndividualMarkers(clusterAmbulances, markers);
      } else {
        // Multiple ambulances - create cluster marker
        final centerLat =
            clusterAmbulances.map((a) => a.latitude!).reduce((a, b) => a + b) /
                clusterAmbulances.length;
        final centerLng =
            clusterAmbulances.map((a) => a.longitude!).reduce((a, b) => a + b) /
                clusterAmbulances.length;

        final marker = Marker(
          markerId: MarkerId('cluster_$key'),
          position: LatLng(centerLat, centerLng),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          infoWindow: InfoWindow(
            title: 'Ambulance Cluster',
            snippet: '${clusterAmbulances.length} ambulances',
            onTap: () => _showClusterDetails(clusterAmbulances),
          ),
          onTap: () => _onClusterTapped(clusterAmbulances),
        );

        markers.add(marker);
      }
    });
  }

  void _onMarkerTapped(AmbulanceLocation ambulance) {
    _showAmbulanceBottomSheet(ambulance);
  }

  void _onClusterTapped(List<AmbulanceLocation> ambulances) {
    _showClusterBottomSheet(ambulances);
  }

  void _showAmbulanceBottomSheet(AmbulanceLocation ambulance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => AmbulanceDetailsBottomSheet(ambulance: ambulance),
    );
  }

  void _showClusterBottomSheet(List<AmbulanceLocation> ambulances) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ClusterDetailsBottomSheet(ambulances: ambulances),
    );
  }

  void _showAmbulanceDetails(AmbulanceLocation ambulance) {
    // Navigate to detailed ambulance view or show dialog
    _showAmbulanceBottomSheet(ambulance);
  }

  void _showClusterDetails(List<AmbulanceLocation> ambulances) {
    _showClusterBottomSheet(ambulances);
  }

  void _centerOnAmbulances() {
    if (hospitalId == null || !_isMapReady) return;

    final ambulanceLocationsAsync =
        ref.read(ambulanceLocationsProvider(hospitalId!));

    ambulanceLocationsAsync.whenData((ambulances) {
      final validAmbulances = ambulances.where((a) => a.hasLocation).toList();

      if (validAmbulances.isEmpty) {
        // Center on default location
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_defaultLocation, 12.0),
        );
        return;
      }

      if (validAmbulances.length == 1) {
        // Center on single ambulance
        final ambulance = validAmbulances.first;
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(ambulance.latitude!, ambulance.longitude!),
            16.0,
          ),
        );
        return;
      }

      // Calculate bounds for multiple ambulances
      double minLat = validAmbulances.first.latitude!;
      double maxLat = validAmbulances.first.latitude!;
      double minLng = validAmbulances.first.longitude!;
      double maxLng = validAmbulances.first.longitude!;

      for (final ambulance in validAmbulances) {
        minLat = math.min(minLat, ambulance.latitude!);
        maxLat = math.max(maxLat, ambulance.latitude!);
        minLng = math.min(minLng, ambulance.longitude!);
        maxLng = math.max(maxLng, ambulance.longitude!);
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat - 0.01, minLng - 0.01),
        northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
      );

      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (hospitalId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ambulance Tracking',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.blue.shade700,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final ambulanceLocationsAsync =
        ref.watch(ambulanceLocationsProvider(hospitalId!));
    final locationStats = ref.watch(locationStatsProvider(hospitalId!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Ambulance Tracking',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Filter button
          IconButton(
            icon: Icon(
              _showAllAmbulances ? Icons.filter_list : Icons.filter_list_alt,
              color: Colors.white,
            ),
            onPressed: _showFilterDialog,
          ),
          // Center on ambulances button
          IconButton(
            icon: const Icon(Icons.center_focus_strong, color: Colors.white),
            onPressed: _centerOnAmbulances,
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _updateMarkers(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics bar
          locationStats.when(
            data: (stats) => _buildStatsBar(stats),
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => Container(
              height: 60,
              color: Colors.red.shade100,
              child: Center(
                child: Text('Error loading stats: $error'),
              ),
            ),
          ),

          // Map
          Expanded(
            child: ambulanceLocationsAsync.when(
              data: (ambulances) => _buildMap(ambulances),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 64, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text('Error loading ambulances: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          ref.refresh(ambulanceLocationsProvider(hospitalId!)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "center",
            mini: true,
            onPressed: _centerOnAmbulances,
            backgroundColor: Colors.blue.shade700,
            child: const Icon(Icons.center_focus_strong, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "refresh",
            mini: true,
            onPressed: () => _updateMarkers(),
            backgroundColor: Colors.green.shade700,
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(LocationStats stats) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.blue.shade200)),
      ),
      child: Row(
        children: [
          _buildStatChip(
            'Total: ${stats.totalAmbulances}',
            Colors.blue.shade700,
            Icons.local_shipping,
          ),
          const SizedBox(width: 12),
          _buildStatChip(
            'Tracked: ${stats.activelyTracked}',
            Colors.green.shade700,
            Icons.gps_fixed,
          ),
          const SizedBox(width: 12),
          _buildStatChip(
            'Stale: ${stats.staleLocations}',
            Colors.orange.shade700,
            Icons.warning,
          ),
          const Spacer(),
          Text(
            'Updated: ${DateTime.now().toString().substring(11, 19)}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String text, Color color, IconData icon) {
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
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(List<AmbulanceLocation> ambulances) {
    return GoogleMap(
      onMapCreated: _onMapCreated,
      onCameraMove: _onCameraMove,
      initialCameraPosition: const CameraPosition(
        target: _defaultLocation,
        zoom: 12.0,
      ),
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      trafficEnabled: true,
      buildingsEnabled: true,
      mapType: MapType.normal,
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Ambulances'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<bool>(
              title: const Text('Show All Ambulances'),
              value: true,
              groupValue: _showAllAmbulances,
              onChanged: (value) {
                setState(() {
                  _showAllAmbulances = value!;
                  _filterStatus = null;
                });
                Navigator.pop(context);
                _updateMarkers();
              },
            ),
            RadioListTile<bool>(
              title: const Text('Filter by Status'),
              value: false,
              groupValue: _showAllAmbulances,
              onChanged: (value) {
                setState(() {
                  _showAllAmbulances = value!;
                });
              },
            ),
            if (!_showAllAmbulances) ...[
              const Divider(),
              ...AmbulanceStatus.values.map((status) {
                return RadioListTile<AmbulanceStatus>(
                  title: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        color: Color(AmbulanceStatus.getStatusColor(status)),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(status.displayName),
                    ],
                  ),
                  value: status,
                  groupValue: _filterStatus,
                  onChanged: (value) {
                    setState(() {
                      _filterStatus = value;
                    });
                    Navigator.pop(context);
                    _updateMarkers();
                  },
                );
              }).toList(),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

// Ambulance Details Bottom Sheet
class AmbulanceDetailsBottomSheet extends StatelessWidget {
  final AmbulanceLocation ambulance;

  const AmbulanceDetailsBottomSheet({
    Key? key,
    required this.ambulance,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusColor = ambulance.statusColor;
    final isStale = ambulance.isStale || _isLocationStale(ambulance);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_shipping,
                  color: statusColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ambulance.licensePlate,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ambulance.model,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isStale ? Colors.red : statusColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isStale ? 'STALE' : ambulance.statusDisplayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Location Info
          _buildInfoSection(
            'Location Information',
            Icons.location_on,
            [
              if (ambulance.hasLocation) ...[
                _buildInfoRow(
                  'Coordinates',
                  '${ambulance.latitude!.toStringAsFixed(6)}, ${ambulance.longitude!.toStringAsFixed(6)}',
                ),
                if (ambulance.accuracy != null)
                  _buildInfoRow('Accuracy',
                      '±${ambulance.accuracy!.toStringAsFixed(1)}m'),
                if (ambulance.speed != null)
                  _buildInfoRow('Speed',
                      '${(ambulance.speed! * 3.6).toStringAsFixed(1)} km/h'),
                if (ambulance.heading != null)
                  _buildInfoRow(
                      'Heading', '${ambulance.heading!.toStringAsFixed(0)}°'),
              ] else ...[
                _buildInfoRow('Status', 'No location data available'),
              ],
            ],
          ),

          const SizedBox(height: 20),

          // Timing Info
          _buildInfoSection(
            'Update Information',
            Icons.access_time,
            [
              _buildInfoRow('Last Update', ambulance.lastUpdateFormatted),
              if (isStale)
                _buildInfoRow(
                  'Warning',
                  'Location data is outdated',
                  valueColor: Colors.red,
                ),
            ],
          ),

          const SizedBox(height: 20),

          // Driver Info
          if (ambulance.currentDriverId != null)
            _buildInfoSection(
              'Driver Information',
              Icons.person,
              [
                _buildInfoRow('Driver ID', ambulance.currentDriverId!),
              ],
            ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToAmbulance(context, ambulance),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.blue.shade700, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.grey.shade900,
                fontWeight:
                    valueColor != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isLocationStale(AmbulanceLocation ambulance) {
    if (ambulance.lastLocationUpdate == null) return true;
    return DateTime.now().difference(ambulance.lastLocationUpdate!) >
        const Duration(minutes: 2);
  }

  void _navigateToAmbulance(BuildContext context, AmbulanceLocation ambulance) {
    // Implement navigation to ambulance location
    // This could open external maps app or provide in-app navigation
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigate to ${ambulance.licensePlate}'),
        action: SnackBarAction(
          label: 'Open Maps',
          onPressed: () {
            // Open external maps application
            // Implementation depends on platform and available packages
          },
        ),
      ),
    );
  }
}

// Cluster Details Bottom Sheet
class ClusterDetailsBottomSheet extends StatelessWidget {
  final List<AmbulanceLocation> ambulances;

  const ClusterDetailsBottomSheet({
    Key? key,
    required this.ambulances,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.group_work,
                  color: Colors.purple.shade700,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ambulance Cluster',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${ambulances.length} ambulances in this area',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Ambulance list
          Text(
            'Ambulances in Cluster',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: ambulances.length,
              itemBuilder: (context, index) {
                final ambulance = ambulances[index];
                return _buildAmbulanceListItem(context, ambulance);
              },
            ),
          ),

          const SizedBox(height: 20),

          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              label: const Text('Close'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildAmbulanceListItem(
      BuildContext context, AmbulanceLocation ambulance) {
    final statusColor = ambulance.statusColor;
    final isStale = ambulance.isStale || _isLocationStale(ambulance);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.local_shipping,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(
          ambulance.licensePlate,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(ambulance.model),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isStale ? Colors.red : statusColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isStale ? 'STALE' : ambulance.statusDisplayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              ambulance.lastUpdateFormatted,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.pop(context);
          // Show individual ambulance details
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (context) =>
                AmbulanceDetailsBottomSheet(ambulance: ambulance),
          );
        },
      ),
    );
  }

  bool _isLocationStale(AmbulanceLocation ambulance) {
    if (ambulance.lastLocationUpdate == null) return true;
    return DateTime.now().difference(ambulance.lastLocationUpdate!) >
        const Duration(minutes: 2);
  }
}
