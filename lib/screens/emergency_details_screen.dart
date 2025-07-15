// lib/screens/emergency_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ambulance_model.dart';
import '../models/emergency_model.dart';
import '../providers/emergency_providers.dart';

class EmergencyDetailsScreen extends ConsumerStatefulWidget {
  final EmergencyModel emergency;

  const EmergencyDetailsScreen({
    Key? key,
    required this.emergency,
  }) : super(key: key);

  @override
  ConsumerState<EmergencyDetailsScreen> createState() =>
      _EmergencyDetailsScreenState();
}

class _EmergencyDetailsScreenState
    extends ConsumerState<EmergencyDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final priorityColor = Color(widget.emergency.priority.colorValue);
    final statusColor = Color(widget.emergency.status.colorValue);
    final assignmentState = ref.watch(emergencyAssignmentProvider);
    final isLoading = ref.watch(emergencyLoadingProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Emergency Details',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: priorityColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _handleAction(context, value),
            itemBuilder: (context) => [
              if (widget.emergency.status != EmergencyStatus.completed &&
                  widget.emergency.status != EmergencyStatus.cancelled) ...[
                const PopupMenuItem(
                    value: 'update_status', child: Text('Update Status')),
                if (widget.emergency.isAssigned)
                  const PopupMenuItem(
                      value: 'cancel_assignment',
                      child: Text('Cancel Assignment')),
                if (!widget.emergency.isAssigned)
                  const PopupMenuItem(
                      value: 'find_ambulance', child: Text('Find Ambulance')),
                const PopupMenuItem(
                    value: 'complete', child: Text('Mark Complete')),
              ],
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    priorityColor,
                    priorityColor.withOpacity(0.8),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.emergency,
                      size: 40,
                      color: priorityColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.emergency.callerName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.emergency.callerPhone,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.emergency.priorityDisplayName,
                          style: TextStyle(
                            color: priorityColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.emergency.statusDisplayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Emergency Information Card
                  _buildInfoCard(
                    title: 'Emergency Information',
                    icon: Icons.info_outline,
                    children: [
                      _buildInfoRow(
                          'Description', widget.emergency.description),
                      _buildInfoRow('Created',
                          _formatDateTime(widget.emergency.createdAt)),
                      _buildInfoRow(
                          'Time Elapsed', widget.emergency.timeSinceCreated),
                      if (widget.emergency.notes != null)
                        _buildInfoRow('Notes', widget.emergency.notes!),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Location Information Card
                  _buildInfoCard(
                    title: 'Patient Location',
                    icon: Icons.location_on,
                    children: [
                      _buildInfoRow(
                          'Address', widget.emergency.patientAddressString),
                      _buildInfoRow(
                        'Coordinates',
                        '${widget.emergency.patientLat.toStringAsFixed(6)}, ${widget.emergency.patientLng.toStringAsFixed(6)}',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Assignment Information Card
                  _buildInfoCard(
                    title: 'Assignment Details',
                    icon: Icons.local_shipping,
                    children: [
                      if (widget.emergency.isAssigned) ...[
                        _buildInfoRow('Ambulance ID',
                            widget.emergency.assignedAmbulanceId!),
                        _buildInfoRow('Driver ID',
                            widget.emergency.assignedDriverId ?? 'Unknown'),
                        _buildInfoRow('Assigned At',
                            _formatDateTime(widget.emergency.assignedAt!)),
                        if (widget.emergency.estimatedArrival != null)
                          _buildInfoRow(
                            'Estimated Arrival',
                            _formatDateTime(widget.emergency.estimatedArrival!),
                          ),
                        if (widget.emergency.actualArrival != null)
                          _buildInfoRow(
                            'Actual Arrival',
                            _formatDateTime(widget.emergency.actualArrival!),
                          ),
                      ] else ...[
                        _buildInfoRow('Status', 'No ambulance assigned'),
                        const SizedBox(height: 8),
                        if (!isLoading &&
                            assignmentState.nearestAmbulance == null)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _findNearestAmbulance,
                              icon: const Icon(Icons.search),
                              label: const Text('Find Nearest Ambulance'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Nearest Ambulance Card (if found)
                  if (assignmentState.nearestAmbulance != null)
                    _buildAmbulanceAssignmentCard(assignmentState),

                  const SizedBox(height: 24),

                  // Action Buttons
                  if (widget.emergency.status != EmergencyStatus.completed &&
                      widget.emergency.status != EmergencyStatus.cancelled) ...[
                    Row(
                      children: [
                        if (!widget.emergency.isAssigned) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  isLoading ? null : _findNearestAmbulance,
                              icon: const Icon(Icons.search),
                              label: const Text('Find Ambulance'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isLoading ? null : _cancelAssignment,
                              icon: const Icon(Icons.cancel),
                              label: const Text('Cancel Assignment'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isLoading ? null : _completeEmergency,
                            icon: const Icon(Icons.check),
                            label: const Text('Complete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : _showStatusDialog,
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Update Status'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
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
                Icon(icon, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
                color: Colors.grey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbulanceAssignmentCard(EmergencyAssignmentState state) {
    final ambulance = state.nearestAmbulance!;
    final distance = state.distance;

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
                Icon(Icons.local_shipping, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  'Nearest Available Ambulance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.local_shipping,
                    color: Colors.green.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ambulance.licensePlate,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ambulance.model,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (distance != null)
                        Text(
                          'Distance: ${distance.toStringAsFixed(2)} km',
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
            const SizedBox(height: 16),
            if (!state.isAssigned && !state.isLoading)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _assignAmbulance(ambulance),
                  icon: const Icon(Icons.assignment),
                  label: const Text('Assign This Ambulance'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            if (state.isLoading)
              const Center(child: CircularProgressIndicator()),
            if (state.isAssigned)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'Ambulance has been assigned successfully',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _handleAction(BuildContext context, String action) {
    switch (action) {
      case 'update_status':
        _showStatusDialog();
        break;
      case 'cancel_assignment':
        _cancelAssignment();
        break;
      case 'find_ambulance':
        _findNearestAmbulance();
        break;
      case 'complete':
        _completeEmergency();
        break;
      case 'delete':
        _showDeleteDialog();
        break;
    }
  }

  Future<void> _findNearestAmbulance() async {
    final notifier = ref.read(emergencyAssignmentProvider.notifier);
    await notifier.findNearestAmbulance(
      hospitalId: widget.emergency.hospitalId,
      patientLat: widget.emergency.patientLat,
      patientLng: widget.emergency.patientLng,
    );

    final state = ref.read(emergencyAssignmentProvider);
    if (state.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _assignAmbulance(AmbulanceModel ambulance) async {
    final notifier = ref.read(emergencyAssignmentProvider.notifier);
    final success = await notifier.assignAmbulance(
      emergencyId: widget.emergency.id,
      ambulanceId: ambulance.id,
      driverId: ambulance.currentDriverId!,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ambulance assigned successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the emergency data
      Navigator.pop(context);
    } else {
      final state = ref.read(emergencyAssignmentProvider);
      if (state.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error!),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelAssignment() async {
    final actions = ref.read(emergencyActionsProvider);
    final success = await actions.cancelAssignment(widget.emergency.id);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignment cancelled'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _completeEmergency() async {
    final actions = ref.read(emergencyActionsProvider);
    final success = await actions.completeEmergency(widget.emergency.id);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency completed'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _showStatusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Emergency Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: EmergencyStatus.values.map((status) {
            final color = Color(status.colorValue);
            return ListTile(
              leading: Icon(Icons.circle, color: color),
              title: Text(status.displayName),
              onTap: () async {
                Navigator.pop(context);
                final actions = ref.read(emergencyActionsProvider);
                final success = await actions.updateEmergencyStatus(
                  emergencyId: widget.emergency.id,
                  status: status,
                );
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Status updated to ${status.displayName}'),
                    ),
                  );
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Emergency'),
        content: const Text(
          'Are you sure you want to delete this emergency? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final actions = ref.read(emergencyActionsProvider);
              final success =
                  await actions.deleteEmergency(widget.emergency.id);
              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Emergency deleted'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
