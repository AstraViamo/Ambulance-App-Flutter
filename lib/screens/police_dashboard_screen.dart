// lib/screens/police_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/route_model.dart';
import '../providers/auth_provider.dart';
import '../providers/route_providers.dart';
import 'login_screen.dart';
import 'police_route_details_screen.dart';
import 'police_route_map_screen.dart';

class PoliceDashboardScreen extends ConsumerStatefulWidget {
  const PoliceDashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PoliceDashboardScreen> createState() =>
      _PoliceDashboardScreenState();
}

class _PoliceDashboardScreenState extends ConsumerState<PoliceDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Updated to 3 tabs: Pending Routes, Active Routes, Route History
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final policeStats = ref.watch(policeRouteStatisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Police Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              ref.invalidate(policePendingRoutesProvider);
              ref.invalidate(policeActiveRoutesProvider);
              ref.invalidate(policeRouteHistoryProvider);
            },
            tooltip: 'Refresh Routes',
          ),
          IconButton(
            icon: const Icon(Icons.map, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PoliceRouteMapScreen(),
                ),
              );
            },
            tooltip: 'Map View',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.person, color: Colors.white),
            onSelected: (value) async {
              if (value == 'logout') {
                _showLogoutDialog(context, ref);
              } else if (value == 'settings') {
                _showComingSoon(context, 'Settings');
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
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
          isScrollable: true,
          tabs: const [
            Tab(text: 'Pending Routes', icon: Icon(Icons.pending_actions)),
            Tab(text: 'Active Routes', icon: Icon(Icons.route)),
            Tab(text: 'Route History', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Statistics Section
          _buildStatsSection(policeStats),

          // Search and Filter Section
          _buildSearchAndFilters(),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPendingRoutesTab(),
                _buildActiveRoutesTab(),
                _buildRouteHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(Map<String, int> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatCard(
              'Pending',
              stats['pending']?.toString() ?? '0',
              Colors.blue.shade600,
              Icons.pending_actions,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              'Active',
              stats['active']?.toString() ?? '0',
              Colors.green.shade600,
              Icons.check_circle,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              'Completed',
              stats['completed']?.toString() ?? '0',
              Colors.grey.shade600,
              Icons.flag,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              'Critical',
              stats['critical']?.toString() ?? '0',
              Colors.red.shade600,
              Icons.warning,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              'Timeout',
              stats['timeout']?.toString() ?? '0',
              Colors.orange.shade600,
              Icons.timer_off,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by ambulance, location, or priority...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _updateFilter();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (value) => _updateFilter(),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filter Routes',
                onSelected: (value) => _applyFilter(value),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'all', child: Text('All Routes')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                      value: 'critical', child: Text('Critical Priority')),
                  const PopupMenuItem(
                      value: 'high', child: Text('High Priority')),
                  const PopupMenuItem(
                      value: 'medium', child: Text('Medium Priority')),
                  const PopupMenuItem(
                      value: 'low', child: Text('Low Priority')),
                ],
              ),
              PopupMenuButton<RouteSortOption>(
                icon: const Icon(Icons.sort),
                tooltip: 'Sort Routes',
                onSelected: (option) => _applySorting(option),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: RouteSortOption.newest,
                    child: Text('Newest First'),
                  ),
                  const PopupMenuItem(
                    value: RouteSortOption.priority,
                    child: Text('By Priority'),
                  ),
                  const PopupMenuItem(
                    value: RouteSortOption.eta,
                    child: Text('By ETA'),
                  ),
                  const PopupMenuItem(
                    value: RouteSortOption.distance,
                    child: Text('By Distance'),
                  ),
                  const PopupMenuItem(
                    value: RouteSortOption.clearedDate,
                    child: Text('By Cleared Date'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRoutesTab() {
    final pendingRoutesAsync = ref.watch(policePendingRoutesProvider);

    return pendingRoutesAsync.when(
      data: (routes) {
        if (routes.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pending_actions, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No pending routes',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Routes needing traffic clearance will appear here',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: routes.length,
          itemBuilder: (context, index) {
            final route = routes[index];
            return _buildPendingRouteCard(route);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading pending routes: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(policePendingRoutesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRoutesTab() {
    final activeRoutesAsync = ref.watch(policeActiveRoutesProvider);

    return activeRoutesAsync.when(
      data: (routes) {
        if (routes.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.route, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No active routes',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Cleared routes will appear here',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: routes.length,
          itemBuilder: (context, index) {
            final route = routes[index];
            return _buildActiveRouteCard(route);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading active routes: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(policeActiveRoutesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteHistoryTab() {
    final routeHistoryAsync = ref.watch(policeRouteHistoryProvider);

    return routeHistoryAsync.when(
      data: (routes) {
        if (routes.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No route history',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Completed routes will appear here',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: routes.length,
          itemBuilder: (context, index) {
            final route = routes[index];
            return _buildHistoryRouteCard(route);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading route history: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(policeRouteHistoryProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRouteCard(AmbulanceRouteModel route) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.pending_actions, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ambulance ${route.ambulanceLicensePlate}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        route.getStatusDescription('police'),
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: route.isHighPriority
                        ? Colors.red.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    route.emergencyPriority.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: route.isHighPriority ? Colors.red : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Route details
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    route.patientLocation,
                    style: TextStyle(color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Stats
            Row(
              children: [
                _buildRouteStatChip(
                  icon: Icons.route,
                  label: route.formattedDistance,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildRouteStatChip(
                  icon: Icons.schedule,
                  label: route.formattedETA,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildRouteStatChip(
                  icon: Icons.access_time,
                  label: _formatTimeSince(route.createdAt),
                  color: Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _updateRouteStatus(route, RouteStatus.cleared),
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('Clear Traffic'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _updateRouteStatus(route, RouteStatus.timeout),
                    icon: const Icon(Icons.timer_off, size: 16),
                    label: const Text('Timeout'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // View details button
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _showRouteDetails(route),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRouteCard(AmbulanceRouteModel route) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ambulance ${route.ambulanceLicensePlate}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        route.getStatusDescription('police'),
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: route.isHighPriority
                        ? Colors.red.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    route.emergencyPriority.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: route.isHighPriority ? Colors.red : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Route details
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    route.patientLocation,
                    style: TextStyle(color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Stats
            Row(
              children: [
                _buildRouteStatChip(
                  icon: Icons.route,
                  label: route.formattedDistance,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildRouteStatChip(
                  icon: Icons.schedule,
                  label: route.formattedETA,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                if (route.clearedAt != null)
                  _buildRouteStatChip(
                    icon: Icons.check,
                    label: 'Cleared ${_formatTimeSince(route.clearedAt!)}',
                    color: Colors.green,
                  ),
              ],
            ),

            // Police clearance info
            if (route.policeOfficerName != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Cleared by: ${route.policeOfficerName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (route.clearedAt != null)
                      Text(
                        _formatDateTime(route.clearedAt!),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // View details button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showRouteDetails(route),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('View Details'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryRouteCard(AmbulanceRouteModel route) {
    final historyInfo = route.historyInfo;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.flag, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ambulance ${route.ambulanceLicensePlate}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Completed ${_formatDate(route.completedAt)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: route.isHighPriority
                        ? Colors.red.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    route.emergencyPriority.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: route.isHighPriority ? Colors.red : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Emergency details
            _buildHistoryDetailRow(
              'Emergency Location',
              route.patientLocation,
              Icons.location_on,
            ),

            _buildHistoryDetailRow(
              'Distance & Duration',
              '${route.formattedDistance} • ${route.formattedDuration}',
              Icons.route,
            ),

            if (historyInfo['completion']['duration'] != null)
              _buildHistoryDetailRow(
                'Total Time',
                '${historyInfo['completion']['duration']} minutes',
                Icons.timer,
              ),

            // Police clearance info
            if (historyInfo['police'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_police,
                            size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Traffic Cleared by Police',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Officer: ${historyInfo['police']['officerName']}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    if (historyInfo['police']['clearedAt'] != null)
                      Text(
                        'Cleared: ${_formatDate(historyInfo['police']['clearedAt'])}',
                        style: const TextStyle(fontSize: 11),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Action button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showRouteDetails(route),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('View Details'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _updateFilter() {
    final currentFilter = ref.read(routeFilterProvider);
    ref.read(routeFilterProvider.notifier).state = currentFilter.copyWith(
      searchQuery: _searchController.text,
    );
  }

  void _applyFilter(String filterType) {
    final currentFilter = ref.read(routeFilterProvider);

    String? priority;

    switch (filterType) {
      case 'critical':
        priority = 'critical';
        break;
      case 'high':
        priority = 'high';
        break;
      case 'medium':
        priority = 'medium';
        break;
      case 'low':
        priority = 'low';
        break;
      default:
        priority = null;
    }

    ref.read(routeFilterProvider.notifier).state = currentFilter.copyWith(
      priority: priority,
    );
  }

  void _applySorting(RouteSortOption sortOption) {
    final currentFilter = ref.read(routeFilterProvider);
    ref.read(routeFilterProvider.notifier).state = currentFilter.copyWith(
      sortBy: sortOption,
    );
  }

  void _showRouteDetails(AmbulanceRouteModel route) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PoliceRouteDetailsScreen(route: route),
      ),
    );
  }

  void _updateRouteStatus(
      AmbulanceRouteModel route, RouteStatus newStatus) async {
    final currentUserAsync = ref.read(currentUserProvider);

    await currentUserAsync.when(
      data: (user) async {
        if (user == null) return;

        final confirmed = await _showConfirmationDialog(route, newStatus);
        if (!confirmed) return;

        try {
          String? notes;
          if (newStatus == RouteStatus.timeout) {
            notes = 'Route marked as timeout by police officer';
          } else if (newStatus == RouteStatus.cleared) {
            notes = 'Traffic cleared by police officer';
          }

          await ref.read(routeStatusUpdateProvider.notifier).updateRouteStatus(
                routeId: route.id,
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

  Future<bool> _showConfirmationDialog(
      AmbulanceRouteModel route, RouteStatus newStatus) async {
    String title;
    String content;
    Color actionColor;

    switch (newStatus) {
      case RouteStatus.cleared:
        title = 'Clear Traffic';
        content =
            'Mark traffic as cleared for ambulance ${route.ambulanceLicensePlate}?';
        actionColor = Colors.green;
        break;
      case RouteStatus.timeout:
        title = 'Mark Timeout';
        content =
            'Mark route as timeout for ambulance ${route.ambulanceLicensePlate}?';
        actionColor = Colors.orange;
        break;
      default:
        title = 'Update Status';
        content = 'Update route status to ${newStatus.displayName}?';
        actionColor = Colors.blue;
    }

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: actionColor),
                child: Text(
                  newStatus == RouteStatus.cleared
                      ? 'Clear Traffic'
                      : 'Confirm',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature coming soon!')),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(authServiceProvider).signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  String _formatTimeSince(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
