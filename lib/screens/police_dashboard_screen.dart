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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routeStats = ref.watch(routeStatisticsProvider);
    final currentUser = ref.watch(currentUserProvider);

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
              ref.invalidate(allActiveRoutesProvider);
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
          tabs: const [
            Tab(text: 'Active Routes', icon: Icon(Icons.route)),
            Tab(text: 'Route History', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Statistics Section
          _buildStatsSection(routeStats),

          // Search and Filter Section
          _buildSearchAndFilters(),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
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
      child: Row(
        children: [
          _buildStatCard(
            'Total',
            stats['total']?.toString() ?? '0',
            Colors.indigo.shade700,
            Icons.route,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Active',
            stats['active']?.toString() ?? '0',
            Colors.blue.shade700,
            Icons.directions_car,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Cleared',
            stats['cleared']?.toString() ?? '0',
            Colors.green.shade700,
            Icons.check_circle,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Critical',
            stats['critical']?.toString() ?? '0',
            Colors.red.shade700,
            Icons.priority_high,
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

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
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
                ),
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
              const PopupMenuItem(value: 'active', child: Text('Active Only')),
              const PopupMenuItem(
                  value: 'cleared', child: Text('Cleared Only')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'critical', child: Text('Critical Priority')),
              const PopupMenuItem(value: 'high', child: Text('High Priority')),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRoutesTab() {
    final filter = ref.watch(routeFilterProvider);
    final filteredRoutes = ref.watch(filteredRoutesProvider(filter));

    if (filteredRoutes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No active routes found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Active ambulance routes will appear here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredRoutes.length,
      itemBuilder: (context, index) {
        final route = filteredRoutes[index];
        return _buildRouteCard(route);
      },
    );
  }

  Widget _buildRouteHistoryTab() {
    // For now, showing same routes but could be enhanced to show completed/timeout routes
    final filter = ref.watch(routeFilterProvider);
    final filteredRoutes = ref.watch(filteredRoutesProvider(filter));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredRoutes.length,
      itemBuilder: (context, index) {
        final route = filteredRoutes[index];
        return _buildRouteCard(route, showHistory: true);
      },
    );
  }

  Widget _buildRouteCard(AmbulanceRouteModel route,
      {bool showHistory = false}) {
    final priorityColor = route.emergencyPriority == 'critical'
        ? Colors.red
        : route.emergencyPriority == 'high'
            ? Colors.orange
            : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showRouteDetails(route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: priorityColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      route.emergencyPriority.toUpperCase(),
                      style: TextStyle(
                        color: priorityColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ambulance ${route.ambulanceLicensePlate}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(route.status.colorValue).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(route.status.colorValue).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      route.status.displayName,
                      style: TextStyle(
                        color: Color(route.status.colorValue),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Route info
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      route.patientLocation,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Stats
              Row(
                children: [
                  _buildRouteStatChip(
                    icon: Icons.straighten,
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
                    label: route.formattedDuration,
                    color: Colors.purple,
                  ),
                ],
              ),

              // Action buttons
              if (!showHistory && route.status == RouteStatus.active) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _updateRouteStatus(route, RouteStatus.cleared),
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text('Mark Cleared'),
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
              ],

              // Police officer info (if status was updated)
              if (route.policeOfficerName != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Updated by: ${route.policeOfficerName}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      if (route.statusUpdatedAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '• ${_formatDateTime(route.statusUpdatedAt!)}',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
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

    RouteStatus? status;
    String? priority;

    switch (filterType) {
      case 'active':
        status = RouteStatus.active;
        break;
      case 'cleared':
        status = RouteStatus.cleared;
        break;
      case 'critical':
        priority = 'critical';
        break;
      case 'high':
        priority = 'high';
        break;
      default:
        status = null;
        priority = null;
    }

    ref.read(routeFilterProvider.notifier).state = currentFilter.copyWith(
      status: status,
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
          await ref.read(routeStatusUpdateProvider.notifier).updateRouteStatus(
                routeId: route.id,
                newStatus: newStatus,
                policeOfficerId: user.id,
                policeOfficerName: user.fullName,
                notes: newStatus == RouteStatus.timeout
                    ? 'Marked as timeout by police'
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

  Future<bool> _showConfirmationDialog(
      AmbulanceRouteModel route, RouteStatus newStatus) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Update Route Status'),
            content: Text(
              'Are you sure you want to mark this route as ${newStatus.displayName}?\n\n'
              'Ambulance: ${route.ambulanceLicensePlate}\n'
              'Destination: ${route.patientLocation}',
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

  String _formatDateTime(DateTime dateTime) {
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

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text('Sign Out'),
            ],
          ),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  final authService = ref.read(authServiceProvider);
                  await authService.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error signing out: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  void _showComingSoon(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName feature coming soon!'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
