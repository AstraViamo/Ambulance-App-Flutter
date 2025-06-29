// lib/screens/ambulance_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ambulance_model.dart';
import '../models/user_model.dart';
import '../providers/ambulance_providers.dart';
import '../providers/driver_providers.dart';
import 'create_ambulance_screen.dart';

class AmbulanceDetailsScreen extends ConsumerWidget {
  final AmbulanceModel ambulance;

  const AmbulanceDetailsScreen({
    Key? key,
    required this.ambulance,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = Color(AmbulanceStatus.getStatusColor(ambulance.status));
    final isLoading = ref.watch(ambulanceLoadingProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          ambulance.licensePlate,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: statusColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _handleAction(context, ref, value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                value: 'status',
                child: Text('Change Status'),
              ),
              if (ambulance.status != AmbulanceStatus.onDuty)
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
                    statusColor,
                    statusColor.withOpacity(0.8),
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
                      Icons.local_shipping,
                      size: 40,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ambulance.licensePlate,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ambulance.model,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ambulance.statusDisplayName,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Details Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Basic Information Card
                  _buildInfoCard(
                    title: 'Basic Information',
                    icon: Icons.info_outline,
                    children: [
                      _buildInfoRow('License Plate', ambulance.licensePlate,
                          Icons.confirmation_number),
                      _buildInfoRow(
                          'Model', ambulance.model, Icons.local_shipping),
                      _buildInfoRow(
                          'Status', ambulance.statusDisplayName, Icons.circle,
                          statusColor: statusColor),
                      _buildInfoRow('Hospital ID', ambulance.hospitalId,
                          Icons.local_hospital),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Driver Information Card
                  _buildInfoCard(
                    title: 'Driver Information',
                    icon: Icons.person,
                    children: [
                      if (ambulance.hasDriver) ...[
                        _buildInfoRow(
                            'Driver Assigned', 'Yes', Icons.check_circle,
                            statusColor: Colors.green),
                        _buildInfoRow('Driver ID', ambulance.currentDriverId!,
                            Icons.badge),
                      ] else ...[
                        _buildInfoRow('Driver Assigned', 'No driver assigned',
                            Icons.person_off,
                            statusColor: Colors.grey),
                        const SizedBox(height: 8),
                        if (!isLoading)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _showAssignDriverDialog(context, ref),
                              icon: const Icon(Icons.person_add),
                              label: const Text('Assign Driver'),
                            ),
                          ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Location Information Card
                  _buildInfoCard(
                    title: 'Location Information',
                    icon: Icons.location_on,
                    children: [
                      if (ambulance.hasLocation) ...[
                        _buildInfoRow('Latitude', ambulance.latitude.toString(),
                            Icons.place),
                        _buildInfoRow('Longitude',
                            ambulance.longitude.toString(), Icons.place),
                        _buildInfoRow(
                            'Last Update',
                            ambulance.lastLocationUpdateFormatted,
                            Icons.access_time),
                      ] else ...[
                        _buildInfoRow('Location', 'No location data available',
                            Icons.location_off,
                            statusColor: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          'Location tracking requires an assigned driver',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Timestamps Card
                  _buildInfoCard(
                    title: 'Timestamps',
                    icon: Icons.schedule,
                    children: [
                      _buildInfoRow(
                          'Created',
                          _formatDateTime(ambulance.createdAt),
                          Icons.add_circle),
                      _buildInfoRow('Last Updated',
                          _formatDateTime(ambulance.updatedAt), Icons.update),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  if (ambulance.status != AmbulanceStatus.onDuty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isLoading
                                ? null
                                : () => _navigateToEdit(context),
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit Details'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isLoading
                                ? null
                                : () => _showStatusDialog(context, ref),
                            icon: const Icon(Icons.swap_horiz),
                            label: const Text('Change Status'),
                            style: OutlinedButton.styleFrom(
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
                        onPressed: isLoading
                            ? null
                            : () => _showDeleteDialog(context, ref),
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('Delete Ambulance',
                            style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber,
                              color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This ambulance is currently on duty and cannot be modified.',
                              style: TextStyle(color: Colors.orange.shade700),
                            ),
                          ),
                        ],
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

  Widget _buildInfoRow(String label, String value, IconData icon,
      {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'edit':
        _navigateToEdit(context);
        break;
      case 'status':
        _showStatusDialog(context, ref);
        break;
      case 'delete':
        _showDeleteDialog(context, ref);
        break;
    }
  }

  void _navigateToEdit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateAmbulanceScreen(
          hospitalId: ambulance.hospitalId,
          ambulanceToEdit: ambulance,
        ),
      ),
    );
  }

  void _showStatusDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Status for ${ambulance.licensePlate}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AmbulanceStatus.values.map((status) {
            final color = Color(AmbulanceStatus.getStatusColor(status));
            return ListTile(
              leading: Icon(Icons.circle, color: color),
              title: Text(status.displayName),
              subtitle: Text(_getStatusDescription(status)),
              onTap: () async {
                Navigator.pop(context);
                final actions = ref.read(ambulanceActionsProvider);
                final success =
                    await actions.updateStatus(ambulance.id, status);
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('Status updated to ${status.displayName}')),
                  );
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Ambulance'),
        content: Text(
          'Are you sure you want to delete ${ambulance.licensePlate}? '
          'This action cannot be undone and will remove all associated data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final actions = ref.read(ambulanceActionsProvider);
              final success = await actions.deleteAmbulance(ambulance.id);
              if (success && context.mounted) {
                Navigator.pop(context); // Go back to list
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Ambulance deleted successfully')),
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

  void _showAssignDriverDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _AssignDriverDialog(ambulance: ambulance),
    );
  }

  String _getStatusDescription(AmbulanceStatus status) {
    switch (status) {
      case AmbulanceStatus.available:
        return 'Ready for emergency response';
      case AmbulanceStatus.onDuty:
        return 'Currently responding to emergency';
      case AmbulanceStatus.maintenance:
        return 'Under maintenance or repair';
      case AmbulanceStatus.offline:
        return 'Not in service';
    }
  }
}

// Assign Driver Dialog Widget
class _AssignDriverDialog extends ConsumerStatefulWidget {
  final AmbulanceModel ambulance;

  const _AssignDriverDialog({required this.ambulance});

  @override
  ConsumerState<_AssignDriverDialog> createState() =>
      _AssignDriverDialogState();
}

class _AssignDriverDialogState extends ConsumerState<_AssignDriverDialog> {
  UserModel? selectedDriver;

  @override
  Widget build(BuildContext context) {
    final availableDriversAsync =
        ref.watch(availableDriversProvider(widget.ambulance.hospitalId));
    final isLoading = ref.watch(driverLoadingProvider);
    final error = ref.watch(driverErrorProvider);

    return AlertDialog(
      title: Text('Assign Driver to ${widget.ambulance.licensePlate}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select an available driver:'),
            const SizedBox(height: 16),

            // Error message
            if (error != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Text(error, style: TextStyle(color: Colors.red.shade700)),
              ),
            ],

            // Driver dropdown
            availableDriversAsync.when(
              data: (drivers) {
                if (drivers.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber,
                            color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No available drivers found. Make sure drivers are on shift and not assigned to active ambulances.',
                            style: TextStyle(color: Colors.orange.shade700),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<UserModel>(
                    value: selectedDriver,
                    hint: const Text('Select a driver'),
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: drivers.map((driver) {
                      return DropdownMenuItem<UserModel>(
                        value: driver,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driver.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'License: ${driver.roleSpecificData.licenseNumber}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (driver) {
                      setState(() {
                        selectedDriver = driver;
                      });
                      ref.read(driverErrorProvider.notifier).state = null;
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error loading drivers: $error',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ),

            if (selectedDriver != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Driver Details:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Name: ${selectedDriver!.fullName}'),
                    Text('Email: ${selectedDriver!.email}'),
                    Text('Phone: ${selectedDriver!.phoneNumber}'),
                    Text(
                        'License: ${selectedDriver!.roleSpecificData.licenseNumber}'),
                    if (selectedDriver!
                            .roleSpecificData.assignedAmbulances?.isNotEmpty ==
                        true)
                      Text(
                        'Currently assigned to ${selectedDriver!.roleSpecificData.assignedAmbulances!.length} ambulance(s)',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              (selectedDriver == null || isLoading) ? null : _assignDriver,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Assign Driver'),
        ),
      ],
    );
  }

  Future<void> _assignDriver() async {
    if (selectedDriver == null) return;

    final driverActions = ref.read(driverActionsProvider);
    final ambulanceActions = ref.read(ambulanceActionsProvider);

    // First assign ambulance to driver (updates driver's assigned ambulances list)
    final success1 = await driverActions.assignAmbulanceToDriver(
      selectedDriver!.id,
      widget.ambulance.id,
    );

    if (success1) {
      // Then update ambulance with current driver
      final success2 = await ambulanceActions.assignDriver(
        widget.ambulance.id,
        selectedDriver!.id,
      );

      if (success2 && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${selectedDriver!.fullName} assigned to ${widget.ambulance.licensePlate}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
