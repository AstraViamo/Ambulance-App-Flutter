// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/notification_providers.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? userId;
  NotificationFilter _filter = NotificationFilter(userId: '');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final currentUser = await ref.read(currentUserProvider.future);
    if (currentUser != null && mounted) {
      setState(() {
        userId = currentUser.id;
        _filter = _filter.copyWith(userId: currentUser.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final notificationStats =
        ref.watch(notificationStatisticsProvider(userId!));
    final unreadCount = ref.watch(unreadNotificationCountProvider(userId!));
    final managementState = ref.watch(notificationManagementProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Notifications',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            unreadCount.when(
              data: (count) => count > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        count.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => const SizedBox.shrink(),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: ListTile(
                  leading: Icon(Icons.mark_email_read),
                  title: Text('Mark All Read'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: ListTile(
                  leading: Icon(Icons.clear_all),
                  title: Text('Clear All'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'test',
                child: ListTile(
                  leading: Icon(Icons.notifications_active),
                  title: Text('Send Test'),
                  contentPadding: EdgeInsets.zero,
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
            Tab(text: 'All', icon: Icon(Icons.notifications)),
            Tab(text: 'Unread', icon: Icon(Icons.mark_email_unread)),
            Tab(text: 'Emergency', icon: Icon(Icons.emergency)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Statistics Section
          _buildStatsSection(notificationStats),

          // Filter Section
          _buildFilterSection(),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllNotificationsTab(),
                _buildUnreadNotificationsTab(),
                _buildEmergencyNotificationsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.invalidate(notificationsProvider),
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.refresh, color: Colors.white),
        tooltip: 'Refresh Notifications',
      ),
    );
  }

  Widget _buildStatsSection(Map<String, int> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatChip('Total', stats['total'] ?? 0, Colors.blue),
          const SizedBox(width: 8),
          _buildStatChip('Unread', stats['unread'] ?? 0, Colors.orange),
          const SizedBox(width: 8),
          _buildStatChip('Critical', stats['critical'] ?? 0, Colors.red),
          const SizedBox(width: 8),
          _buildStatChip('Today', stats['today'] ?? 0, Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Route Updates'),
                    selected: _filter.types.contains('route_update'),
                    onSelected: (selected) => _toggleTypeFilter('route_update'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Emergencies'),
                    selected: _filter.types.contains('emergency_assignment'),
                    onSelected: (selected) =>
                        _toggleTypeFilter('emergency_assignment'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('High Priority'),
                    selected: _filter.priorities.contains('high'),
                    onSelected: (selected) => _togglePriorityFilter('high'),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<NotificationSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort Options',
            onSelected: (option) {
              setState(() {
                _filter = _filter.copyWith(sortBy: option);
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: NotificationSortOption.newest,
                child: Text('Newest First'),
              ),
              const PopupMenuItem(
                value: NotificationSortOption.oldest,
                child: Text('Oldest First'),
              ),
              const PopupMenuItem(
                value: NotificationSortOption.priority,
                child: Text('By Priority'),
              ),
              const PopupMenuItem(
                value: NotificationSortOption.type,
                child: Text('By Type'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllNotificationsTab() {
    final filteredNotifications =
        ref.watch(filteredNotificationsProvider(_filter));

    return _buildNotificationsList(filteredNotifications);
  }

  Widget _buildUnreadNotificationsTab() {
    final unreadFilter = _filter.copyWith(showUnreadOnly: true);
    final filteredNotifications =
        ref.watch(filteredNotificationsProvider(unreadFilter));

    return _buildNotificationsList(filteredNotifications);
  }

  Widget _buildEmergencyNotificationsTab() {
    final emergencyFilter = _filter.copyWith(
      types: ['emergency_assignment', 'new_route'],
      priorities: ['critical', 'high'],
    );
    final filteredNotifications =
        ref.watch(filteredNotificationsProvider(emergencyFilter));

    return _buildNotificationsList(filteredNotifications);
  }

  Widget _buildNotificationsList(List<NotificationModel> notifications) {
    if (notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No notifications found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Notifications will appear here when you receive them',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: notification.isRead ? 1 : 3,
      color: notification.isRead ? null : Colors.blue.shade50,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _handleNotificationTap(notification),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: notification.priorityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      notification.typeIcon,
                      color: notification.priorityColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.isRead
                                ? FontWeight.w500
                                : FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    notification.priorityColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                notification.priority.toUpperCase(),
                                style: TextStyle(
                                  color: notification.priorityColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              notification.timeAgo,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                notification.message,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),

              // Additional data if available
              if (notification.data.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildNotificationData(notification),
              ],

              // Actions
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!notification.isRead)
                    TextButton.icon(
                      onPressed: () => _markAsRead(notification.id),
                      icon: const Icon(Icons.mark_email_read, size: 16),
                      label: const Text('Mark Read'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _viewDetails(notification),
                    child: const Text('View Details'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationData(NotificationModel notification) {
    final data = notification.data;
    final dataEntries = data.entries
        .where((entry) => !['type', 'timestamp'].contains(entry.key))
        .take(3);

    if (dataEntries.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: dataEntries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Text(
                  '${_formatDataKey(entry.key)}:',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.value.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _toggleTypeFilter(String type) {
    setState(() {
      final types = List<String>.from(_filter.types);
      if (types.contains(type)) {
        types.remove(type);
      } else {
        types.add(type);
      }
      _filter = _filter.copyWith(types: types);
    });
  }

  void _togglePriorityFilter(String priority) {
    setState(() {
      final priorities = List<String>.from(_filter.priorities);
      if (priorities.contains(priority)) {
        priorities.remove(priority);
      } else {
        priorities.add(priority);
      }
      _filter = _filter.copyWith(priorities: priorities);
    });
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'mark_all_read':
        _markAllAsRead();
        break;
      case 'clear_all':
        _clearAllNotifications();
        break;
      case 'settings':
        _openNotificationSettings();
        break;
      case 'test':
        _sendTestNotification();
        break;
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    if (!notification.isRead) {
      _markAsRead(notification.id);
    }

    // Navigate based on notification type
    switch (notification.type) {
      case 'emergency_assignment':
        _navigateToEmergencyDetails(notification.data);
        break;
      case 'new_route':
      case 'route_update':
      case 'route_cleared':
      case 'route_timeout':
        _navigateToRouteDetails(notification.data);
        break;
      default:
        _viewDetails(notification);
    }
  }

  void _markAsRead(String notificationId) {
    ref
        .read(notificationManagementProvider.notifier)
        .markAsRead(notificationId);
  }

  void _markAllAsRead() async {
    final confirmed = await _showConfirmationDialog(
      'Mark All Read',
      'Are you sure you want to mark all notifications as read?',
    );

    if (confirmed) {
      ref.read(notificationManagementProvider.notifier).markAllAsRead(userId!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _clearAllNotifications() async {
    final confirmed = await _showConfirmationDialog(
      'Clear All Notifications',
      'Are you sure you want to delete all notifications? This action cannot be undone.',
    );

    if (confirmed) {
      ref.read(notificationManagementProvider.notifier).clearAll(userId!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications cleared'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _openNotificationSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationSettingsScreen(),
      ),
    );
  }

  void _sendTestNotification() {
    ref.read(notificationManagementProvider.notifier).sendTestNotification(
          userId!,
          'Test Notification',
          'This is a test notification to verify your notification settings are working correctly.',
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test notification sent'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _viewDetails(NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(notification.message),
              const SizedBox(height: 16),
              if (notification.data.isNotEmpty) ...[
                const Text(
                  'Additional Information:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...notification.data.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_formatDataKey(entry.key)}:',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(entry.value.toString()),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Received: ${notification.createdAt}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              if (notification.readAt != null)
                Text(
                  'Read: ${notification.readAt}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _navigateToEmergencyDetails(Map<String, dynamic> data) {
    final emergencyId = data['emergencyId'] as String?;
    if (emergencyId != null) {
      // Navigate to emergency details screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigate to Emergency: $emergencyId'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _navigateToRouteDetails(Map<String, dynamic> data) {
    final routeId = data['routeId'] as String?;
    if (routeId != null) {
      // Navigate to route details screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigate to Route: $routeId'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Confirm',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _formatDataKey(String key) {
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

// Notification Settings Screen
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(notificationSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notification Settings',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Notification Types
          _buildSectionHeader('Notification Types'),
          _buildSettingsTile(
            title: 'Emergency Notifications',
            subtitle: 'Critical emergency assignments and alerts',
            value: settingsState.emergencyNotifications,
            onChanged: (value) => ref
                .read(notificationSettingsProvider.notifier)
                .updateEmergencyNotifications(value),
            icon: Icons.emergency,
            color: Colors.red,
          ),
          _buildSettingsTile(
            title: 'Route Notifications',
            subtitle: 'Ambulance route updates and traffic alerts',
            value: settingsState.routeNotifications,
            onChanged: (value) => ref
                .read(notificationSettingsProvider.notifier)
                .updateRouteNotifications(value),
            icon: Icons.route,
            color: Colors.blue,
          ),
          _buildSettingsTile(
            title: 'General Notifications',
            subtitle: 'App updates and general information',
            value: settingsState.generalNotifications,
            onChanged: (value) => ref
                .read(notificationSettingsProvider.notifier)
                .updateGeneralNotifications(value),
            icon: Icons.notifications,
            color: Colors.green,
          ),

          const SizedBox(height: 24),

          // Sound & Vibration
          _buildSectionHeader('Sound & Vibration'),
          _buildSettingsTile(
            title: 'Sound',
            subtitle: 'Play notification sounds',
            value: settingsState.soundEnabled,
            onChanged: (value) => ref
                .read(notificationSettingsProvider.notifier)
                .updateSoundEnabled(value),
            icon: Icons.volume_up,
            color: Colors.orange,
          ),
          _buildSettingsTile(
            title: 'Vibration',
            subtitle: 'Vibrate for notifications',
            value: settingsState.vibrationEnabled,
            onChanged: (value) => ref
                .read(notificationSettingsProvider.notifier)
                .updateVibrationEnabled(value),
            icon: Icons.vibration,
            color: Colors.purple,
          ),

          const SizedBox(height: 24),

          // Notification Tone
          _buildSectionHeader('Notification Tone'),
          ListTile(
            leading: const Icon(Icons.music_note, color: Colors.indigo),
            title: const Text('Notification Sound'),
            subtitle: Text('Current: ${settingsState.notificationTone}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () =>
                _showToneSelector(context, ref, settingsState.notificationTone),
          ),

          const SizedBox(height: 24),

          // Test Notifications
          _buildSectionHeader('Test'),
          ListTile(
            leading: const Icon(Icons.notifications_active, color: Colors.teal),
            title: const Text('Send Test Notification'),
            subtitle: const Text('Test your notification settings'),
            trailing: ElevatedButton(
              onPressed: () => _sendTestNotification(context, ref),
              child: const Text('Test'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: color,
      ),
    );
  }

  void _showToneSelector(
      BuildContext context, WidgetRef ref, String currentTone) {
    final tones = [
      'default',
      'emergency_alert',
      'route_alert',
      'gentle',
      'urgent',
      'classic',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Notification Tone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: tones
              .map((tone) => RadioListTile<String>(
                    title: Text(tone.replaceAll('_', ' ').toUpperCase()),
                    value: tone,
                    groupValue: currentTone,
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(notificationSettingsProvider.notifier)
                            .updateNotificationTone(value);
                        Navigator.of(context).pop();
                      }
                    },
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _sendTestNotification(BuildContext context, WidgetRef ref) async {
    // Get current user ID
    final currentUser = await ref.read(currentUserProvider.future);
    if (currentUser != null) {
      ref.read(notificationManagementProvider.notifier).sendTestNotification(
            currentUser.id,
            'Test Notification',
            'This is a test notification to verify your settings are working correctly.',
          );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
