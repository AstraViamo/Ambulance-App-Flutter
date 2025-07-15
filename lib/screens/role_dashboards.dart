// lib/screens/updated_role_dashboards.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import 'driver_dashboard_screen.dart';
import 'hospital_dashboard.dart';
import 'login_screen.dart';
import 'police_dashboard_screen.dart';

// Hospital Admin Dashboard with Enhanced Features
class HospitalAdminDashboard extends ConsumerWidget {
  const HospitalAdminDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const HospitalDashboard();
  }
}

// Driver Dashboard (unchanged)
class DriverDashboard extends ConsumerWidget {
  const DriverDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DriverDashboardScreen();
  }
}

// Enhanced Police Dashboard with Route Management
class PoliceDashboard extends ConsumerWidget {
  const PoliceDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const PoliceDashboardScreen();
  }
}

// Common dashboard builder (for other roles if needed)
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
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () => _showLogoutDialog(context, ref),
          tooltip: 'Logout',
        ),
      ],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to $title',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Access your ${_getRoleDisplayName(role).toLowerCase()} tools and manage operations',
                  style: TextStyle(
                    fontSize: 16,
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Features grid
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
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
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => feature.onTap(context, ref),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                feature.icon,
                size: 32,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              feature.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              feature.subtitle,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}

void _showLogoutDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
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

class DashboardFeature {
  final IconData icon;
  final String title;
  final String subtitle;
  final Function(BuildContext context, WidgetRef ref) onTap;

  DashboardFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

// Helper function to get role display name
String _getRoleDisplayName(UserRole role) {
  switch (role) {
    case UserRole.hospitalAdmin:
      return 'Hospital Admin';
    case UserRole.hospitalStaff:
      return 'Hospital Staff';
    case UserRole.ambulanceDriver:
      return 'Ambulance Driver';
    case UserRole.police:
      return 'Police Officer';
  }
}
