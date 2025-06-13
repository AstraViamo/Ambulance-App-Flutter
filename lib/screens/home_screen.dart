// lib/screens/home_screen.dart
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import 'role_dashboards.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Select Your Role',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header section
            const SizedBox(height: 20),

            Icon(
              Icons.local_hospital,
              size: 60,
              color: Colors.red.shade700,
            ),

            const SizedBox(height: 16),

            Text(
              'Choose your role to continue',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 40),

            // Role selection cards
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio:
                    0.95, // Increased from 0.85 to give more height
                children: [
                  _buildRoleCard(
                    context: context,
                    role: UserRole.hospitalAdmin,
                    title: 'Hospital Admin',
                    subtitle: 'Manage hospital operations',
                    icon: Icons.admin_panel_settings,
                    color: Colors.blue.shade700,
                  ),
                  _buildRoleCard(
                    context: context,
                    role: UserRole.hospitalStaff,
                    title: 'Hospital Staff',
                    subtitle: 'Coordinate ambulances',
                    icon: Icons.medical_services,
                    color: Colors.green.shade700,
                  ),
                  _buildRoleCard(
                    context: context,
                    role: UserRole.ambulanceDriver,
                    title: 'Ambulance Driver',
                    subtitle: 'Respond to emergency calls',
                    icon: Icons.local_shipping,
                    color: Colors.orange.shade700,
                  ),
                  _buildRoleCard(
                    context: context,
                    role: UserRole.police,
                    title: 'Police Officer',
                    subtitle: 'Clear traffic routes',
                    icon: Icons.local_police,
                    color: Colors.indigo.shade700,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Firebase Connected',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required UserRole role,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _onRoleSelected(context, role),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16), // Reduced from 20 to 16
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 32,
                ),
              ),

              const SizedBox(height: 12), // Reduced from 16

              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15, // Reduced from 16
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6), // Reduced from 8

              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onRoleSelected(BuildContext context, UserRole role) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                _getRoleIcon(role),
                color: _getRoleColor(role),
              ),
              const SizedBox(width: 12),
              Text(_getRoleTitle(role)),
            ],
          ),
          content: Text(
            'You selected ${_getRoleTitle(role)}. This will determine your app experience and available features.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToRole(context, role);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _getRoleColor(role),
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToRole(BuildContext context, UserRole role) {
    Widget destination;

    switch (role) {
      case UserRole.hospitalAdmin:
        destination = const HospitalAdminDashboard();
        break;
      case UserRole.hospitalStaff:
        destination = const HospitalStaffDashboard();
        break;
      case UserRole.ambulanceDriver:
        destination = const AmbulanceDriverDashboard();
        break;
      case UserRole.police:
        destination = const PoliceDashboard();
        break;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => destination),
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
        return 'Hospital Admin';
      case UserRole.hospitalStaff:
        return 'Hospital Staff';
      case UserRole.ambulanceDriver:
        return 'Ambulance Driver';
      case UserRole.police:
        return 'Police Officer';
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.hospitalAdmin:
        return Colors.blue.shade700;
      case UserRole.hospitalStaff:
        return Colors.green.shade700;
      case UserRole.ambulanceDriver:
        return Colors.orange.shade700;
      case UserRole.police:
        return Colors.indigo.shade700;
    }
  }
}
