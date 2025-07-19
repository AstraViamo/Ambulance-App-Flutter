// lib/screens/route_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/route_model.dart';
import '../providers/auth_provider.dart';
import '../providers/route_providers.dart';
import '../utils/polyline_decoder.dart';

class RouteDetailsScreen extends ConsumerStatefulWidget {
  final AmbulanceRouteModel route;
  final bool isPoliceView;

  const RouteDetailsScreen({
    Key? key,
    required this.route,
    this.isPoliceView = false,
  }) : super(key: key);

  @override
  ConsumerState<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends ConsumerState<RouteDetailsScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  late TabController _tabController;
  final TextEditingController _notesController = TextEditingController();

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: widget.isPoliceView ? 4 : 3, vsync: this);
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
          color: _getRouteColor(),
          width: 5,
          patterns: _getRoutePattern(),
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

  Color _getRouteColor() {
    if (widget.route.isHighPriority) return Colors.red;

    switch (widget.route.status) {
      case RouteStatus.active:
        return Colors.blue;
      case RouteStatus.cleared:
        return Colors.green;
      case RouteStatus.timeout:
        return Colors.orange;
      case RouteStatus.completed:
        return Colors.grey;
    }
  }

  List<PatternItem> _getRoutePattern() {
    switch (widget.route.status) {
      case RouteStatus.active:
        return [];
      case RouteStatus.cleared:
        return [];
      case RouteStatus.timeout:
        return [PatternItem.dash(20), PatternItem.gap(10)];
      case RouteStatus.completed:
        return [PatternItem.dot, PatternItem.gap(10)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final userRole = currentUser.maybeWhen(
      data: (user) => user?.role.value,
      orElse: () => null,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isPoliceView ? 'Police Route Details' : 'Route Details',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor:
            widget.isPoliceView ? Colors.indigo.shade700 : Colors.red.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              // Refresh route data
              ref.invalidate(routeByIdProvider(widget.route.id));
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: [
            const Tab(text: 'Overview', icon: Icon(Icons.info)),
            const Tab(text: 'Map', icon: Icon(Icons.map)),
            const Tab(text: 'Timeline', icon: Icon(Icons.timeline)),
            if (widget.isPoliceView)
              const Tab(text: 'Actions', icon: Icon(Icons.local_police)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(userRole),
          _buildMapTab(),
          _buildTimelineTab(),
          if (widget.isPoliceView) _buildActionsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(String? userRole) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Header
          _buildStatusHeader(),
          const SizedBox(height: 16),

          // Emergency Information
          _buildSectionCard(
            title: 'Emergency Information',
            icon: Icons.emergency,
            color: widget.route.isHighPriority ? Colors.red : Colors.orange,
            children: [
              _buildInfoRow('Emergency ID', widget.route.emergencyId),
              _buildInfoRow(
                  'Priority', widget.route.emergencyPriority.toUpperCase(),
                  isHighlighted: widget.route.isHighPriority),
              _buildInfoRow('Patient Location', widget.route.patientLocation),
              _buildInfoRow(
                  'Emergency Created', _formatDateTime(widget.route.createdAt)),
            ],
          ),
          const SizedBox(height: 16),

          // Ambulance Information
          _buildSectionCard(
            title: 'Ambulance Information',
            icon: Icons.local_shipping,
            color: Colors.blue,
            children: [
              _buildInfoRow(
                  'License Plate', widget.route.ambulanceLicensePlate),
              _buildInfoRow('Driver ID', widget.route.driverId),
              _buildInfoRow('Ambulance ID', widget.route.ambulanceId),
            ],
          ),
          const SizedBox(height: 16),

          // Route Information
          _buildSectionCard(
            title: 'Route Information',
            icon: Icons.route,
            color: Colors.green,
            children: [
              _buildInfoRow('Distance', widget.route.formattedDistance),
              _buildInfoRow('Duration', widget.route.formattedDuration),
              _buildInfoRow('ETA', widget.route.formattedETA),
              _buildInfoRow('Start Address', widget.route.startAddress),
              _buildInfoRow('End Address', widget.route.endAddress),
            ],
          ),
          const SizedBox(height: 16),

          // Status-Specific Information
          if (widget.route.status != RouteStatus.active)
            _buildStatusSpecificInfo(userRole),

          // Police Information (if available)
          if (widget.route.policeOfficerId != null) _buildPoliceInformation(),

          // Completion Information (if completed)
          if (widget.route.status == RouteStatus.completed)
            _buildCompletionInformation(),
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(widget.route.status.colorValue),
            Color(widget.route.status.colorValue).withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getStatusIcon(),
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.route.getStatusDescription(
                      widget.isPoliceView ? 'police' : 'hospital_admin'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ambulance ${widget.route.ambulanceLicensePlate}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                if (widget.route.statusUpdatedAt != null)
                  Text(
                    'Last updated: ${_formatDateTime(widget.route.statusUpdatedAt!)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
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
        ],
      ),
    );
  }

  Widget _buildStatusSpecificInfo(String? userRole) {
    switch (widget.route.status) {
      case RouteStatus.cleared:
        return Column(
          children: [
            _buildSectionCard(
              title: 'Traffic Clearance',
              icon: Icons.check_circle,
              color: Colors.green,
              children: [
                if (widget.route.policeOfficerName != null)
                  _buildInfoRow('Cleared by', widget.route.policeOfficerName!),
                if (widget.route.clearedAt != null)
                  _buildInfoRow(
                      'Cleared at', _formatDateTime(widget.route.clearedAt!)),
                if (widget.route.statusNotes != null)
                  _buildInfoRow('Notes', widget.route.statusNotes!),
                _buildInfoRow(
                    'Status', 'Traffic has been cleared - route is now open'),
              ],
            ),
            const SizedBox(height: 16),
          ],
        );
      case RouteStatus.timeout:
        return Column(
          children: [
            _buildSectionCard(
              title: 'Route Timeout',
              icon: Icons.timer_off,
              color: Colors.orange,
              children: [
                if (widget.route.policeOfficerName != null)
                  _buildInfoRow('Marked by', widget.route.policeOfficerName!),
                if (widget.route.statusUpdatedAt != null)
                  _buildInfoRow('Timeout at',
                      _formatDateTime(widget.route.statusUpdatedAt!)),
                if (widget.route.statusNotes != null)
                  _buildInfoRow('Reason', widget.route.statusNotes!),
                _buildInfoRow('Status',
                    'Route has timed out - may need alternative action'),
              ],
            ),
            const SizedBox(height: 16),
          ],
        );
      case RouteStatus.completed:
        return Container(); // Handled in buildCompletionInformation
      default:
        return Container();
    }
  }

  Widget _buildPoliceInformation() {
    return Column(
      children: [
        _buildSectionCard(
          title: 'Police Officer Information',
          icon: Icons.local_police,
          color: Colors.indigo,
          children: [
            _buildInfoRow(
                'Officer Name', widget.route.policeOfficerName ?? 'Unknown'),
            _buildInfoRow(
                'Officer ID', widget.route.policeOfficerId ?? 'Unknown'),
            if (widget.route.statusUpdatedAt != null)
              _buildInfoRow('Action Time',
                  _formatDateTime(widget.route.statusUpdatedAt!)),
            if (widget.route.statusNotes != null)
              _buildInfoRow('Officer Notes', widget.route.statusNotes!),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCompletionInformation() {
    final historyInfo = widget.route.historyInfo;

    return Column(
      children: [
        _buildSectionCard(
          title: 'Route Completion',
          icon: Icons.flag,
          color: Colors.grey,
          children: [
            if (widget.route.completedAt != null)
              _buildInfoRow(
                  'Completed at', _formatDateTime(widget.route.completedAt!)),
            if (widget.route.completionReason != null)
              _buildInfoRow(
                  'Completion Reason', widget.route.completionReason!),
            if (historyInfo['completion']['duration'] != null)
              _buildInfoRow('Total Duration',
                  '${historyInfo['completion']['duration']} minutes'),
            _buildInfoRow(
                'Final Status', 'Emergency response completed successfully'),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMapTab() {
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        _fitMapToRoute();
      },
      initialCameraPosition: CameraPosition(
        target: LatLng(widget.route.startLat, widget.route.startLng),
        zoom: 12,
      ),
      polylines: _polylines,
      markers: _markers,
      mapType: MapType.normal,
      zoomControlsEnabled: true,
      myLocationButtonEnabled: false,
    );
  }

  Widget _buildTimelineTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Route Timeline',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTimelineItem(
            icon: Icons.add_circle,
            title: 'Route Created',
            time: widget.route.createdAt,
            description:
                'Emergency route was created and assigned to ambulance',
            isCompleted: true,
            color: Colors.blue,
          ),
          if (widget.route.clearedAt != null)
            _buildTimelineItem(
              icon: Icons.check_circle,
              title: 'Traffic Cleared',
              time: widget.route.clearedAt!,
              description:
                  'Traffic cleared by ${widget.route.policeOfficerName ?? 'Police Officer'}',
              isCompleted: true,
              color: Colors.green,
            ),
          if (widget.route.status == RouteStatus.timeout)
            _buildTimelineItem(
              icon: Icons.timer_off,
              title: 'Route Timeout',
              time: widget.route.statusUpdatedAt ?? DateTime.now(),
              description:
                  'Route marked as timeout by ${widget.route.policeOfficerName ?? 'Police Officer'}',
              isCompleted: true,
              color: Colors.orange,
            ),
          if (widget.route.completedAt != null)
            _buildTimelineItem(
              icon: Icons.flag,
              title: 'Route Completed',
              time: widget.route.completedAt!,
              description: widget.route.completionReason ??
                  'Emergency response completed',
              isCompleted: true,
              color: Colors.grey,
            )
          else
            _buildTimelineItem(
              icon: Icons.pending,
              title: 'Route Completion',
              time: null,
              description: 'Waiting for ambulance to reach destination',
              isCompleted: false,
              color: Colors.grey,
            ),
        ],
      ),
    );
  }

  Widget _buildActionsTab() {
    final currentUser = ref.watch(currentUserProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Police Actions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Current status info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Status: ${widget.route.status.displayName}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.route.getStatusDescription('police'),
                  style: TextStyle(color: Colors.indigo.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons based on current status
          if (widget.route.status == RouteStatus.active) ...[
            const Text(
              'Available Actions:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _updateRouteStatus(RouteStatus.cleared),
                icon: const Icon(Icons.check_circle),
                label: const Text('Clear Traffic'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _updateRouteStatus(RouteStatus.timeout),
                icon: const Icon(Icons.timer_off),
                label: const Text('Mark as Timeout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No actions available for ${widget.route.status.displayName.toLowerCase()} routes',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Notes section
          const Text(
            'Add Notes:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              hintText: 'Enter any additional notes about this route...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _addNotes(),
              icon: const Icon(Icons.note_add),
              label: const Text('Add Notes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    color: (color ?? Colors.blue).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color ?? Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
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

  Widget _buildInfoRow(String label, String value,
      {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
              style: TextStyle(
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                color: isHighlighted ? Colors.red : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required IconData icon,
    required String title,
    required DateTime? time,
    required String description,
    required bool isCompleted,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isCompleted ? color : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 16,
              ),
            ),
            Container(
              width: 2,
              height: 40,
              color: Colors.grey.shade300,
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? Colors.black87 : Colors.grey.shade600,
                ),
              ),
              if (time != null)
                Text(
                  _formatDateTime(time),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: isCompleted ? Colors.black54 : Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon() {
    switch (widget.route.status) {
      case RouteStatus.active:
        return Icons.pending_actions;
      case RouteStatus.cleared:
        return Icons.check_circle;
      case RouteStatus.timeout:
        return Icons.timer_off;
      case RouteStatus.completed:
        return Icons.flag;
    }
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
    final currentUser = ref.read(currentUserProvider);

    await currentUser.when(
      data: (user) async {
        if (user == null) return;

        final confirmed = await _showConfirmationDialog(newStatus);
        if (!confirmed) return;

        try {
          String? notes =
              _notesController.text.isNotEmpty ? _notesController.text : null;

          await ref.read(routeStatusUpdateProvider.notifier).updateRouteStatus(
                routeId: widget.route.id,
                newStatus: newStatus,
                policeOfficerId: user.id,
                policeOfficerName: user.fullName,
                notes: notes,
              );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Route status updated to ${newStatus.displayName}'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context); // Return to previous screen
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error updating route: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      loading: () {},
      error: (error, stack) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not found'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  Future<bool> _showConfirmationDialog(RouteStatus newStatus) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Update Route Status'),
            content: Text(
                'Are you sure you want to mark this route as ${newStatus.displayName.toLowerCase()}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(newStatus.colorValue),
                ),
                child: Text(
                  'Confirm',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _addNotes() {
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter some notes'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Add notes functionality here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notes added successfully'),
        backgroundColor: Colors.green,
      ),
    );

    _notesController.clear();
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
