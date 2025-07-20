// lib/screens/hospital_dashboard_with_bottom_nav.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/route_model.dart';
import '../providers/auth_provider.dart';
import '../providers/emergency_providers.dart';
import '../providers/route_providers.dart';
import '../services/navigation_service.dart';
import 'ambulance_list_screen.dart';
import 'emergency_list_screen.dart';
import 'hospital_route_map_screen.dart';
import 'login_screen.dart';
import 'route_details_screen.dart';

class HospitalDashboard extends ConsumerStatefulWidget {
  const HospitalDashboard({Key? key}) : super(key: key);

  @override
  ConsumerState<HospitalDashboard> createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends ConsumerState<HospitalDashboard> {
  int _currentBottomIndex = 0;
  String? hospitalId;

  @override
  void initState() {
    super.initState();
    _loadHospitalId();
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

    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      data: (user) {
        if (user == null) return const LoginScreen();

        // Get bottom navigation items for hospital users
        final bottomNavItems =
            NavigationService.getBottomNavigationItems(ref, user.role);

        return Scaffold(
          appBar: _buildAppBar(),
          body: _buildCurrentPage(),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentBottomIndex,
            onTap: _onBottomNavTap,
            selectedItemColor: Colors.red.shade700,
            unselectedItemColor: Colors.grey.shade600,
            backgroundColor: Colors.white,
            elevation: 8,
            items: bottomNavItems,
          ),
        );
      },
      loading: () => _buildLoadingScreen(),
      error: (error, stack) => _buildErrorScreen(error),
    );
  }

  AppBar _buildAppBar() {
    String title;
    Color backgroundColor;

    switch (_currentBottomIndex) {
      case 0:
        title = 'Hospital Dashboard';
        backgroundColor = Colors.red.shade700;
        break;
      case 1:
        title = 'Emergency Management';
        backgroundColor = Colors.orange.shade700;
        break;
      case 2:
        title = 'Route Management';
        backgroundColor = Colors.blue.shade700;
        break;
      case 3:
        title = 'Live Map';
        backgroundColor = Colors.green.shade700;
        break;
      default:
        title = 'Hospital Dashboard';
        backgroundColor = Colors.red.shade700;
    }

    return AppBar(
      title: Text(
        title,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: backgroundColor,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _refreshCurrentPage,
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
              _showLogoutDialog();
            } else if (value == 'settings') {
              _showComingSoon('Settings');
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
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentBottomIndex) {
      case 0:
        return _buildDashboardOverview();
      case 1:
        return EmergencyListScreen();
      case 2:
        return _buildRouteManagement();
      case 3:
        return HospitalRouteMapScreen(hospitalId: hospitalId!);
      default:
        return _buildDashboardOverview();
    }
  }

  Widget _buildDashboardOverview() {
    final hospitalStats =
        ref.watch(hospitalRouteStatisticsProvider(hospitalId!));
    final emergencyStats = ref.watch(emergencyStatsProvider(hospitalId!));
    final activeRoutesAsync =
        ref.watch(hospitalActiveRoutesProvider(hospitalId!));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.local_hospital,
                      size: 40, color: Colors.red.shade700),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome to Hospital Dashboard',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Monitor and manage emergency services',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Emergency Statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.emergency, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Emergency Statistics',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  emergencyStats.when(
                    data: (stats) => _buildEmergencyStatsGrid(stats),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Text('Error: $error'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Route Statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.route, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Route Statistics',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildRouteStatsGrid(hospitalStats),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Active Routes Preview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_shipping,
                              color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'Active Routes',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _currentBottomIndex = 2),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  activeRoutesAsync.when(
                    data: (routes) {
                      if (routes.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No active routes at the moment'),
                          ),
                        );
                      }
                      // Show only first 3 routes in preview
                      final previewRoutes = routes.take(3).toList();
                      return Column(
                        children: previewRoutes
                            .map((route) => _buildRoutePreviewCard(route))
                            .toList(),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Text('Error: $error'),
                  ),
                ],
              ),
            ),
          ),

          // Quick Actions
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionButton(
                          'View Emergencies',
                          Icons.emergency,
                          Colors.orange.shade700,
                          () => setState(() => _currentBottomIndex = 1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickActionButton(
                          'Manage Routes',
                          Icons.route,
                          Colors.blue.shade700,
                          () => setState(() => _currentBottomIndex = 2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionButton(
                          'Live Map',
                          Icons.map,
                          Colors.green.shade700,
                          () => setState(() => _currentBottomIndex = 3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickActionButton(
                          'Ambulances',
                          Icons.local_shipping,
                          Colors.purple.shade700,
                          () => _navigateToAmbulanceList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteManagement() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.blue.shade50,
            child: const TabBar(
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              tabs: [
                Tab(text: 'Active Routes', icon: Icon(Icons.route)),
                Tab(text: 'Route History', icon: Icon(Icons.history)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
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

  Widget _buildActiveRoutesTab() {
    final activeRoutesAsync =
        ref.watch(hospitalActiveRoutesProvider(hospitalId!));

    return activeRoutesAsync.when(
      data: (routes) {
        if (routes.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.route, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No active routes', style: TextStyle(fontSize: 18)),
                SizedBox(height: 8),
                Text('Active ambulance routes will appear here'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: routes.length,
          itemBuilder: (context, index) {
            final route = routes[index];
            return _buildRouteCard(route);
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
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(hospitalActiveRoutesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteHistoryTab() {
    final routeHistoryAsync =
        ref.watch(hospitalRouteHistoryProvider(hospitalId!));

    return routeHistoryAsync.when(
      data: (routes) {
        if (routes.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No route history', style: TextStyle(fontSize: 18)),
                SizedBox(height: 8),
                Text('Completed routes will appear here'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: routes.length,
          itemBuilder: (context, index) {
            final route = routes[index];
            return _buildRouteCard(route);
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
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(hospitalRouteHistoryProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Methods

  Widget _buildEmergencyStatsGrid(Map<String, int> stats) {
    return Row(
      children: [
        _buildStatCard('Total', stats['total'] ?? 0, Colors.blue),
        const SizedBox(width: 8),
        _buildStatCard('Active', stats['active'] ?? 0, Colors.orange),
        const SizedBox(width: 8),
        _buildStatCard('Critical', stats['critical'] ?? 0, Colors.red),
        const SizedBox(width: 8),
        _buildStatCard('Completed', stats['completed'] ?? 0, Colors.green),
      ],
    );
  }

  Widget _buildRouteStatsGrid(Map<String, int> stats) {
    return Row(
      children: [
        _buildStatCard('Total', stats['total'] ?? 0, Colors.blue),
        const SizedBox(width: 8),
        _buildStatCard('En Route', stats['enRoute'] ?? 0, Colors.orange),
        const SizedBox(width: 8),
        _buildStatCard('Cleared', stats['cleared'] ?? 0, Colors.green),
        const SizedBox(width: 8),
        _buildStatCard('Pending', stats['pending'] ?? 0, Colors.amber),
      ],
    );
  }

  Widget _buildStatCard(String title, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutePreviewCard(AmbulanceRouteModel route) {
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: route.isHighPriority ? Colors.red : Colors.orange,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              route.isHighPriority ? 'HIGH' : 'NORMAL',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(AmbulanceRouteModel route) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.local_shipping,
          color: route.isHighPriority ? Colors.red : Colors.orange,
        ),
        title: Text(route.ambulanceLicensePlate),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(route.patientLocation),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: route.isHighPriority ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    route.isHighPriority ? 'HIGH PRIORITY' : 'NORMAL',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  route.status.displayName,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _navigateToRouteDetails(route),
      ),
    );
  }

  Widget _buildQuickActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorScreen(Object error) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(currentUserProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // Navigation and Action Methods

  void _onBottomNavTap(int index) {
    setState(() {
      _currentBottomIndex = index;
    });
  }

  void _refreshCurrentPage() {
    switch (_currentBottomIndex) {
      case 0:
        ref.invalidate(hospitalRouteStatisticsProvider);
        ref.invalidate(emergencyStatsProvider);
        ref.invalidate(hospitalActiveRoutesProvider);
        break;
      case 1:
        ref.invalidate(emergenciesProvider);
        break;
      case 2:
        ref.invalidate(hospitalActiveRoutesProvider);
        ref.invalidate(hospitalRouteHistoryProvider);
        break;
      case 3:
        // Refresh map data if needed
        break;
    }
  }

  void _showNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notifications feature coming soon!')),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature feature coming soon!')),
    );
  }

  void _showLogoutDialog() {
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
              Navigator.of(context).pop();
              try {
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

  void _navigateToRouteDetails(AmbulanceRouteModel route) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteDetailsScreen(route: route),
      ),
    );
  }

  void _navigateToAmbulanceList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AmbulanceListScreen(),
      ),
    );
  }
}
