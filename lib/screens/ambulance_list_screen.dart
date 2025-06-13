// lib/screens/ambulance_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ambulance_model.dart';
import '../providers/ambulance_providers.dart';
import '../providers/auth_provider.dart';
import '../screens/ambulance_details_screen.dart';
import '../screens/create_ambulance_screen.dart';

class AmbulanceListScreen extends ConsumerStatefulWidget {
  const AmbulanceListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AmbulanceListScreen> createState() =>
      _AmbulanceListScreenState();
}

class _AmbulanceListScreenState extends ConsumerState<AmbulanceListScreen> {
  final _searchController = TextEditingController();
  String? hospitalId;

  @override
  void initState() {
    super.initState();
    _loadHospitalId();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHospitalId() async {
    try {
      print('Loading hospital ID...'); // Debug log
      final currentUser = await ref.read(currentUserProvider.future);
      print('Current user: $currentUser'); // Debug log

      if (currentUser != null) {
        final loadedHospitalId = currentUser.roleSpecificData.hospitalId;
        print('Loaded hospital ID: $loadedHospitalId'); // Debug log

        if (loadedHospitalId != null && loadedHospitalId.isNotEmpty) {
          setState(() {
            hospitalId = loadedHospitalId;
          });
          ref.read(currentHospitalIdProvider.notifier).state = hospitalId;
          print('Hospital ID set successfully: $hospitalId'); // Debug log
        } else {
          print('Hospital ID is null or empty'); // Debug log
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: No hospital ID found in user profile'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        print('Current user is null'); // Debug log
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: User not found. Please log in again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading hospital ID: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (hospitalId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ambulance Management',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.blue.shade700,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading hospital information...'),
              SizedBox(height: 8),
              Text(
                'If this takes too long, please try logging out and back in.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final ambulancesAsync = ref.watch(sortedAmbulancesProvider(hospitalId!));
    final ambulanceStats = ref.watch(ambulanceStatsProvider(hospitalId!));
    final isLoading = ref.watch(ambulanceLoadingProvider);
    final error = ref.watch(ambulanceErrorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ambulance Management',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (hospitalId != null) ...[
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () {
                print('Add button in AppBar clicked'); // Debug log
                _navigateToCreateAmbulance();
              },
              tooltip: 'Add New Ambulance',
            ),
            PopupMenuButton<AmbulanceSortOption>(
              icon: const Icon(Icons.sort, color: Colors.white),
              onSelected: (option) {
                ref.read(ambulanceSortOptionProvider.notifier).state = option;
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: AmbulanceSortOption.newest,
                  child: Text('Newest First'),
                ),
                const PopupMenuItem(
                  value: AmbulanceSortOption.oldest,
                  child: Text('Oldest First'),
                ),
                const PopupMenuItem(
                  value: AmbulanceSortOption.licensePlate,
                  child: Text('License Plate'),
                ),
                const PopupMenuItem(
                  value: AmbulanceSortOption.model,
                  child: Text('Model'),
                ),
                const PopupMenuItem(
                  value: AmbulanceSortOption.status,
                  child: Text('Status'),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Statistics cards
          ambulanceStats.when(
            data: (stats) => _buildStatsSection(stats),
            loading: () => const SizedBox(
                height: 120, child: Center(child: CircularProgressIndicator())),
            error: (error, stack) => Container(
              height: 120,
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text('Error loading stats: $error',
                    style: const TextStyle(color: Colors.red)),
              ),
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by license plate or model...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(ambulanceSearchQueryProvider.notifier)
                              .state = '';
                        },
                      )
                    : null,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) {
                ref.read(ambulanceSearchQueryProvider.notifier).state = value;
              },
            ),
          ),

          // Error message
          if (error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(error,
                          style: TextStyle(color: Colors.red.shade700))),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        ref.read(ambulanceErrorProvider.notifier).state = null,
                  ),
                ],
              ),
            ),

          // Ambulance list
          Expanded(
            child: ambulancesAsync.when(
              data: (ambulances) {
                if (ambulances.isEmpty) {
                  return _buildEmptyState();
                }
                return _buildAmbulanceList(ambulances, isLoading);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 64, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text('Error: $error', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          ref.refresh(ambulancesProvider(hospitalId!)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: hospitalId != null
          ? FloatingActionButton(
              onPressed: () {
                print('FloatingActionButton clicked'); // Debug log
                _navigateToCreateAmbulance();
              },
              backgroundColor: Colors.blue.shade700,
              tooltip: 'Add New Ambulance',
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildStatsSection(Map<String, int> stats) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatCard('Total', stats['total'] ?? 0, Colors.blue.shade700,
              Icons.local_shipping),
          const SizedBox(width: 12),
          _buildStatCard('Available', stats['available'] ?? 0,
              Colors.green.shade700, Icons.check_circle),
          const SizedBox(width: 12),
          _buildStatCard('On Duty', stats['onDuty'] ?? 0,
              Colors.orange.shade700, Icons.emergency),
          const SizedBox(width: 12),
          _buildStatCard('Maintenance', stats['maintenance'] ?? 0,
              Colors.red.shade700, Icons.build),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final query = ref.watch(ambulanceSearchQueryProvider);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            query.isEmpty ? Icons.local_shipping : Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            query.isEmpty ? 'No ambulances yet' : 'No ambulances found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            query.isEmpty
                ? 'Add your first ambulance to get started'
                : 'Try adjusting your search terms',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          if (query.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                print('Empty state add button clicked'); // Debug log
                _navigateToCreateAmbulance();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Ambulance'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAmbulanceList(List<AmbulanceModel> ambulances, bool isLoading) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(ambulancesProvider(hospitalId!));
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: ambulances.length,
        itemBuilder: (context, index) {
          final ambulance = ambulances[index];
          return _buildAmbulanceCard(ambulance, isLoading);
        },
      ),
    );
  }

  Widget _buildAmbulanceCard(AmbulanceModel ambulance, bool isLoading) {
    final statusColor = Color(AmbulanceStatus.getStatusColor(ambulance.status));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToAmbulanceDetails(ambulance),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.local_shipping,
                      color: statusColor,
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
                            fontSize: 18,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ambulance.statusDisplayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    enabled: !isLoading,
                    onSelected: (value) =>
                        _handleAmbulanceAction(value, ambulance),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'view', child: Text('View Details')),
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (ambulance.status != AmbulanceStatus.onDuty) ...[
                        PopupMenuItem(
                          value: 'status',
                          child: Text('Change Status'),
                        ),
                        const PopupMenuItem(
                            value: 'delete', child: Text('Delete')),
                      ],
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Details row
              Row(
                children: [
                  if (ambulance.hasDriver) ...[
                    Icon(Icons.person, size: 16, color: Colors.green.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Driver Assigned',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else ...[
                    Icon(Icons.person_off,
                        size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'No Driver',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                  const SizedBox(width: 16),
                  Icon(Icons.access_time,
                      size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Updated ${_getTimeAgo(ambulance.updatedAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _handleAmbulanceAction(String action, AmbulanceModel ambulance) {
    switch (action) {
      case 'view':
        _navigateToAmbulanceDetails(ambulance);
        break;
      case 'edit':
        _navigateToEditAmbulance(ambulance);
        break;
      case 'status':
        _showStatusDialog(ambulance);
        break;
      case 'delete':
        _showDeleteDialog(ambulance);
        break;
    }
  }

  void _navigateToCreateAmbulance() {
    print('Navigate to create ambulance clicked'); // Debug log
    print('Hospital ID: $hospitalId'); // Debug log

    if (hospitalId == null || hospitalId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Error: Hospital ID not found. Please try logging in again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateAmbulanceScreen(hospitalId: hospitalId!),
        ),
      ).then((result) {
        print('Returned from create ambulance screen'); // Debug log
        // Refresh the list if ambulance was created
        if (result == true) {
          ref.refresh(ambulancesProvider(hospitalId!));
        }
      });
    } catch (e) {
      print('Error navigating to create ambulance: $e'); // Debug log
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening create screen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToEditAmbulance(AmbulanceModel ambulance) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateAmbulanceScreen(
          hospitalId: hospitalId!,
          ambulanceToEdit: ambulance,
        ),
      ),
    );
  }

  void _navigateToAmbulanceDetails(AmbulanceModel ambulance) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AmbulanceDetailsScreen(ambulance: ambulance),
      ),
    );
  }

  void _showStatusDialog(AmbulanceModel ambulance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Status for ${ambulance.licensePlate}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AmbulanceStatus.values.map((status) {
            return ListTile(
              leading: Icon(
                Icons.circle,
                color: Color(AmbulanceStatus.getStatusColor(status)),
              ),
              title: Text(status.displayName),
              onTap: () async {
                Navigator.pop(context);
                final actions = ref.read(ambulanceActionsProvider);
                final success =
                    await actions.updateStatus(ambulance.id, status);
                if (success && mounted) {
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

  void _showDeleteDialog(AmbulanceModel ambulance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Ambulance'),
        content: Text(
            'Are you sure you want to delete ${ambulance.licensePlate}? This action cannot be undone.'),
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
              if (success && mounted) {
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
}
