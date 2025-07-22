// lib/screens/role_dashboards.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import 'driver_dashboard_screen.dart';
import 'hospital_dashboard.dart' as hospital_dashboard;
import 'login_screen.dart';
import 'police_dashboard_screen.dart';

// Hospital Admin Dashboard with Enhanced Features
class HospitalAdminDashboard extends ConsumerWidget {
  const HospitalAdminDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const hospital_dashboard.HospitalDashboard();
  }
}

// Alias for backward compatibility
class HospitalDashboard extends ConsumerWidget {
  final String? hospitalId;

  const HospitalDashboard({Key? key, this.hospitalId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const hospital_dashboard
        .HospitalDashboard(); // Fixed: Use correct class name
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
                  'Manage your ${role.name.toLowerCase()} responsibilities efficiently',
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
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: features.length,
            itemBuilder: (context, index) {
              final feature = features[index];
              return _buildFeatureCard(feature, color);
            },
          ),
        ],
      ),
    ),
  );
}

Widget _buildFeatureCard(DashboardFeature feature, Color themeColor) {
  return Card(
    elevation: 2,
    child: InkWell(
      onTap: feature.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              feature.icon,
              size: 48,
              color: themeColor,
            ),
            const SizedBox(height: 12),
            Text(
              feature.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              feature.description,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
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
            final authService = ref.read(authServiceProvider);
            await authService.signOut();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

// Dashboard feature model
class DashboardFeature {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  DashboardFeature({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });
}
