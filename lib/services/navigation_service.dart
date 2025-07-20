// lib/services/navigation_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../providers/permissions_providers.dart';
import '../screens/driver_dashboard_screen.dart';
import '../screens/driver_navigation_screen.dart';
import '../screens/emergency_details_screen.dart';
import '../screens/emergency_list_screen.dart';
import '../screens/hospital_dashboard.dart';
import '../screens/notifications_screen.dart';
import '../screens/police_dashboard_screen.dart';
import '../screens/role_dashboards.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Check if user can navigate to a specific screen
  static bool canNavigateToScreen(WidgetRef ref, String screenName) {
    final canAccessScreen = ref.read(canAccessScreenProvider(screenName));
    return canAccessScreen;
  }

  // Navigate with permission check
  static Future<void> navigateToScreen(
    BuildContext context,
    WidgetRef ref,
    String screenName, {
    Map<String, dynamic>? arguments,
  }) async {
    if (!canNavigateToScreen(ref, screenName)) {
      _showAccessDeniedDialog(context, screenName);
      return;
    }

    final route = _getRouteForScreen(screenName, arguments);
    if (route != null) {
      await Navigator.of(context).push(route);
    }
  }

  // Navigate and replace with permission check
  static Future<void> navigateAndReplaceToScreen(
    BuildContext context,
    WidgetRef ref,
    String screenName, {
    Map<String, dynamic>? arguments,
  }) async {
    if (!canNavigateToScreen(ref, screenName)) {
      _showAccessDeniedDialog(context, screenName);
      return;
    }

    final route = _getRouteForScreen(screenName, arguments);
    if (route != null) {
      await Navigator.of(context).pushReplacement(route);
    }
  }

  // Navigate and clear stack with permission check
  static Future<void> navigateAndClearStack(
    BuildContext context,
    WidgetRef ref,
    String screenName, {
    Map<String, dynamic>? arguments,
  }) async {
    if (!canNavigateToScreen(ref, screenName)) {
      _showAccessDeniedDialog(context, screenName);
      return;
    }

    final route = _getRouteForScreen(screenName, arguments);
    if (route != null) {
      await Navigator.of(context).pushAndRemoveUntil(
        route,
        (route) => false,
      );
    }
  }

  // Get route for screen name
  static MaterialPageRoute? _getRouteForScreen(
    String screenName,
    Map<String, dynamic>? arguments,
  ) {
    switch (screenName) {
      case 'hospital_dashboard':
        return MaterialPageRoute(
          builder: (context) => HospitalDashboard(
            hospitalId: arguments?['hospitalId'],
          ),
        );
      case 'driver_dashboard':
        return MaterialPageRoute(
          builder: (context) => const DriverDashboardScreen(),
        );
      case 'driver_navigation':
        return MaterialPageRoute(
          builder: (context) => DriverNavigationScreen(
            route: arguments!['route'],
          ),
        );
      case 'police_dashboard':
        return MaterialPageRoute(
          builder: (context) => const PoliceDashboardScreen(),
        );
      case 'emergency_list':
        return MaterialPageRoute(
          builder: (context) => const EmergencyListScreen(),
        );
      case 'emergency_details':
        return MaterialPageRoute(
          builder: (context) => EmergencyDetailsScreen(
            emergencyId: arguments!['emergencyId'],
          ),
        );
      case 'notifications':
        return MaterialPageRoute(
          builder: (context) => const NotificationsScreen(),
        );
      case 'role_dashboards':
        return MaterialPageRoute(
          builder: (context) => RoleDashboards(
            userRole: arguments!['userRole'],
          ),
        );
      default:
        return null;
    }
  }

  // Show access denied dialog
  static void _showAccessDeniedDialog(BuildContext context, String screenName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Access Denied'),
        content: Text(
          'You do not have permission to access ${_getScreenDisplayName(screenName)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Get display name for screen
  static String _getScreenDisplayName(String screenName) {
    switch (screenName) {
      case 'hospital_dashboard':
        return 'Hospital Dashboard';
      case 'admin_dashboard':
        return 'Admin Dashboard';
      case 'police_dashboard':
        return 'Police Dashboard';
      case 'driver_dashboard':
        return 'Driver Dashboard';
      case 'driver_navigation':
        return 'Driver Navigation';
      case 'emergency_list':
        return 'Emergency List';
      case 'emergency_details':
        return 'Emergency Details';
      default:
        return screenName.replaceAll('_', ' ').toUpperCase();
    }
  }

  // Get available navigation items based on user permissions
  static List<NavigationItem> getAvailableNavigationItems(WidgetRef ref) {
    final availableMenuItems = ref.watch(availableMenuItemsProvider);
    return availableMenuItems
        .map((item) => NavigationItem.fromMenuItem(item))
        .toList();
  }

  // Get bottom navigation items for role-based dashboards
  static List<BottomNavigationBarItem> getBottomNavigationItems(
    WidgetRef ref,
    UserRole role,
  ) {
    final List<BottomNavigationBarItem> items = [];

    switch (role) {
      case UserRole.hospitalAdmin:
      case UserRole.hospitalStaff:
        // Dashboard
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ));
        // Emergencies
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.emergency),
          label: 'Emergencies',
        ));
        // Routes
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.route),
          label: 'Routes',
        ));
        // Reports
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.analytics),
          label: 'Reports',
        ));
        break;

      case UserRole.ambulanceDriver:
        // Dashboard
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ));
        // Current Route
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.route),
          label: 'Route',
        ));
        // Navigation
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.navigation),
          label: 'Navigation',
        ));
        // History
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'History',
        ));
        break;

      case UserRole.police:
        // Dashboard
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ));
        // Traffic
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.traffic),
          label: 'Traffic',
        ));
        // Routes
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.route),
          label: 'Routes',
        ));
        // Reports
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.report),
          label: 'Reports',
        ));
        break;

      case UserRole.systemAdmin:
        // Admin Dashboard
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ));
        // Users
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Users',
        ));
        // System
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'System',
        ));
        // Analytics
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.analytics),
          label: 'Analytics',
        ));
        break;
    }

    return items;
  }

  // Handle navigation item selection
  static void handleNavigationItemSelected(
    BuildContext context,
    WidgetRef ref,
    NavigationItem item,
    UserRole role,
  ) {
    String? screenName;

    switch (item.label) {
      case 'Dashboard':
        switch (role) {
          case UserRole.hospitalAdmin:
          case UserRole.hospitalStaff:
            screenName = 'hospital_dashboard';
            break;
          case UserRole.ambulanceDriver:
            screenName = 'driver_dashboard';
            break;
          case UserRole.police:
            screenName = 'police_dashboard';
            break;
        }
        break;
      case 'Emergencies':
        screenName = 'emergency_list';
        break;
      case 'Routes':
        // For police, stay on dashboard but switch to routes tab
        if (role == UserRole.police) {
          // This would need to be handled by the dashboard's tab controller
          return;
        }
        break;
      case 'Reports':
        screenName = 'reports';
        break;
      case 'Settings':
        screenName = 'settings';
        break;
      case 'Navigation':
        // For ambulance drivers, this is now properly handled
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigation available in active route')),
        );
        return;
      case 'Traffic':
        // Handle police traffic management
        // This would typically switch tabs in the police dashboard
        return;
      case 'Profile':
        screenName = 'profile';
        break;
    }

    if (screenName != null) {
      navigateToScreen(context, ref, screenName);
    }
  }

  // Create drawer menu with permission-based items
  static Widget createPermissionBasedDrawer(
    BuildContext context,
    WidgetRef ref,
    UserModel currentUser,
  ) {
    final availableMenuItems = ref.watch(availableMenuItemsProvider);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName:
                Text('${currentUser.firstName} ${currentUser.lastName}'),
            accountEmail: Text(currentUser.email),
            currentAccountPicture: CircleAvatar(
              backgroundImage: currentUser.profileImageUrl != null
                  ? NetworkImage(currentUser.profileImageUrl!)
                  : null,
              child: currentUser.profileImageUrl == null
                  ? Text(
                      currentUser.firstName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 24),
                    )
                  : null,
            ),
            decoration: BoxDecoration(
              color: _getRoleColor(currentUser.role),
            ),
          ),
          ...availableMenuItems.map((item) => ListTile(
                leading: Icon(item.icon),
                title: Text(item.label),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  handleNavigationItemSelected(
                    context,
                    ref,
                    NavigationItem.fromMenuItem(item),
                    currentUser.role,
                  );
                },
              )),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _showSignOutDialog(context, ref);
            },
          ),
        ],
      ),
    );
  }

  // Get role-specific color
  static Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.hospitalAdmin:
      case UserRole.hospitalStaff:
        return Colors.blue.shade700;
      case UserRole.ambulanceDriver:
        return Colors.orange.shade700;
      case UserRole.police:
        return Colors.indigo.shade700;
      case UserRole.systemAdmin:
        return Colors.purple.shade700;
    }
  }

  // Show sign out confirmation dialog
  static void _showSignOutDialog(BuildContext context, WidgetRef ref) {
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
              // Handle sign out
              // await ref.read(authStateProvider.notifier).signOut();
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

// Navigation item model
class NavigationItem {
  final String label;
  final IconData icon;
  final String? route;

  NavigationItem({
    required this.label,
    required this.icon,
    this.route,
  });

  factory NavigationItem.fromMenuItem(dynamic menuItem) {
    return NavigationItem(
      label: menuItem.label,
      icon: menuItem.icon,
      route: menuItem.route,
    );
  }
}
