// lib/screens/live_emergency_map_screen.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/ambulance_model.dart';
import '../models/emergency_model.dart';
import '../providers/auth_provider.dart';
import '../providers/emergency_providers.dart';
import '../providers/location_providers.dart';
import 'emergency_details_screen.dart';

class LiveEmergencyMapScreen extends ConsumerStatefulWidget {
  const LiveEmergencyMapScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LiveEmergencyMapScreen> createState() =>
      _LiveEmergencyMapScreenState();
}

class _LiveEmergencyMapScreenState
    extends ConsumerState<LiveEmergencyMapScreen> {
  GoogleMapController? _mapController;
  String? hospitalId;
  Timer? _refreshTimer;

  // Map state
  final Set<Marker> _emergencyMarkers = {};
  final Set<Marker> _ambulanceMarkers = {};
  final Map<String, BitmapDescriptor> _emergencyIcons = {};
  final Map<String, BitmapDescriptor> _ambulanceIcons = {};
  bool _isMapReady = false;
  bool _showAmbulances = true;
  bool _showEmergencies = true;
  EmergencyPriority? _filterPriority;

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
    // Emergency marker icons by priority
    _emergencyIcons[EmergencyPriority.critical.value] =
        await _createMarkerIcon(Colors.red, Icons.emergency);
    _emergencyIcons[EmergencyPriority.high.value] =
        await _createMarkerIcon(Colors.deepOrange, Icons.emergency);
    _emergencyIcons[EmergencyPriority.medium.value] =
        await _createMarkerIcon(Colors.orange, Icons.emergency);
    _emergencyIcons[EmergencyPriority.low.value] =
        await _createMarkerIcon(Colors.yellow, Icons.emergency);

    // Ambulance marker icons by status
    _ambulanceIcons[AmbulanceStatus.available.value] =
        await _createMarkerIcon(Colors.green, Icons.local_shipping);
    _ambulanceIcons[AmbulanceStatus.onDuty.value] =
        await _createMarkerIcon(Colors.blue, Icons.local_shipping);
    _ambulanceIcons[AmbulanceStatus.maintenance.value] =
        await _createMarkerIcon(Colors.orange, Icons.build);
    _ambulanceIcons['stale'] =
        await _createMarkerIcon(Colors.grey, Icons.warning);
  }

  Future<BitmapDescriptor> _createMarkerIcon(Color color, IconData icon) async {
    // Map colors to BitmapDescriptor hues
    switch (color) {
      case Colors.red:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case Colors.green:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case Colors.blue:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case Colors.orange:
      case Colors.deepOrange:
        return BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange);
      case Colors.yellow:
        return BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow);
      case Colors.grey:
        return BitmapDescriptor.defaultMarker;
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

  Future<void> _updateMarkers() async {
    if (!_isMapReady || hospitalId == null) return;

    _updateEmergencyMarkers();
    _updateAmbulanceMarkers();
  }

  void _updateEmergencyMarkers() {
    if (!_showEmergencies) {
      setState(() {
        _emergencyMarkers.clear();
      });
      return;
    }

    final emergenciesAsync = ref.read(activeEmergenciesProvider(hospitalId!));

    emergenciesAsync.whenData((emergencies) {
      final newMarkers = <Marker>{};

      for (final emergency in emergencies) {
        // Apply priority filter
        if (_filterPriority != null && emergency.priority != _filterPriority) {
          continue;
        }

        final markerId = MarkerId('emergency_${emergency.id}');
        final position = LatLng(emergency.patientLat, emergency.patientLng);

        // Choose appropriate icon
        final icon = _emergencyIcons[emergency.priority.value] ??
            BitmapDescriptor.defaultMarker;

        final marker = Marker(
          markerId: markerId,
          position: position,
          icon: icon,
          infoWindow: InfoWindow(
            title: '${emergency.priority.displayName} Emergency',
            snippet: '${emergency.callerName} • ${emergency.timeSinceCreated}',
            onTap: () => _showEmergencyDetails(emergency),
          ),
          onTap: () => _onEmergencyMarkerTapped(emergency),
        );

        newMarkers.add(marker);
      }

      setState(() {
        _emergencyMarkers.clear();
        _emergencyMarkers.addAll(newMarkers);
      });
    });
  }

  void _updateAmbulanceMarkers() {
    if (!_showAmbulances) {
      setState(() {
        _ambulanceMarkers.clear();
      });
      return;
    }

    final ambulancesAsync = ref.read(ambulanceLocationsProvider(hospitalId!));

    ambulancesAsync.whenData((ambulances) {
      final newMarkers = <Marker>{};
      final now = DateTime.now();
      const staleThreshold = Duration(minutes: 2);

      for (final ambulance in ambulances) {
        if (!ambulance.hasLocation) continue;

        final isStale = ambulance.lastLocationUpdate != null &&
            now.difference(ambulance.lastLocationUpdate!) > staleThreshold;

        final markerId = MarkerId('ambulance_${ambulance.id}');
        final position = LatLng(ambulance.latitude!, ambulance.longitude!);

        // Choose appropriate icon
        BitmapDescriptor icon;
        if (isStale) {
          icon = _ambulanceIcons['stale'] ?? BitmapDescriptor.defaultMarker;
        } else {
          icon = _ambulanceIcons[ambulance.status.value] ??
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
          onTap: () => _onAmbulanceMarkerTapped(ambulance),
        );

        newMarkers.add(marker);
      }

      setState(() {
        _ambulanceMarkers.clear();
        _ambulanceMarkers.addAll(newMarkers);
      });
    });
  }

  void _onEmergencyMarkerTapped(EmergencyModel emergency) {
    _showEmergencyBottomSheet(emergency);
  }

  void _onAmbulanceMarkerTapped(AmbulanceLocation ambulance) {
    _showAmbulanceBottomSheet(ambulance);
  }

  void _showEmergencyBottomSheet(EmergencyModel emergency) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => EmergencyMapBottomSheet(emergency: emergency),
    );
  }

  void _showAmbulanceBottomSheet(AmbulanceLocation ambulance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => AmbulanceMapBottomSheet(ambulance: ambulance),
    );
  }

  void _showEmergencyDetails(EmergencyModel emergency) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencyDetailsScreen(emergency: emergency),
      ),
    );
  }

  void _showAmbulanceDetails(AmbulanceLocation ambulance) {
    // Implementation for ambulance details if needed
  }

  void _centerOnEmergencies() {
    if (hospitalId == null || !_isMapReady) return;

    final emergenciesAsync = ref.read(activeEmergenciesProvider(hospitalId!));

    emergenciesAsync.whenData((emergencies) {
      if (emergencies.isEmpty) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_defaultLocation, 12.0),
        );
        return;
      }

      if (emergencies.length == 1) {
        final emergency = emergencies.first;
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(emergency.patientLat, emergency.patientLng),
            16.0,
          ),
        );
        return;
      }

      // Calculate bounds for multiple emergencies
      double minLat = emergencies.first.patientLat;
      double maxLat = emergencies.first.patientLat;
      double minLng = emergencies.first.patientLng;
      double maxLng = emergencies.first.patientLng;

      for (final emergency in emergencies) {
        minLat = math.min(minLat, emergency.patientLat);
        maxLat = math.max(maxLat, emergency.patientLat);
        minLng = math.min(minLng, emergency.patientLng);
        maxLng = math.max(maxLng, emergency.patientLng);
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
          title: const Text('Live Emergency Map',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red.shade700,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final emergencyStats = ref.watch(emergencyStatsProvider(hospitalId!));
    final locationStats = ref.watch(locationStatsProvider(hospitalId!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Emergency Map',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Layer toggle button
          IconButton(
            icon: const Icon(Icons.layers, color: Colors.white),
            onPressed: _showLayerDialog,
          ),
          // Filter button
          IconButton(
            icon: Icon(
              _filterPriority != null ? Icons.filter_alt : Icons.filter_list,
              color: Colors.white,
            ),
            onPressed: _showFilterDialog,
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
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border(bottom: BorderSide(color: Colors.red.shade200)),
            ),
            child: Row(
              children: [
                emergencyStats.when(
                  data: (stats) => Expanded(
                    child: Row(
                      children: [
                        _buildStatChip(
                          'Active: ${stats['activeTotal']}',
                          Colors.red.shade700,
                          Icons.emergency,
                        ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          'Critical: ${stats['critical']}',
                          Colors.red.shade900,
                          Icons.priority_high,
                        ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          'Pending: ${stats['pending']}',
                          Colors.orange.shade700,
                          Icons.pending,
                        ),
                      ],
                    ),
                  ),
                  loading: () =>
                      const Expanded(child: LinearProgressIndicator()),
                  error: (error, stack) => Expanded(
                    child: Text('Error: $error',
                        style: TextStyle(color: Colors.red)),
                  ),
                ),
                const SizedBox(width: 16),
                locationStats.when(
                  data: (stats) => Row(
                    children: [
                      _buildStatChip(
                        'Ambulances: ${stats.activelyTracked}',
                        Colors.blue.shade700,
                        Icons.local_shipping,
                      ),
                    ],
                  ),
                  loading: () => const SizedBox(),
                  error: (error, stack) => const SizedBox(),
                ),
                const SizedBox(width: 16),
                Text(
                  'Updated: ${DateTime.now().toString().substring(11, 19)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: const CameraPosition(
                target: _defaultLocation,
                zoom: 12.0,
              ),
              markers: {..._emergencyMarkers, ..._ambulanceMarkers},
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: true,
              trafficEnabled: true,
              buildingsEnabled: true,
              mapType: MapType.normal,
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
            onPressed: _centerOnEmergencies,
            backgroundColor: Colors.red.shade700,
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

  void _showLayerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Map Layers'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text('Show Emergencies'),
              subtitle: const Text('Patient locations'),
              value: _showEmergencies,
              onChanged: (value) {
                setState(() {
                  _showEmergencies = value ?? true;
                });
                Navigator.pop(context);
                _updateMarkers();
              },
            ),
            CheckboxListTile(
              title: const Text('Show Ambulances'),
              subtitle: const Text('Ambulance locations'),
              value: _showAmbulances,
              onChanged: (value) {
                setState(() {
                  _showAmbulances = value ?? true;
                });
                Navigator.pop(context);
                _updateMarkers();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Emergencies'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<EmergencyPriority?>(
              title: const Text('Show All Priorities'),
              value: null,
              groupValue: _filterPriority,
              onChanged: (value) {
                setState(() {
                  _filterPriority = value;
                });
                Navigator.pop(context);
                _updateMarkers();
              },
            ),
            ...EmergencyPriority.values.map((priority) {
              return RadioListTile<EmergencyPriority?>(
                title: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Color(priority.colorValue),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(priority.displayName),
                  ],
                ),
                value: priority,
                groupValue: _filterPriority,
                onChanged: (value) {
                  setState(() {
                    _filterPriority = value;
                  });
                  Navigator.pop(context);
                  _updateMarkers();
                },
              );
            }).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// Emergency Map Bottom Sheet
class EmergencyMapBottomSheet extends StatelessWidget {
  final EmergencyModel emergency;

  const EmergencyMapBottomSheet({
    Key? key,
    required this.emergency,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final priorityColor = Color(emergency.priority.colorValue);
    final statusColor = Color(emergency.status.colorValue);

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
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.emergency,
                  color: priorityColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emergency.callerName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      emergency.callerPhone,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      emergency.priorityDisplayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      emergency.statusDisplayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            'Description:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(emergency.description),

          const SizedBox(height: 12),

          // Location
          Text(
            'Location:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(emergency.patientAddressString),

          const SizedBox(height: 12),

          // Time info
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                'Created ${emergency.timeSinceCreated}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              if (emergency.isAssigned) ...[
                const SizedBox(width: 16),
                Icon(Icons.local_shipping,
                    size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 4),
                Text(
                  'Assigned',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),

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
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EmergencyDetailsScreen(emergency: emergency),
                      ),
                    );
                  },
                  icon: const Icon(Icons.info),
                  label: const Text('Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: priorityColor,
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
}

// Ambulance Map Bottom Sheet
class AmbulanceMapBottomSheet extends StatelessWidget {
  final AmbulanceLocation ambulance;

  const AmbulanceMapBottomSheet({
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
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isStale ? Colors.red : statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isStale ? 'STALE' : ambulance.statusDisplayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Location info
          if (ambulance.hasLocation) ...[
            Text(
              'Location:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${ambulance.latitude!.toStringAsFixed(6)}, ${ambulance.longitude!.toStringAsFixed(6)}',
            ),
            if (ambulance.accuracy != null) ...[
              const SizedBox(height: 4),
              Text(
                'Accuracy: ±${ambulance.accuracy!.toStringAsFixed(1)}m',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],

          const SizedBox(height: 12),

          // Update info
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                'Last update: ${ambulance.lastUpdateFormatted}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              if (isStale) ...[
                const SizedBox(width: 8),
                Icon(Icons.warning, size: 16, color: Colors.red.shade600),
                const SizedBox(width: 4),
                Text(
                  'Outdated',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
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

  bool _isLocationStale(AmbulanceLocation ambulance) {
    if (ambulance.lastLocationUpdate == null) return true;
    return DateTime.now().difference(ambulance.lastLocationUpdate!) >
        const Duration(minutes: 2);
  }
}
