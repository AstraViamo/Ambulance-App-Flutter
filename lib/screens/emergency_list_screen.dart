// lib/screens/emergency_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/emergency_model.dart';
import '../providers/auth_provider.dart';
import '../providers/emergency_providers.dart';
import 'create_emergency_screen.dart';
import 'emergency_details_screen.dart';

class EmergencyListScreen extends ConsumerStatefulWidget {
  const EmergencyListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<EmergencyListScreen> createState() =>
      _EmergencyListScreenState();
}

class _EmergencyListScreenState extends ConsumerState<EmergencyListScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String? hospitalId;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHospitalId();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadHospitalId() async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser != null) {
        setState(() {
          hospitalId = currentUser.roleSpecificData.hospitalId;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading hospital data: $e'),
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
          title: const Text('Emergency Dispatch',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red.shade700,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading hospital information...'),
            ],
          ),
        ),
      );
    }

    final emergencyStats = ref.watch(emergencyStatsProvider(hospitalId!));
    final error = ref.watch(emergencyErrorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Dispatch',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _navigateToCreateEmergency,
            tooltip: 'Create Emergency',
          ),
          PopupMenuButton<EmergencySortOption>(
            icon: const Icon(Icons.sort, color: Colors.white),
            onSelected: (option) {
              ref.read(emergencySortOptionProvider.notifier).state = option;
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: EmergencySortOption.newest,
                child: Text('Newest First'),
              ),
              const PopupMenuItem(
                value: EmergencySortOption.oldest,
                child: Text('Oldest First'),
              ),
              const PopupMenuItem(
                value: EmergencySortOption.priority,
                child: Text('By Priority'),
              ),
              const PopupMenuItem(
                value: EmergencySortOption.status,
                child: Text('By Status'),
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
            Tab(text: 'Active', icon: Icon(Icons.emergency)),
            Tab(text: 'All', icon: Icon(Icons.list)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Statistics section
          emergencyStats.when(
            data: (stats) => _buildStatsSection(stats),
            loading: () => const SizedBox(
                height: 100, child: Center(child: CircularProgressIndicator())),
            error: (error, stack) => Container(
              height: 100,
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
                hintText: 'Search by caller name, phone, or description...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(emergencySearchQueryProvider.notifier)
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
                ref.read(emergencySearchQueryProvider.notifier).state = value;
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
                        ref.read(emergencyErrorProvider.notifier).state = null,
                  ),
                ],
              ),
            ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEmergencyList(hospitalId!, activeOnly: true),
                _buildEmergencyList(hospitalId!, activeOnly: false),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateEmergency,
        backgroundColor: Colors.red.shade700,
        tooltip: 'Create Emergency',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildStatsSection(Map<String, int> stats) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatCard(
            'Today',
            stats['todayTotal']?.toString() ?? '0',
            Colors.blue.shade700,
            Icons.today,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Active',
            stats['activeTotal']?.toString() ?? '0',
            Colors.orange.shade700,
            Icons.emergency,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Critical',
            stats['critical']?.toString() ?? '0',
            Colors.red.shade700,
            Icons.priority_high,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Pending',
            stats['pending']?.toString() ?? '0',
            Colors.amber.shade700,
            Icons.pending,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, Color color, IconData icon) {
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
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
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

  Widget _buildEmergencyList(String hospitalId, {required bool activeOnly}) {
    final emergenciesAsync = activeOnly
        ? ref.watch(sortedEmergenciesProvider(hospitalId))
        : ref.watch(sortedEmergenciesProvider(hospitalId));

    return emergenciesAsync.when(
      data: (emergencies) {
        // Filter active emergencies if needed
        final filteredEmergencies = activeOnly
            ? emergencies.where((e) => e.isActive).toList()
            : emergencies;

        if (filteredEmergencies.isEmpty) {
          return _buildEmptyState(activeOnly);
        }
        return _buildEmergencyListView(filteredEmergencies);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('Error: $error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.refresh(emergenciesProvider(hospitalId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool activeOnly) {
    final query = ref.watch(emergencySearchQueryProvider);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            query.isEmpty
                ? (activeOnly ? Icons.emergency : Icons.list)
                : Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            query.isEmpty
                ? (activeOnly ? 'No active emergencies' : 'No emergencies yet')
                : 'No emergencies found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            query.isEmpty
                ? (activeOnly
                    ? 'All emergencies have been resolved'
                    : 'Create your first emergency dispatch')
                : 'Try adjusting your search terms',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          if (query.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToCreateEmergency,
              icon: const Icon(Icons.add),
              label: const Text('Create Emergency'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmergencyListView(List<EmergencyModel> emergencies) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(emergenciesProvider(hospitalId!));
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: emergencies.length,
        itemBuilder: (context, index) {
          final emergency = emergencies[index];
          return _buildEmergencyCard(emergency);
        },
      ),
    );
  }

  Widget _buildEmergencyCard(EmergencyModel emergency) {
    final priorityColor = Color(emergency.priority.colorValue);
    final statusColor = Color(emergency.status.colorValue);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: emergency.isCritical ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: emergency.isCritical
            ? BorderSide(color: Colors.red.shade700, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _navigateToEmergencyDetails(emergency),
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
                      color: priorityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.emergency,
                      color: priorityColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              emergency.callerName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (emergency.isCritical) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'CRITICAL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          emergency.callerPhone,
                          style: TextStyle(
                            fontSize: 12,
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: priorityColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          emergency.priorityDisplayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          emergency.statusDisplayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                emergency.description,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Location
              Row(
                children: [
                  Icon(Icons.location_on,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      emergency.patientAddressString,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Footer row
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    emergency.timeSinceCreated,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  if (emergency.isAssigned) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.local_shipping,
                        size: 14, color: Colors.blue.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Ambulance Assigned',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (emergency.estimatedResponseTime != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.timer, size: 14, color: Colors.orange.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'ETA: ${emergency.estimatedResponseTime}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToCreateEmergency() {
    if (hospitalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hospital ID not found. Please try logging in again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEmergencyScreen(hospitalId: hospitalId!),
      ),
    ).then((result) {
      if (result == true) {
        ref.refresh(emergenciesProvider(hospitalId!));
      }
    });
  }

  void _navigateToEmergencyDetails(EmergencyModel emergency) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencyDetailsScreen(emergency: emergency),
      ),
    );
  }
}
