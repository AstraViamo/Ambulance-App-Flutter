// lib/services/navigation_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../providers/permissions_providers.dart';
import '../screens/driver_dashboard_screen.dart';
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
          builder: (context) => const HospitalDashboard(),
          settings: RouteSettings(name: screenName, arguments: arguments),
        );

      case 'admin_dashboard':
        return MaterialPageRoute(
          builder: (context) => const HospitalAdminDashboard(),
          settings: RouteSettings(name: screenName, arguments: arguments),
        );

      case 'police_dashboard':
        return MaterialPageRoute(
          builder: (context) => const PoliceDashboardScreen(),
          settings: RouteSettings(name: screenName, arguments: arguments),
        );

      case 'driver_dashboard':
        return MaterialPageRoute(
          builder: (context) => const DriverDashboard(),
          settings: RouteSettings(name: screenName, arguments: arguments),
        );

      case 'emergency_list':
        return MaterialPageRoute(
          builder: (context) => const EmergencyListScreen(),
          settings: RouteSettings(name: screenName, arguments: arguments),
        );

      case 'emergency_details':
        final emergency = arguments?['emergency'];
        if (emergency != null) {
          return MaterialPageRoute(
            builder: (context) => EmergencyDetailsScreen(emergency: emergency),
            settings: RouteSettings(name: screenName, arguments: arguments),
          );
        }
        return null;

      case 'notifications':
        return MaterialPageRoute(
          builder: (context) => const NotificationsScreen(),
          settings: RouteSettings(name: screenName, arguments: arguments),
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

        // Emergencies (if has permission)
        if (ref.read(hasPermissionProvider(Permission.viewEmergencies))) {
          items.add(const BottomNavigationBarItem(
            icon: Icon(Icons.emergency),
            label: 'Emergencies',
          ));
        }

        // Routes (if has permission)
        if (ref.read(hasPermissionProvider(Permission.viewRoutes))) {
          items.add(const BottomNavigationBarItem(
            icon: Icon(Icons.route),
            label: 'Routes',
          ));
        }

        // Reports (if has permission)
        if (ref.read(hasPermissionProvider(Permission.viewReports))) {
          items.add(const BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Reports',
          ));
        }

        // Settings
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ));
        break;

      case UserRole.ambulanceDriver:
        // Dashboard
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ));

        // Emergencies (if has permission)
        if (ref
            .read(hasPermissionProvider(Permission.acceptEmergencyRequests))) {
          items.add(const BottomNavigationBarItem(
            icon: Icon(Icons.emergency),
            label: 'Emergencies',
          ));
        }

        // Navigation (if has permission)
        if (ref.read(hasPermissionProvider(Permission.accessNavigationTools))) {
          items.add(const BottomNavigationBarItem(
            icon: Icon(Icons.navigation),
            label: 'Navigation',
          ));
        }

        // Profile
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ));
        break;

      case UserRole.police:
        // Dashboard
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ));

        // Routes (if has permission)
        if (ref.read(hasPermissionProvider(Permission.viewRoutes))) {
          items.add(const BottomNavigationBarItem(
            icon: Icon(Icons.route),
            label: 'Routes',
          ));
        }

        // Traffic (if has permission)
        if (ref
            .read(hasPermissionProvider(Permission.manageTrafficIncidents))) {
          items.add(const BottomNavigationBarItem(
            icon: Icon(Icons.traffic),
            label: 'Traffic',
          ));
        }

        // Profile
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ));
        break;
    }

    return items;
  }

  // Handle bottom navigation tap with permission checks
  static void handleBottomNavigationTap(
    BuildContext context,
    WidgetRef ref,
    int index,
    UserRole role,
  ) {
    final items = getBottomNavigationItems(ref, role);
    if (index >= items.length) return;

    final item = items[index];
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
        // Handle driver navigation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigation feature coming soon')),
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
                      '${currentUser.firstName[0]}${currentUser.lastName[0]}'
                          .toUpperCase(),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            decoration: BoxDecoration(
              color: _getRoleColor(currentUser.role),
            ),
          ),
          ...availableMenuItems.map((item) => _buildDrawerItem(
                context,
                ref,
                item,
              )),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () async {
              Navigator.of(context).pop();
              await _signOut(context, ref);
            },
          ),
        ],
      ),
    );
  }

  static Widget _buildDrawerItem(
    BuildContext context,
    WidgetRef ref,
    MenuItem menuItem,
  ) {
    return ListTile(
      leading: Icon(menuItem.icon),
      title: Text(menuItem.title),
      onTap: () {
        Navigator.of(context).pop();
        if (menuItem.screenName != null) {
          navigateToScreen(context, ref, menuItem.screenName!);
        } else if (menuItem.onTap != null) {
          menuItem.onTap!();
        }
      },
    );
  }

  static Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.hospitalAdmin:
        return Colors.red.shade700;
      case UserRole.hospitalStaff:
        return Colors.red.shade600;
      case UserRole.ambulanceDriver:
        return Colors.green.shade600;
      case UserRole.police:
        return Colors.blue.shade800;
    }
  }

  static Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }
}

// Navigation item model
class NavigationItem {
  final String title;
  final IconData icon;
  final String? screenName;
  final VoidCallback? onTap;
  final List<Permission> requiredPermissions;

  NavigationItem({
    required this.title,
    required this.icon,
    this.screenName,
    this.onTap,
    this.requiredPermissions = const [],
  });

  factory NavigationItem.fromMenuItem(MenuItem menuItem) {
    return NavigationItem(
      title: menuItem.title,
      icon: menuItem.icon,
      screenName: menuItem.screenName,
      onTap: menuItem.onTap,
      requiredPermissions: menuItem.requiredPermissions,
    );
  }
}

// Menu item model (this should be added to your models)
class MenuItem {
  final String title;
  final IconData icon;
  final String? screenName;
  final VoidCallback? onTap;
  final List<Permission> requiredPermissions;

  MenuItem({
    required this.title,
    required this.icon,
    this.screenName,
    this.onTap,
    this.requiredPermissions = const [],
  });
}

// Provider for navigation state
final navigationIndexProvider = StateProvider<int>((ref) => 0);

// Navigation route observer for permission tracking
class PermissionRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  final WidgetRef ref;

  PermissionRouteObserver(this.ref);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logNavigation(route.settings.name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _logNavigation(newRoute?.settings.name);
  }

  void _logNavigation(String? routeName) {
    if (routeName != null) {
      debugPrint('Navigation to: $routeName');
      // Here you could log navigation events for analytics or audit purposes
    }
  }
}
