// lib/services/navigation_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../providers/permissions_providers.dart';
import '../screens/driver_dashboard_screen.dart';
import '../screens/driver_navigation_screen.dart';
import '../screens/emergency_details_screen.dart';
import '../screens/emergency_list_screen.dart';
import '../screens/notifications_screen.dart' as notifications;
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
          builder: (context) =>
              const HospitalAdminDashboard(), // Fixed: Use correct class name
        );
      case 'admin_dashboard':
        return MaterialPageRoute(
          builder: (context) => const HospitalAdminDashboard(),
        );
      case 'police_dashboard':
        return MaterialPageRoute(
          builder: (context) => const PoliceDashboardScreen(),
        );
      case 'driver_dashboard':
        return MaterialPageRoute(
          builder: (context) => const DriverDashboardScreen(),
        );
      case 'driver_navigation':
        // Fixed: DriverNavigationScreen requires a route parameter, not emergencyId
        if (arguments?['route'] != null) {
          return MaterialPageRoute(
            builder: (context) => DriverNavigationScreen(
              route: arguments!['route'], // Pass the AmbulanceRouteModel
            ),
          );
        } else {
          // If no route is provided, show error or redirect to dashboard
          return MaterialPageRoute(
            builder: (context) => const DriverDashboardScreen(),
          );
        }
      case 'emergency_list':
        return MaterialPageRoute(
          builder: (context) => const EmergencyListScreen(),
        );
      case 'emergency_details':
        return MaterialPageRoute(
          builder: (context) => EmergencyDetailsScreen(
            emergency: arguments?['emergency'],
          ),
        );
      case 'notifications':
        return MaterialPageRoute(
          builder: (context) => const notifications.NotificationsScreen(),
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
      case 'notifications':
        return 'Notifications';
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
        items.addAll([
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.emergency),
            label: 'Emergencies',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.route),
            label: 'Routes',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
        ]);
        break;
      case UserRole.police:
        items.addAll([
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.traffic),
            label: 'Traffic Control',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.route),
            label: 'Routes',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
        ]);
        break;
      case UserRole.ambulanceDriver:
        items.addAll([
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.navigation),
            label: 'Navigation',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'Status',
          ),
        ]);
        break;
      default:
        items.add(
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
        );
    }

    return items;
  }

  // Get dashboard widget for user role
  static Widget getDashboardForRole(UserRole role) {
    switch (role) {
      case UserRole.hospitalAdmin:
      case UserRole.hospitalStaff:
        return const HospitalDashboard();
      case UserRole.police:
        return const PoliceDashboardScreen();
      case UserRole.ambulanceDriver:
        return const DriverDashboardScreen();
      default:
        return const HospitalDashboard(); // Default fallback
    }
  }
}

// Navigation item model
class NavigationItem {
  final String title;
  final IconData icon;
  final String route;
  final bool isEnabled;

  NavigationItem({
    required this.title,
    required this.icon,
    required this.route,
    this.isEnabled = true,
  });

  factory NavigationItem.fromMenuItem(dynamic menuItem) {
    return NavigationItem(
      title: menuItem.title ?? 'Unknown',
      icon: _getIconFromString(menuItem.icon ?? 'dashboard'),
      route: menuItem.route ?? '/',
      isEnabled: menuItem.isEnabled ?? true,
    );
  }

  static IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'emergency':
        return Icons.emergency;
      case 'ambulance':
        return Icons.local_shipping;
      case 'map':
        return Icons.map;
      case 'reports':
        return Icons.analytics;
      case 'people':
        return Icons.people;
      case 'drive':
        return Icons.navigation;
      case 'traffic':
        return Icons.traffic;
      case 'settings':
        return Icons.settings;
      default:
        return Icons.dashboard;
    }
  }
}
