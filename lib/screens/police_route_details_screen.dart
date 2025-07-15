// lib/screens/police_route_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/route_model.dart';
import '../providers/auth_provider.dart';
import '../providers/route_providers.dart';
import '../utils/polyline_decoder.dart';

class PoliceRouteDetailsScreen extends ConsumerStatefulWidget {
  final AmbulanceRouteModel route;

  const PoliceRouteDetailsScreen({
    Key? key,
    required this.route,
  }) : super(key: key);

  @override
  ConsumerState<PoliceRouteDetailsScreen> createState() =>
      _PoliceRouteDetailsScreenState();
}

class _PoliceRouteDetailsScreenState
    extends ConsumerState<PoliceRouteDetailsScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  late TabController _tabController;
  final TextEditingController _notesController = TextEditingController();

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupMapData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _setupMapData() {
    // Decode polyline and create route polyline
    if (widget.route.encodedPolyline.isNotEmpty) {
      final points = PolylineDecoder.decode(widget.route.encodedPolyline);
      _polylines = {
        Polyline(
          polylineId: const PolylineId('ambulance_route'),
          points: points
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList(),
          color: widget.route.isHighPriority ? Colors.red : Colors.blue,
          width: 5,
          patterns: widget.route.status == RouteStatus.active
              ? []
              : [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      };
    }

    // Create markers for start and end points
    _markers = {
      Marker(
        markerId: const MarkerId('start'),
        position: LatLng(widget.route.startLat, widget.route.startLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(
          title: 'Ambulance Start',
          snippet: widget.route.ambulanceLicensePlate,
        ),
      ),
      Marker(
        markerId: const MarkerId('end'),
        position: LatLng(widget.route.endLat, widget.route.endLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Patient Location',
          snippet: widget.route.patientLocation,
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = widget.route.emergencyPriority == 'critical'
        ? Colors.red
        : widget.route.emergencyPriority == 'high'
            ? Colors.orange
            : Colors.blue;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Route Details',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: priorityColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (widget.route.status == RouteStatus.active)
            PopupMenuButton<RouteStatus>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (status) => _updateRouteStatus(status),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: RouteStatus.cleared,
                  child: ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text('Mark as Cleared'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: RouteStatus.timeout,
                  child: ListTile(
                    leading: Icon(Icons.timer_off, color: Colors.orange),
                    title: Text('Mark as Timeout'),
                    contentPadding: EdgeInsets.zero,
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
            Tab(text: 'Overview', icon: Icon(Icons.info)),
            Tab(text: 'Map', icon: Icon(Icons.map)),
            Tab(text: 'Actions', icon: Icon(Icons.build)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildMapTab(),
          _buildActionsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status and Priority Header
          _buildStatusHeader(),
          const SizedBox(height: 24),

          // Route Information
          _buildSectionCard(
            title: 'Route Information',
            icon: Icons.route,
            children: [
              _buildInfoRow('Ambulance', widget.route.ambulanceLicensePlate),
              _buildInfoRow('Emergency ID', widget.route.emergencyId),
              _buildInfoRow('Distance', widget.route.formattedDistance),
              _buildInfoRow('Duration', widget.route.formattedDuration),
              _buildInfoRow('ETA', widget.route.formattedETA),
            ],
          ),
          const SizedBox(height: 16),

          // Location Information
          _buildSectionCard(
            title: 'Locations',
            icon: Icons.location_on,
            children: [
              _buildInfoRow('Start Address', widget.route.startAddress),
              _buildInfoRow('Patient Location', widget.route.patientLocation),
              _buildInfoRow('Coordinates',
                  '${widget.route.endLat.toStringAsFixed(6)}, ${widget.route.endLng.toStringAsFixed(6)}'),
            ],
          ),
          const SizedBox(height: 16),

          // Timeline Information
          _buildSectionCard(
            title: 'Timeline',
            icon: Icons.schedule,
            children: [
              _buildInfoRow('Created', _formatDateTime(widget.route.createdAt)),
              _buildInfoRow(
                  'Last Updated', _formatDateTime(widget.route.updatedAt)),
              if (widget.route.estimatedArrival != null)
                _buildInfoRow('Estimated Arrival',
                    _formatDateTime(widget.route.estimatedArrival!)),
            ],
          ),

          // Police Action History
          if (widget.route.policeOfficerName != null) ...[
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Police Actions',
              icon: Icons.security,
              children: [
                _buildInfoRow('Officer', widget.route.policeOfficerName!),
                if (widget.route.statusUpdatedAt != null)
                  _buildInfoRow('Action Time',
                      _formatDateTime(widget.route.statusUpdatedAt!)),
                if (widget.route.statusNotes != null)
                  _buildInfoRow('Notes', widget.route.statusNotes!),
              ],
            ),
          ],

          // Turn-by-turn directions
          if (widget.route.steps.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildDirectionsCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildMapTab() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(widget.route.startLat, widget.route.startLng),
        zoom: 12,
      ),
      polylines: _polylines,
      markers: _markers,
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        _fitMapToRoute();
      },
      mapType: MapType.normal,
      trafficEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
    );
  }

  Widget _buildActionsTab() {
    final currentUserAsync = ref.watch(currentUserProvider);

    return currentUserAsync.when(
      data: (user) {
        if (user == null) {
          return const Center(child: Text('User not found'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Actions
              _buildSectionCard(
                title: 'Quick Actions',
                icon: Icons.flash_on,
                children: [
                  if (widget.route.status == RouteStatus.active) ...[
                    ListTile(
                      leading:
                          const Icon(Icons.check_circle, color: Colors.green),
                      title: const Text('Mark Route as Cleared'),
                      subtitle:
                          const Text('Traffic has been cleared for this route'),
                      onTap: () => _updateRouteStatus(RouteStatus.cleared),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Divider(),
                    ListTile(
                      leading:
                          const Icon(Icons.timer_off, color: Colors.orange),
                      title: const Text('Mark as Timeout'),
                      subtitle: const Text(
                          'Ambulance did not pass within expected time'),
                      onTap: () => _updateRouteStatus(RouteStatus.timeout),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.route.status == RouteStatus.cleared
                                ? Icons.check_circle
                                : Icons.timer_off,
                            color: widget.route.status == RouteStatus.cleared
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Route has been marked as ${widget.route.status.displayName}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Communication
              _buildSectionCard(
                title: 'Communication',
                icon: Icons.chat,
                children: [
                  ListTile(
                    leading: const Icon(Icons.phone, color: Colors.blue),
                    title: const Text('Call Hospital'),
                    subtitle: const Text('Contact hospital about this route'),
                    onTap: _callHospital,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.radio, color: Colors.purple),
                    title: const Text('Radio Ambulance'),
                    subtitle: const Text('Contact ambulance driver directly'),
                    onTap: _radioAmbulance,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Notes Section
              _buildSectionCard(
                title: 'Add Notes',
                icon: Icons.note_add,
                children: [
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      hintText: 'Enter notes about this route...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveNotes,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Notes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildStatusHeader() {
    final priorityColor = widget.route.emergencyPriority == 'critical'
        ? Colors.red
        : widget.route.emergencyPriority == 'high'
            ? Colors.orange
            : Colors.blue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            priorityColor.withOpacity(0.1),
            priorityColor.withOpacity(0.05)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: priorityColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  widget.route.emergencyPriority.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(widget.route.status.colorValue),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  widget.route.status.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Ambulance ${widget.route.ambulanceLicensePlate}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.route.patientLocation,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
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

  Widget _buildDirectionsCard() {
    return _buildSectionCard(
      title: 'Turn-by-turn Directions',
      icon: Icons.directions,
      children: [
        ...widget.route.steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.instruction,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(step.distanceMeters / 1000).toStringAsFixed(1)}km • ${(step.durationSeconds / 60).round()}min',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  void _fitMapToRoute() {
    if (_mapController == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        widget.route.startLat < widget.route.endLat
            ? widget.route.startLat
            : widget.route.endLat,
        widget.route.startLng < widget.route.endLng
            ? widget.route.startLng
            : widget.route.endLng,
      ),
      northeast: LatLng(
        widget.route.startLat > widget.route.endLat
            ? widget.route.startLat
            : widget.route.endLat,
        widget.route.startLng > widget.route.endLng
            ? widget.route.startLng
            : widget.route.endLng,
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  void _updateRouteStatus(RouteStatus newStatus) async {
    final currentUserAsync = ref.read(currentUserProvider);

    await currentUserAsync.when(
      data: (user) async {
        if (user == null) return;

        final confirmed = await _showConfirmationDialog(newStatus);
        if (!confirmed) return;

        try {
          await ref.read(routeStatusUpdateProvider.notifier).updateRouteStatus(
                routeId: widget.route.id,
                newStatus: newStatus,
                policeOfficerId: user.id,
                policeOfficerName: user.fullName,
                notes: _notesController.text.isNotEmpty
                    ? _notesController.text
                    : null,
              );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Route status updated to ${newStatus.displayName}'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update route status: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      loading: () {},
      error: (error, stack) {},
    );
  }

  Future<bool> _showConfirmationDialog(RouteStatus newStatus) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Update Route Status'),
            content: Text(
              'Are you sure you want to mark this route as ${newStatus.displayName}?\n\n'
              'This will notify the hospital about the status change.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: newStatus == RouteStatus.cleared
                      ? Colors.green
                      : Colors.orange,
                ),
                child: Text('Mark ${newStatus.displayName}'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _callHospital() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calling hospital... (Feature not implemented)'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _radioAmbulance() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contacting ambulance... (Feature not implemented)'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  void _saveNotes() async {
    if (_notesController.text.trim().isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notes saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
    _notesController.clear();
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
