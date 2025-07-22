// Complete Emergency Details Screen with all modules integrated
// Replace your lib/screens/emergency_details_screen.dart file with this version

// =============================================================================
// MODULE 4: FINAL INTEGRATION - COMPLETE EMERGENCY DETAILS SCREEN
// =============================================================================

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
    // Initialize assignment state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(emergencyAssignmentProvider.notifier).clearAssignment();
    });
  }

  @override
  Widget build(BuildContext context) {
    final assignmentState = ref.watch(emergencyAssignmentProvider);
    final priorityColor = Color(widget.emergency.priority.colorValue);

    // Listen for state changes and show notifications
    ref.listen<EmergencyAssignmentState>(emergencyAssignmentProvider,
        (previous, next) {
      if (next.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      if (next.isSuccess && next.isAssigned && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '🚑 Ambulance assigned successfully!\n📍 Route has been created'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Emergency Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                    value: 'auto_assign', child: Text('Auto-Assign')),
              ],
              if (widget.emergency.isAssigned && !widget.emergency.isCompleted)
                const PopupMenuItem(value: 'complete', child: Text('Complete')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section with Emergency Summary
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
                  Icon(
                    Icons.emergency,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.emergency.priorityBadge,
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

                  // Location Information Card
                  _buildInfoCard(
                    title: 'Patient Location',
                    icon: Icons.location_on,
                    children: [
                      _buildInfoRow(
                          'Address',
                          widget.emergency.patientAddressString,
                          Icons.location_on),
                      _buildInfoRow('Coordinates',
                          widget.emergency.coordinatesString, Icons.gps_fixed),
                    ],
                  ),

                  // Ambulance Assignment Card
                  _buildInfoCard(
                    title: 'Ambulance Assignment',
                    icon: Icons.local_shipping,
                    headerColor: widget.emergency.isAssigned
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                    children: [
                      if (widget.emergency.isAssigned) ...[
                        _buildInfoRow(
                            'Ambulance ID',
                            widget.emergency.assignedAmbulanceId ?? 'Unknown',
                            Icons.local_shipping,
                            statusColor: Colors.green.shade700),
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
                            Icons.timer,
                            statusColor: widget.emergency.isOverdue
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
                          ),
                        if (widget.emergency.actualArrival != null)
                          _buildInfoRow(
                            'Actual Arrival',
                            _formatDateTime(widget.emergency.actualArrival!),
                            Icons.check_circle,
                            statusColor: Colors.green.shade700,
                          ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.warning_amber,
                                  color: Colors.orange.shade700, size: 32),
                              const SizedBox(height: 8),
                              Text(
                                'No Ambulance Assigned',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Please assign an ambulance to respond to this emergency',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Assignment Actions Section
                  if (!widget.emergency.isAssigned &&
                      !assignmentState.isLoading) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _findNearestAmbulance,
                            icon: const Icon(Icons.search),
                            label: const Text('Find Ambulance'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _autoAssignNearestAmbulance,
                            icon: const Icon(Icons.auto_fix_high),
                            label: const Text('Auto-Assign'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Assignment Loading State
                  if (assignmentState.isLoading)
                    _buildLoadingIndicator(assignmentState.statusMessage),

                  // Assignment Error State
                  if (assignmentState.error != null)
                    _buildErrorDisplay(
                      assignmentState.error!,
                      () => ref
                          .read(emergencyAssignmentProvider.notifier)
                          .resetState(),
                    ),

                  // Nearby Ambulances List
                  if (assignmentState.hasNearbyAmbulances &&
                      !widget.emergency.isAssigned) ...[
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      title:
                          'Available Ambulances (${assignmentState.nearbyAmbulances!.length})',
                      icon: Icons.local_shipping,
                      headerColor: Colors.blue.shade700,
                      children: [
                        ...assignmentState.nearbyAmbulances!
                            .map((ambulance) => _buildAmbulanceRow(ambulance))
                            .toList(),
                        const SizedBox(height: 8),
                        if (assignmentState.selectedAmbulance != null)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _assignAmbulance(
                                  assignmentState.selectedAmbulance!),
                              icon: const Icon(Icons.assignment),
                              label: Text(
                                'Assign ${assignmentState.selectedAmbulance!.licensePlate}',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],

                  // Completion Actions for Assigned Emergencies
                  if (widget.emergency.isAssigned &&
                      !widget.emergency.isCompleted) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _completeEmergency,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Mark Emergency Complete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================================
  // UI HELPER METHODS (From Module 2)
  // =============================================================================

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? headerColor,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    color: headerColor ?? Colors.blue.shade700, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: headerColor ?? Colors.blue.shade700,
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
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: statusColor ?? Colors.grey.shade900,
                fontWeight:
                    statusColor != null ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbulanceRow(AmbulanceModel ambulance) {
    final assignmentState = ref.watch(emergencyAssignmentProvider);
    final isSelected = assignmentState.selectedAmbulance?.id == ambulance.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
        ),
      ),
      child: InkWell(
        onTap: () => ref
            .read(emergencyAssignmentProvider.notifier)
            .selectAmbulance(ambulance),
        child: Row(
          children: [
            Icon(
              Icons.local_shipping,
              color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ambulance.licensePlate,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.blue.shade700 : Colors.black,
                    ),
                  ),
                  Text(
                    ambulance.model,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (assignmentState.distance != null)
              Text(
                '${(assignmentState.distance! / 1000).toStringAsFixed(1)} km',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.blue.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorDisplay(String error, VoidCallback? onRetry) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(error,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 14)),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeStr = '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';

    if (dateOnly.isAtSameMomentAs(today)) {
      return 'Today $timeStr';
    } else if (dateOnly
        .isAtSameMomentAs(today.subtract(const Duration(days: 1)))) {
      return 'Yesterday $timeStr';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} $timeStr';
    }
  }

  void _showComingSoon(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.construction, color: Colors.orange.shade600),
            const SizedBox(width: 12),
            const Text('Coming Soon'),
          ],
        ),
        content: Text('$feature functionality is coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade600),
            const SizedBox(width: 12),
            const Text('Delete Emergency'),
          ],
        ),
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
              await _deleteEmergency();
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // =============================================================================
  // ACTION METHODS (Using Enhanced Providers from Module 1)
  // =============================================================================

  Future<void> _findNearestAmbulance() async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser?.roleSpecificData.hospitalId == null) {
        throw Exception('Hospital ID not found');
      }

      final hospitalId = currentUser!.roleSpecificData.hospitalId!;
      await ref.read(emergencyAssignmentProvider.notifier).findNearestAmbulance(
            hospitalId: hospitalId,
            patientLat: widget.emergency.patientLat,
            patientLng: widget.emergency.patientLng,
          );
    } catch (e) {
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

  Future<void> _autoAssignNearestAmbulance() async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser?.roleSpecificData.hospitalId == null) {
        throw Exception('Hospital ID not found');
      }

      final hospitalId = currentUser!.roleSpecificData.hospitalId!;
      final success = await ref
          .read(emergencyAssignmentProvider.notifier)
          .autoAssignNearestAmbulance(
            emergencyId: widget.emergency.id,
            hospitalId: hospitalId,
          );

      if (success && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-assignment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assignAmbulance(AmbulanceModel ambulance) async {
    try {
      if (ambulance.currentDriverId == null ||
          ambulance.currentDriverId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot assign ambulance: No driver assigned'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final success =
          await ref.read(emergencyAssignmentProvider.notifier).assignAmbulance(
                emergencyId: widget.emergency.id,
                ambulanceId: ambulance.id,
                driverId: ambulance.currentDriverId!,
              );

      if (success && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign ambulance: $e'),
            backgroundColor: Colors.red,
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

  Future<void> _deleteEmergency() async {
    try {
      final actions = ref.read(emergencyActionsProvider);
      final success = await actions.deleteEmergency(widget.emergency.id);

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete emergency: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
