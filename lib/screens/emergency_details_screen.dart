// lib/screens/emergency_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ambulance_model.dart';
import '../models/emergency_model.dart';
import '../providers/auth_provider.dart';
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
  void initState() {
    super.initState();
    // Clear any previous assignment state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(emergencyAssignmentProvider.notifier).clearAssignment();
    });
  }

  @override
  Widget build(BuildContext context) {
    final assignmentState = ref.watch(emergencyAssignmentProvider);
    final isLoading = assignmentState.isLoading;
    final priorityColor = Color(widget.emergency.priority.colorValue);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Emergency Details',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: priorityColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              switch (value) {
                case 'edit':
                  _showComingSoon('Edit Emergency');
                  break;
                case 'find_ambulance':
                  await _findNearestAmbulance();
                  break;
                case 'auto_assign':
                  await _autoAssignNearestAmbulance();
                  break;
                case 'complete':
                  await _completeEmergency();
                  break;
                case 'delete':
                  _showDeleteDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit Emergency')),
              if (!widget.emergency.isAssigned) ...[
                const PopupMenuItem(
                    value: 'find_ambulance', child: Text('Find Ambulance')),
                const PopupMenuItem(
                    value: 'auto_assign', child: Text('Auto-Assign Nearest')),
              ],
              if (widget.emergency.isAssigned &&
                  widget.emergency.status != EmergencyStatus.completed) ...[
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
                    widget.emergency.priorityDisplayName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.emergency.statusDisplayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.emergency.timeSinceCreated,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Content Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Caller Information Card
                  _buildInfoCard(
                    title: 'Caller Information',
                    icon: Icons.person,
                    children: [
                      _buildInfoRow(
                          'Name', widget.emergency.callerName, Icons.person),
                      _buildInfoRow(
                          'Phone', widget.emergency.callerPhone, Icons.phone),
                      _buildInfoRow(
                          'Time',
                          _formatDateTime(widget.emergency.createdAt),
                          Icons.access_time),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Emergency Details Card
                  _buildInfoCard(
                    title: 'Emergency Details',
                    icon: Icons.description,
                    children: [
                      _buildInfoRow('Description', widget.emergency.description,
                          Icons.description),
                      _buildInfoRow(
                          'Priority',
                          widget.emergency.priorityDisplayName,
                          Icons.priority_high,
                          statusColor: priorityColor),
                      _buildInfoRow('Status',
                          widget.emergency.statusDisplayName, Icons.info,
                          statusColor:
                              Color(widget.emergency.status.colorValue)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Location Information Card
                  _buildInfoCard(
                    title: 'Patient Location',
                    icon: Icons.location_on,
                    children: [
                      _buildInfoRow(
                          'Address',
                          widget.emergency.patientAddressString,
                          Icons.location_on),
                      _buildInfoRow(
                          'Coordinates',
                          '${widget.emergency.patientLat.toStringAsFixed(6)}, ${widget.emergency.patientLng.toStringAsFixed(6)}',
                          Icons.gps_fixed),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Ambulance Assignment Card
                  _buildInfoCard(
                    title: 'Ambulance Assignment',
                    icon: Icons.local_shipping,
                    children: [
                      if (widget.emergency.isAssigned) ...[
                        _buildInfoRow(
                            'Ambulance ID',
                            widget.emergency.assignedAmbulanceId ?? 'Unknown',
                            Icons.local_shipping),
                        _buildInfoRow(
                            'Driver ID',
                            widget.emergency.assignedDriverId ?? 'Unknown',
                            Icons.person),
                        _buildInfoRow(
                            'Assigned At',
                            _formatDateTime(widget.emergency.assignedAt!),
                            Icons.schedule),
                        if (widget.emergency.estimatedArrival != null)
                          _buildInfoRow(
                            'Estimated Arrival',
                            _formatDateTime(widget.emergency.estimatedArrival!),
                            Icons.schedule,
                          ),
                        if (widget.emergency.actualArrival != null)
                          _buildInfoRow(
                            'Actual Arrival',
                            _formatDateTime(widget.emergency.actualArrival!),
                            Icons.check_circle,
                            statusColor: Colors.green,
                          ),
                      ] else ...[
                        _buildInfoRow(
                            'Status', 'No ambulance assigned', Icons.warning,
                            statusColor: Colors.orange),
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
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isLoading
                                  ? null
                                  : _autoAssignNearestAmbulance,
                              icon: const Icon(Icons.auto_fix_high),
                              label: const Text('Auto-Assign'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isLoading ? null : _completeEmergency,
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Mark Complete'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Loading indicator
                  if (isLoading)
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Processing ambulance assignment...'),
                        ],
                      ),
                    ),

                  // Error message
                  if (assignmentState.error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              assignmentState.error!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
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

  Widget _buildInfoRow(String label, String value, IconData icon,
      {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: statusColor ?? Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: statusColor ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbulanceAssignmentCard(
      EmergencyAssignmentState assignmentState) {
    final ambulance = assignmentState.nearestAmbulance!;
    final distance = assignmentState.distance;

    return Card(
      elevation: 3,
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
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.local_shipping,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nearest Ambulance Found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      Text(
                        ambulance.licensePlate,
                        style: const TextStyle(
                          fontSize: 18,
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

            // Assignment status and buttons
            if (!assignmentState.isAssigned && !assignmentState.isLoading) ...[
              // Driver validation
              if (ambulance.currentDriverId == null ||
                  ambulance.currentDriverId!.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This ambulance has no assigned driver. Please assign a driver first.',
                          style: TextStyle(color: Colors.orange.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Ready to assign
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _assignAmbulance(ambulance),
                    icon: const Icon(Icons.assignment),
                    label: const Text(
                      'Assign This Ambulance\n(Route will be created)',
                      textAlign: TextAlign.center,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],

            if (assignmentState.isLoading) ...[
              Container(
                padding: const EdgeInsets.all(16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('Assigning ambulance and creating route...'),
                  ],
                ),
              ),
            ],

            if (assignmentState.isAssigned) ...[
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
                    Expanded(
                      child: Text(
                        '✅ Ambulance assigned successfully!\n📍 Route created and police notified',
                        style: TextStyle(
                          color: Colors.green.shade700,
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

  Future<void> _findNearestAmbulance() async {
    try {
      print('🔍 Finding nearest ambulance...');

      // Get current user to determine hospital ID
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser?.roleSpecificData.hospitalId == null) {
        throw Exception('Hospital ID not found');
      }

      final hospitalId = currentUser!.roleSpecificData.hospitalId!;

      // Use the assignment provider to find nearest ambulance
      final assignmentNotifier = ref.read(emergencyAssignmentProvider.notifier);

      await assignmentNotifier.findNearestAmbulance(
        hospitalId: hospitalId,
        patientLat: widget.emergency.patientLat,
        patientLng: widget.emergency.patientLng,
      );

      print('✅ Nearest ambulance search completed');
    } catch (e) {
      print('❌ Error finding nearest ambulance: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error finding ambulance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assignAmbulance(AmbulanceModel ambulance) async {
    try {
      print('🚀 Starting ambulance assignment with route creation');

      // Use the updated emergency assignment provider
      final assignmentNotifier = ref.read(emergencyAssignmentProvider.notifier);

      // Ensure ambulance has a driver
      if (ambulance.currentDriverId == null ||
          ambulance.currentDriverId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Cannot assign ambulance: No driver assigned to this ambulance'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Call the enhanced assignment method that creates routes
      final success = await assignmentNotifier.assignAmbulance(
        emergencyId: widget.emergency.id,
        ambulanceId: ambulance.id,
        driverId: ambulance.currentDriverId!,
      );

      if (success && mounted) {
        print('✅ Ambulance assigned successfully with route creation');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🚑 Ambulance ${ambulance.licensePlate} assigned successfully!\n'
              '📍 Route has been calculated and sent to police',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        // Navigate back to the previous screen
        Navigator.pop(context);
      } else {
        print('❌ Ambulance assignment failed');
        throw Exception('Assignment failed - please try again');
      }
    } catch (e) {
      print('❌ Assignment error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign ambulance: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _autoAssignNearestAmbulance() async {
    try {
      print('🎯 Auto-assigning nearest ambulance with route creation...');

      // Get current user to determine hospital ID
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser?.roleSpecificData.hospitalId == null) {
        throw Exception('Hospital ID not found');
      }

      final hospitalId = currentUser!.roleSpecificData.hospitalId!;

      // Use the assignment provider for auto-assignment
      final assignmentNotifier = ref.read(emergencyAssignmentProvider.notifier);

      final success = await assignmentNotifier.autoAssignNearestAmbulance(
        emergencyId: widget.emergency.id,
        hospitalId: hospitalId,
      );

      if (success && mounted) {
        print('✅ Auto-assignment completed successfully with route creation');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🎯 Nearest ambulance auto-assigned successfully!\n'
              '📍 Route calculated and police notified',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Navigate back
        Navigator.pop(context);
      } else {
        throw Exception(
            'Auto-assignment failed - no available ambulances found');
      }
    } catch (e) {
      print('❌ Auto-assignment error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-assignment failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _completeEmergency() async {
    try {
      final actions = ref.read(emergencyActionsProvider);
      final success = await actions.completeEmergency(widget.emergency.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency marked as completed'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete emergency: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Emergency'),
        content: const Text(
          'Are you sure you want to delete this emergency? This action cannot be undone.',
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
              if (success && context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Emergency deleted successfully'),
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

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
