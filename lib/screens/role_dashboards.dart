// lib/screens/updated_role_dashboards.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import 'ambulance_list_screen.dart';
import 'driver_dashboard_screen.dart';
import 'hospital_map_screen.dart';
import 'login_screen.dart';

// Hospital Admin Dashboard with Map Integration
class HospitalAdminDashboard extends ConsumerWidget {
  const HospitalAdminDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _buildDashboard(
      context: context,
      ref: ref,
      role: UserRole.hospitalAdmin,
      title: 'Hospital Admin Dashboard',
      color: Colors.blue.shade700,
      features: [
        DashboardFeature(
          icon: Icons.map,
          title: 'Live Ambulance Map',
          subtitle: 'Real-time ambulance tracking',
          onTap: (context, ref) => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HospitalMapScreen()),
          ),
        ),
        DashboardFeature(
          icon: Icons.local_shipping,
          title: 'Manage Ambulances',
          subtitle: 'Add, edit, and monitor ambulances',
          onTap: (context, ref) => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const AmbulanceListScreen()),
          ),
        ),
        DashboardFeature(
          icon: Icons.people,
          title: 'Manage Staff',
          subtitle: 'Handle hospital staff and drivers',
          onTap: (context, ref) => _showComingSoon(context, 'Staff Management'),
        ),
        DashboardFeature(
          icon: Icons.analytics,
          title: 'View Reports',
          subtitle: 'Access performance analytics',
          onTap: (context, ref) =>
              _showComingSoon(context, 'Reports & Analytics'),
        ),
        DashboardFeature(
          icon: Icons.emergency,
          title: 'Emergency Dispatch',
          subtitle: 'Coordinate emergency responses',
          onTap: (context, ref) =>
              _showComingSoon(context, 'Emergency Dispatch'),
        ),
        DashboardFeature(
          icon: Icons.settings,
          title: 'System Settings',
          subtitle: 'Configure hospital settings',
          onTap: (context, ref) => _showComingSoon(context, 'System Settings'),
        ),
      ],
    );
  }
}

// Hospital Staff Dashboard with Map Integration
class HospitalStaffDashboard extends ConsumerWidget {
  const HospitalStaffDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _buildDashboard(
      context: context,
      ref: ref,
      role: UserRole.hospitalStaff,
      title: 'Hospital Staff Dashboard',
      color: Colors.green.shade700,
      features: [
        DashboardFeature(
          icon: Icons.map,
          title: 'Live Ambulance Map',
          subtitle: 'Track ambulances in real-time',
          onTap: (context, ref) => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HospitalMapScreen()),
          ),
        ),
        DashboardFeature(
          icon: Icons.assignment,
          title: 'Assign Ambulances',
          subtitle: 'Allocate ambulances to emergencies',
          onTap: (context, ref) =>
              _showComingSoon(context, 'Emergency Assignment'),
        ),
        DashboardFeature(
          icon: Icons.local_shipping,
          title: 'View Ambulances',
          subtitle: 'Monitor ambulance fleet',
          onTap: (context, ref) => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const AmbulanceListScreen()),
          ),
        ),
        DashboardFeature(
          icon: Icons.history,
          title: 'Recent Assignments',
          subtitle: 'View assignment history',
          onTap: (context, ref) =>
              _showComingSoon(context, 'Assignment History'),
        ),
        DashboardFeature(
          icon: Icons.notification_important,
          title: 'Emergency Alerts',
          subtitle: 'Manage incoming emergencies',
          onTap: (context, ref) => _showComingSoon(context, 'Emergency Alerts'),
        ),
        DashboardFeature(
          icon: Icons.route,
          title: 'Route Optimization',
          subtitle: 'Optimize ambulance routes',
          onTap: (context, ref) =>
              _showComingSoon(context, 'Route Optimization'),
        ),
      ],
    );
  }
}

// Enhanced Ambulance Driver Dashboard
class AmbulanceDriverDashboard extends ConsumerWidget {
  const AmbulanceDriverDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DriverDashboardScreen();
  }
}

// Police Dashboard with Map Integration
class PoliceDashboard extends ConsumerWidget {
  const PoliceDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _buildDashboard(
      context: context,
      ref: ref,
      role: UserRole.police,
      title: 'Police Dashboard',
      color: Colors.indigo.shade700,
      features: [
        DashboardFeature(
          icon: Icons.map,
          title: 'Ambulance Locations',
          subtitle: 'View all ambulance positions',
          onTap: (context, ref) => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HospitalMapScreen()),
          ),
        ),
        DashboardFeature(
          icon: Icons.route,
          title: 'Active Routes',
          subtitle: 'Monitor ambulance routes',
          onTap: (context, ref) => _showComingSoon(context, 'Active Routes'),
        ),
        DashboardFeature(
          icon: Icons.traffic,
          title: 'Clear Traffic',
          subtitle: 'Manage traffic clearance',
          onTap: (context, ref) =>
              _showComingSoon(context, 'Traffic Management'),
        ),
        DashboardFeature(
          icon: Icons.timer,
          title: 'Route ETAs',
          subtitle: 'Estimated arrival times',
          onTap: (context, ref) => _showComingSoon(context, 'ETA Monitoring'),
        ),
        DashboardFeature(
          icon: Icons.emergency,
          title: 'Emergency Coordination',
          subtitle: 'Coordinate with hospitals',
          onTap: (context, ref) =>
              _showComingSoon(context, 'Emergency Coordination'),
        ),
        DashboardFeature(
          icon: Icons.chat,
          title: 'Communication Hub',
          subtitle: 'Direct communication channels',
          onTap: (context, ref) =>
              _showComingSoon(context, 'Communication Hub'),
        ),
      ],
    );
  }
}

// Common dashboard builder
Widget _buildDashboard({
  required BuildContext context,
  required WidgetRef ref,
  required UserRole role,
  required String title,
  required Color color,
  required List<DashboardFeature> features,
}) {
  return Scaffold(
    appBar: AppBar(
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: color,
      elevation: 0,
      actions: [
        // Quick access to map for hospital users
        if (role == UserRole.hospitalAdmin ||
            role == UserRole.hospitalStaff) ...[
          IconButton(
            icon: const Icon(Icons.map, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const HospitalMapScreen()),
            ),
            tooltip: 'Live Map',
          ),
        ],
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
    ),
    body: Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.1),
                  color.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Icon(
                        _getRoleIcon(role),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back!',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            _getRoleTitle(role),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        color: Colors.green.shade700,
                        size: 12,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Online',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          // Feature grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.3,
              ),
              itemCount: features.length,
              itemBuilder: (context, index) {
                final feature = features[index];
                return _buildFeatureCard(
                  context: context,
                  ref: ref,
                  feature: feature,
                  color: color,
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildFeatureCard({
  required BuildContext context,
  required WidgetRef ref,
  required DashboardFeature feature,
  required Color color,
}) {
  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    child: InkWell(
      onTap: () {
        if (feature.onTap != null) {
          feature.onTap!(context, ref);
        } else {
          _showComingSoon(context, feature.title);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(22.5),
              ),
              child: Icon(
                feature.icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              feature.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Flexible(
              child: Text(
                feature.subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

IconData _getRoleIcon(UserRole role) {
  switch (role) {
    case UserRole.hospitalAdmin:
      return Icons.admin_panel_settings;
    case UserRole.hospitalStaff:
      return Icons.medical_services;
    case UserRole.ambulanceDriver:
      return Icons.local_shipping;
    case UserRole.police:
      return Icons.local_police;
  }
}

String _getRoleTitle(UserRole role) {
  switch (role) {
    case UserRole.hospitalAdmin:
      return 'Hospital Administrator';
    case UserRole.hospitalStaff:
      return 'Hospital Staff Member';
    case UserRole.ambulanceDriver:
      return 'Ambulance Driver';
    case UserRole.police:
      return 'Police Officer';
  }
}

void _showComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$feature coming soon'),
      backgroundColor: Colors.blue.shade700,
      action: SnackBarAction(
        label: 'OK',
        textColor: Colors.white,
        onPressed: () {},
      ),
    ),
  );
}

// Dashboard feature model
class DashboardFeature {
  final IconData icon;
  final String title;
  final String subtitle;
  final void Function(BuildContext context, WidgetRef ref)? onTap;

  DashboardFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
}

// Logout dialog function
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
                        builder: (context) => const LoginScreen()),
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
