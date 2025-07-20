// lib/screens/hospital_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/route_model.dart';
import '../providers/auth_provider.dart';
import '../providers/emergency_providers.dart';
import '../providers/route_providers.dart';
import 'hospital_route_map_screen.dart';
import 'login_screen.dart';
import 'route_details_screen.dart';

class HospitalDashboardScreen extends ConsumerStatefulWidget {
  const HospitalDashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HospitalDashboardScreen> createState() =>
      _HospitalDashboardScreenState();
}

class _HospitalDashboardScreenState
    extends ConsumerState<HospitalDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String? hospitalId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadHospitalId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHospitalId() async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser != null && mounted) {
        setState(() {
          hospitalId = currentUser.roleSpecificData.hospitalId ?? 'default';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          hospitalId = 'default'; // Fallback
        });
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
          title: const Text(
            'Hospital Dashboard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red.shade700,
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

    final hospitalStats =
        ref.watch(hospitalRouteStatisticsProvider(hospitalId!));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hospital Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              // Fixed: Include all relevant providers in refresh
              ref.invalidate(hospitalRoutesProvider);
              ref.invalidate(hospitalActiveRoutesProvider);
              ref.invalidate(hospitalRouteHistoryProvider);
              ref.invalidate(emergencyStatsProvider);
              ref.invalidate(hospitalRouteStatisticsProvider);
            },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: _showNotifications,
            tooltip: 'Notifications',
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
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Active Routes', icon: Icon(Icons.route)),
            Tab(text: 'Route History', icon: Icon(Icons.history)),
            Tab(text: 'Route Map', icon: Icon(Icons.map)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Statistics Section
          _buildStatsSection(hospitalStats),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildActiveRoutesTab(),
                _buildRouteHistoryTab(),
                _buildRouteMapTab(),
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
        color: Colors.red.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatCard(
              'Total Routes',
              stats['total']?.toString() ?? '0',
              Colors.blue.shade600,
              Icons.route,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              'En Route',
              stats['enRoute']?.toString() ?? '0',
              Colors.orange.shade600,
              Icons.local_shipping,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              'Traffic Cleared',
              stats['cleared']?.toString() ?? '0',
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

  Widget _buildOverviewTab() {
    final emergencyStats = ref.watch(emergencyStatsProvider(hospitalId!));
    final activeRoutesAsync =
        ref.watch(hospitalActiveRoutesProvider(hospitalId!));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emergency Statistics Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.emergency, color: Colors.red.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        'Emergency Statistics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  emergencyStats.when(
                    data: (stats) => _buildEmergencyStatsGrid(stats),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) =>
                        Text('Error loading emergency stats: $error'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Recent Active Routes Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.route, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        'Recent Active Routes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  activeRoutesAsync.when(
                    data: (routes) {
                      final recentRoutes = routes.take(5).toList();
                      if (recentRoutes.isEmpty) {
                        return const Center(
                          child: Text(
                            'No active routes',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }
                      return Column(
                        children: recentRoutes
                            .map((route) => _buildRouteListItem(route))
                            .toList(),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) =>
                        Text('Error loading routes: $error'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyStatsGrid(Map<String, int> stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.5,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _buildMiniStatCard('Active', stats['active'] ?? 0, Colors.orange),
        _buildMiniStatCard('Pending', stats['pending'] ?? 0, Colors.blue),
        _buildMiniStatCard('Critical', stats['critical'] ?? 0, Colors.red),
        _buildMiniStatCard(
            'Completed Today', stats['completedToday'] ?? 0, Colors.green),
      ],
    );
  }

  Widget _buildMiniStatCard(String title, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRouteListItem(AmbulanceRouteModel route) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_shipping,
            color: route.isHighPriority ? Colors.red : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route.ambulanceLicensePlate,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  route.patientLocation,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: route.isHighPriority ? Colors.red : Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  route.emergencyPriority.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ETA: ${route.formattedETA}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: route.isHighPriority ? Colors.red : Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRoutesTab() {
    final activeRoutesAsync =
        ref.watch(hospitalActiveRoutesProvider(hospitalId!));

    return Column(
      children: [
        // Search and Filter Section
        _buildSearchAndFilters(),

        // Routes List
        Expanded(
          child: activeRoutesAsync.when(
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
                        'Active ambulance routes will appear here',
                        style: TextStyle(color: Colors.grey),
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
                  return _buildRouteCard(route, showActions: false);
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
                  Text('Error loading routes: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        ref.invalidate(hospitalActiveRoutesProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteHistoryTab() {
    final routeHistoryAsync =
        ref.watch(hospitalRouteHistoryProvider(hospitalId!));

    return Column(
      children: [
        // Search and Filter Section
        _buildHistorySearchAndFilters(),

        // History List
        Expanded(
          child: routeHistoryAsync.when(
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
                  return _buildRouteCard(route, showActions: true);
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
                    onPressed: () =>
                        ref.invalidate(hospitalRouteHistoryProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteCard(AmbulanceRouteModel route,
      {required bool showActions}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showRouteDetails(route),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Status indicator
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(route.status.colorValue),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Route info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              route.ambulanceLicensePlate,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: route.isHighPriority
                                    ? Colors.red
                                    : Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                route.emergencyPriority.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          route.patientLocation,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              route.formattedDistance,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              route.formattedDuration,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Status and ETA
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        route.status.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(route.status.colorValue),
                        ),
                      ),
                      if (route.status != RouteStatus.completed) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: route.isHighPriority
                                ? Colors.red
                                : Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ETA: ${route.formattedETA}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (showActions) ...[
                const SizedBox(height: 12),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showRouteDetails(route),
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text('Details'),
                    ),
                    TextButton.icon(
                      onPressed: () => _exportRouteReport(route),
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Export'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
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
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search routes...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Routes', true),
                const SizedBox(width: 8),
                _buildFilterChip('Critical Priority', false),
                const SizedBox(width: 8),
                _buildFilterChip('Traffic Cleared', false),
                const SizedBox(width: 8),
                _buildFilterChip('En Route', false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search route history...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Time', true),
                const SizedBox(width: 8),
                _buildFilterChip('Today', false),
                const SizedBox(width: 8),
                _buildFilterChip('This Week', false),
                const SizedBox(width: 8),
                _buildFilterChip('This Month', false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        // TODO: Implement filter functionality
      },
      selectedColor: Colors.red.shade100,
      checkmarkColor: Colors.red.shade700,
    );
  }

  Widget _buildRouteMapTab() {
    return HospitalRouteMapScreen(hospitalId: hospitalId!);
  }

  void _showRouteDetails(AmbulanceRouteModel route) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteDetailsScreen(route: route),
      ),
    );
  }

  void _exportRouteReport(AmbulanceRouteModel route) {
    _showComingSoon(context, 'Route Export');
  }

  void _showNotifications() {
    _showComingSoon(context, 'Notifications');
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog first
              try {
                // Use the correct authServiceProvider
                final authService = ref.read(authServiceProvider);
                await authService.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error signing out: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
