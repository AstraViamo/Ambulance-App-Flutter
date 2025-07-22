// lib/screens/ambulance_list_screen.dart - Responsive version

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ambulance_model.dart';
import '../providers/ambulance_providers.dart';
import '../providers/auth_provider.dart';
import 'ambulance_details_screen.dart';
import 'create_ambulance_screen.dart';

class AmbulanceListScreen extends ConsumerStatefulWidget {
  const AmbulanceListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AmbulanceListScreen> createState() =>
      _AmbulanceListScreenState();
}

class _AmbulanceListScreenState extends ConsumerState<AmbulanceListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? hospitalId;

  @override
  void initState() {
    super.initState();
    _loadHospitalId();
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

  void _navigateToCreateAmbulance() {
    if (hospitalId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateAmbulanceScreen(hospitalId: hospitalId!),
        ),
      );
    }
  }

  void _navigateToAmbulanceDetails(AmbulanceModel ambulance) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AmbulanceDetailsScreen(ambulance: ambulance),
      ),
    );
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
                print('Add button in AppBar clicked');
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
          // Statistics cards - RESPONSIVE
          ambulanceStats.when(
            data: (stats) => _buildResponsiveStatsSection(stats),
            loading: () => SizedBox(
                height: _getStatsHeight(context),
                child: const Center(child: CircularProgressIndicator())),
            error: (error, stack) => Container(
              height: _getStatsHeight(context),
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text('Error loading stats: $error',
                    style: const TextStyle(color: Colors.red)),
              ),
            ),
          ),

          // Search bar - RESPONSIVE
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _getHorizontalPadding(context),
              vertical: 16,
            ),
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
              margin: EdgeInsets.symmetric(
                horizontal: _getHorizontalPadding(context),
                vertical: 8,
              ),
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

          // Ambulance list - RESPONSIVE
          Expanded(
            child: ambulancesAsync.when(
              data: (ambulances) {
                if (ambulances.isEmpty) {
                  return _buildEmptyState();
                }
                return _buildResponsiveAmbulanceList(ambulances, isLoading);
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
                print('FloatingActionButton clicked');
                _navigateToCreateAmbulance();
              },
              backgroundColor: Colors.blue.shade700,
              tooltip: 'Add New Ambulance',
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  // RESPONSIVE HELPER METHODS
  double _getHorizontalPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 12.0; // Very small phones
    if (screenWidth < 400) return 14.0; // Small phones
    return 16.0; // Normal and larger phones
  }

  double _getStatsHeight(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 110.0; // Very small phones
    if (screenWidth < 400) return 115.0; // Small phones
    return 120.0; // Normal and larger phones
  }

  double _getStatsFontSize(BuildContext context, {bool isValue = false}) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (isValue) {
      if (screenWidth < 360) return 14.0; // Very small phones
      if (screenWidth < 400) return 16.0; // Small phones
      return 18.0; // Normal and larger phones
    } else {
      if (screenWidth < 360) return 8.0; // Very small phones
      if (screenWidth < 400) return 9.0; // Small phones
      return 10.0; // Normal and larger phones
    }
  }

  double _getStatsIconSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 20.0; // Very small phones
    if (screenWidth < 400) return 22.0; // Small phones
    return 24.0; // Normal and larger phones
  }

  // RESPONSIVE STATS SECTION
  Widget _buildResponsiveStatsSection(Map<String, int> stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        // For very small screens, show stats in 2x2 grid
        if (screenWidth < 360) {
          return Container(
            height:
                _getStatsHeight(context) * 2 + 16, // Double height + padding
            padding: EdgeInsets.all(_getHorizontalPadding(context)),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildResponsiveStatCard('Total', stats['total'] ?? 0,
                          Colors.blue.shade700, Icons.local_shipping),
                      SizedBox(width: _getHorizontalPadding(context)),
                      _buildResponsiveStatCard(
                          'Available',
                          stats['available'] ?? 0,
                          Colors.green.shade700,
                          Icons.check_circle),
                    ],
                  ),
                ),
                SizedBox(height: _getHorizontalPadding(context)),
                Expanded(
                  child: Row(
                    children: [
                      _buildResponsiveStatCard('On Duty', stats['onDuty'] ?? 0,
                          Colors.orange.shade700, Icons.emergency),
                      SizedBox(width: _getHorizontalPadding(context)),
                      _buildResponsiveStatCard(
                          'Maintenance',
                          stats['maintenance'] ?? 0,
                          Colors.red.shade700,
                          Icons.build),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // For normal screens, show all in one row
        return Container(
          height: _getStatsHeight(context),
          padding: EdgeInsets.all(_getHorizontalPadding(context)),
          child: Row(
            children: [
              _buildResponsiveStatCard('Total', stats['total'] ?? 0,
                  Colors.blue.shade700, Icons.local_shipping),
              SizedBox(width: _getHorizontalPadding(context)),
              _buildResponsiveStatCard('Available', stats['available'] ?? 0,
                  Colors.green.shade700, Icons.check_circle),
              SizedBox(width: _getHorizontalPadding(context)),
              _buildResponsiveStatCard('On Duty', stats['onDuty'] ?? 0,
                  Colors.orange.shade700, Icons.emergency),
              SizedBox(width: _getHorizontalPadding(context)),
              _buildResponsiveStatCard('Maintenance', stats['maintenance'] ?? 0,
                  Colors.red.shade700, Icons.build),
            ],
          ),
        );
      },
    );
  }

  // RESPONSIVE STAT CARD
  Widget _buildResponsiveStatCard(
      String label, int value, Color color, IconData icon) {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            padding: EdgeInsets.all(constraints.maxWidth < 80 ? 8.0 : 12.0),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: _getStatsIconSize(context)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: _getStatsFontSize(context, isValue: true),
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: _getStatsFontSize(context),
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // RESPONSIVE AMBULANCE LIST
  Widget _buildResponsiveAmbulanceList(
      List<AmbulanceModel> ambulances, bool isLoading) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(ambulancesProvider(hospitalId!));
      },
      child: ListView.builder(
        padding:
            EdgeInsets.symmetric(horizontal: _getHorizontalPadding(context)),
        itemCount: ambulances.length,
        itemBuilder: (context, index) {
          final ambulance = ambulances[index];
          return _buildResponsiveAmbulanceCard(ambulance, isLoading);
        },
      ),
    );
  }

  // RESPONSIVE AMBULANCE CARD
  Widget _buildResponsiveAmbulanceCard(
      AmbulanceModel ambulance, bool isLoading) {
    final statusColor = Color(AmbulanceStatus.getStatusColor(ambulance.status));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToAmbulanceDetails(ambulance),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(_getHorizontalPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row - RESPONSIVE
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
                      size: _getStatsIconSize(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // License plate - RESPONSIVE with overflow protection
                        Text(
                          ambulance.licensePlate,
                          style: TextStyle(
                            fontSize: _getLicensePlateFontSize(context),
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Model - RESPONSIVE with overflow protection
                        Text(
                          ambulance.model,
                          style: TextStyle(
                            fontSize: _getModelFontSize(context),
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Status badge - RESPONSIVE
                  _buildResponsiveStatusBadge(
                      ambulance.statusDisplayName, statusColor),
                ],
              ),

              const SizedBox(height: 12),

              // Driver info - RESPONSIVE
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ambulance.currentDriverId ?? 'No driver assigned',
                      style: TextStyle(
                        fontSize: _getDriverFontSize(context),
                        fontWeight: ambulance.currentDriverId != null
                            ? FontWeight.w500
                            : FontWeight.normal,
                        color: ambulance.currentDriverId != null
                            ? Colors.grey.shade700
                            : Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Last updated - RESPONSIVE
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Updated ${_getTimeAgo(ambulance.updatedAt)}',
                      style: TextStyle(
                        fontSize: _getTimeFontSize(context),
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  // RESPONSIVE STATUS BADGE
  Widget _buildResponsiveStatusBadge(String status, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth < 100 ? 6.0 : 8.0,
            vertical: 4.0,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              status,
              style: TextStyle(
                fontSize: _getStatusFontSize(context),
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
            ),
          ),
        );
      },
    );
  }

  // RESPONSIVE FONT SIZE HELPERS
  double _getLicensePlateFontSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 14.0; // Very small phones
    if (screenWidth < 400) return 15.0; // Small phones
    return 16.0; // Normal and larger phones
  }

  double _getModelFontSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 12.0; // Very small phones
    if (screenWidth < 400) return 13.0; // Small phones
    return 14.0; // Normal and larger phones
  }

  double _getDriverFontSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 12.0; // Very small phones
    if (screenWidth < 400) return 13.0; // Small phones
    return 14.0; // Normal and larger phones
  }

  double _getTimeFontSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 10.0; // Very small phones
    if (screenWidth < 400) return 11.0; // Small phones
    return 12.0; // Normal and larger phones
  }

  double _getStatusFontSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 10.0; // Very small phones
    if (screenWidth < 400) return 11.0; // Small phones
    return 12.0; // Normal and larger phones
  }

  // HELPER METHODS
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
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
            query.isEmpty
                ? 'No ambulances found'
                : 'No ambulances match your search',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            query.isEmpty
                ? 'Add your first ambulance to get started'
                : 'Try adjusting your search terms',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          if (query.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToCreateAmbulance,
              icon: const Icon(Icons.add),
              label: const Text('Add Ambulance'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
