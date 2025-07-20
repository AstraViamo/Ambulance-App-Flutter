// lib/providers/notification_providers.dart
import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/notification_settings_service.dart';
import 'auth_provider.dart';

// Notification service provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final notificationSettingsServiceProvider =
    Provider<NotificationSettingsService>((ref) {
  return NotificationSettingsService();
});

// Notifications stream provider for a specific user
final notificationsProvider =
    StreamProvider.family<List<NotificationModel>, String>(
  (ref, userId) {
    final notificationService = ref.watch(notificationServiceProvider);
    return notificationService.getNotificationsForUser(userId);
  },
);

// Unread notification count provider
final unreadNotificationCountProvider = StreamProvider.family<int, String>(
  (ref, userId) {
    final notificationService = ref.watch(notificationServiceProvider);
    return notificationService.getUnreadNotificationCount(userId);
  },
);

// Notification management state
class NotificationManagementState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  NotificationManagementState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });

  NotificationManagementState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) {
    return NotificationManagementState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

// Notification management notifier
class NotificationManagementNotifier
    extends StateNotifier<NotificationManagementState> {
  final NotificationService _notificationService;

  NotificationManagementNotifier(this._notificationService)
      : super(NotificationManagementState());

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      await _notificationService.markNotificationAsRead(notificationId);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      log('Error marking notification as read: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      await _notificationService.markAllNotificationsAsRead(userId);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      log('Error marking all notifications as read: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Clear all notifications
  Future<void> clearAll(String userId) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      await _notificationService.clearAllNotifications(userId);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      log('Error clearing all notifications: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Update FCM token
  Future<void> updateFCMToken(String userId) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      await _notificationService.updateUserFCMToken(userId);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      log('Error updating FCM token: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Send test notification
  Future<void> sendTestNotification(
      String userId, String title, String message) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      await _notificationService.sendPushNotification(
        userId: userId,
        title: title,
        message: message,
        data: {'type': 'test', 'timestamp': DateTime.now().toIso8601String()},
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      log('Error sending test notification: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() {
    state = NotificationManagementState();
  }
}

// Notification management provider
final notificationManagementProvider = StateNotifierProvider<
    NotificationManagementNotifier, NotificationManagementState>(
  (ref) =>
      NotificationManagementNotifier(ref.watch(notificationServiceProvider)),
);

// Filtered notifications provider
final filteredNotificationsProvider =
    Provider.family<List<NotificationModel>, NotificationFilter>(
  (ref, filter) {
    final notificationsAsync = ref.watch(notificationsProvider(filter.userId));

    return notificationsAsync.when(
      data: (notifications) {
        var filtered = notifications;

        // Filter by type
        if (filter.types.isNotEmpty) {
          filtered =
              filtered.where((n) => filter.types.contains(n.type)).toList();
        }

        // Filter by read status
        if (filter.showUnreadOnly) {
          filtered = filtered.where((n) => !n.isRead).toList();
        }

        // Filter by priority
        if (filter.priorities.isNotEmpty) {
          filtered = filtered
              .where((n) => filter.priorities.contains(n.priority))
              .toList();
        }

        // Filter by date range
        if (filter.dateRange != null) {
          final start = filter.dateRange!.start;
          final end = filter.dateRange!.end;
          filtered = filtered
              .where((n) =>
                  n.createdAt.isAfter(start) && n.createdAt.isBefore(end))
              .toList();
        }

        // Sort
        switch (filter.sortBy) {
          case NotificationSortOption.newest:
            filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            break;
          case NotificationSortOption.oldest:
            filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            break;
          case NotificationSortOption.priority:
            filtered.sort((a, b) => _priorityValue(b.priority)
                .compareTo(_priorityValue(a.priority)));
            break;
          case NotificationSortOption.type:
            filtered.sort((a, b) => a.type.compareTo(b.type));
            break;
        }

        return filtered;
      },
      loading: () => <NotificationModel>[],
      error: (error, stack) => <NotificationModel>[],
    );
  },
);

// Notification statistics provider
final notificationStatisticsProvider =
    Provider.family<Map<String, int>, String>(
  (ref, userId) {
    final notificationsAsync = ref.watch(notificationsProvider(userId));

    return notificationsAsync.when(
      data: (notifications) {
        final stats = <String, int>{
          'total': notifications.length,
          'unread': notifications.where((n) => !n.isRead).length,
          'critical':
              notifications.where((n) => n.priority == 'critical').length,
          'high': notifications.where((n) => n.priority == 'high').length,
          'emergency': notifications
              .where((n) => n.type == 'emergency_assignment')
              .length,
          'route': notifications.where((n) => n.type.contains('route')).length,
        };

        // Today's notifications
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        stats['today'] =
            notifications.where((n) => n.createdAt.isAfter(startOfDay)).length;

        // This week's notifications
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        final startOfWeekDay =
            DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        stats['thisWeek'] = notifications
            .where((n) => n.createdAt.isAfter(startOfWeekDay))
            .length;

        return stats;
      },
      loading: () => <String, int>{},
      error: (error, stack) => <String, int>{},
    );
  },
);

// Recent notifications provider (last 5)
final recentNotificationsProvider =
    Provider.family<List<NotificationModel>, String>(
  (ref, userId) {
    final notificationsAsync = ref.watch(notificationsProvider(userId));

    return notificationsAsync.when(
      data: (notifications) => notifications.take(5).toList(),
      loading: () => <NotificationModel>[],
      error: (error, stack) => <NotificationModel>[],
    );
  },
);

// Notification settings state
class NotificationSettingsState {
  final bool emergencyNotifications;
  final bool routeNotifications;
  final bool generalNotifications;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final String notificationTone;
  final bool isLoading;
  final String? error;

  NotificationSettingsState({
    this.emergencyNotifications = true,
    this.routeNotifications = true,
    this.generalNotifications = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.notificationTone = 'default',
    this.isLoading = false,
    this.error,
  });

  NotificationSettingsState copyWith({
    bool? emergencyNotifications,
    bool? routeNotifications,
    bool? generalNotifications,
    bool? soundEnabled,
    bool? vibrationEnabled,
    String? notificationTone,
    bool? isLoading,
    String? error,
  }) {
    return NotificationSettingsState(
      emergencyNotifications:
          emergencyNotifications ?? this.emergencyNotifications,
      routeNotifications: routeNotifications ?? this.routeNotifications,
      generalNotifications: generalNotifications ?? this.generalNotifications,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      notificationTone: notificationTone ?? this.notificationTone,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Notification settings notifier
class NotificationSettingsNotifier
    extends StateNotifier<NotificationSettingsState> {
  final NotificationService _notificationService;
  final NotificationSettingsService _settingsService;
  String? _currentUserId;

  NotificationSettingsNotifier(this._notificationService, this._settingsService)
      : super(NotificationSettingsState());

  /// Load notification settings for a user
  Future<void> loadSettings(String userId) async {
    if (_currentUserId == userId && !state.isLoading) {
      return; // Already loaded for this user
    }

    state = state.copyWith(isLoading: true, error: null);
    _currentUserId = userId;

    try {
      final settingsData = await _settingsService.loadSettings(userId);

      state = NotificationSettingsState(
        emergencyNotifications: settingsData.emergencyNotifications,
        routeNotifications: settingsData.routeNotifications,
        generalNotifications: settingsData.generalNotifications,
        soundEnabled: settingsData.soundEnabled,
        vibrationEnabled: settingsData.vibrationEnabled,
        notificationTone: settingsData.notificationTone,
        isLoading: false,
        error: null,
      );

      log('Notification settings loaded successfully for user $userId');
    } catch (e) {
      log('Error loading notification settings: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load settings: ${e.toString()}',
      );
    }
  }

  /// Update emergency notifications setting
  Future<void> updateEmergencyNotifications(bool enabled) async {
    if (_currentUserId == null) return;

    state = state.copyWith(emergencyNotifications: enabled);
    await _saveSettings();
  }

  /// Update route notifications setting
  Future<void> updateRouteNotifications(bool enabled) async {
    if (_currentUserId == null) return;

    state = state.copyWith(routeNotifications: enabled);
    await _saveSettings();
  }

  /// Update general notifications setting
  Future<void> updateGeneralNotifications(bool enabled) async {
    if (_currentUserId == null) return;

    state = state.copyWith(generalNotifications: enabled);
    await _saveSettings();
  }

  /// Update sound setting
  Future<void> updateSoundEnabled(bool enabled) async {
    if (_currentUserId == null) return;

    state = state.copyWith(soundEnabled: enabled);
    await _saveSettings();
  }

  /// Update vibration setting
  Future<void> updateVibrationEnabled(bool enabled) async {
    if (_currentUserId == null) return;

    state = state.copyWith(vibrationEnabled: enabled);
    await _saveSettings();
  }

  /// Update notification tone
  Future<void> updateNotificationTone(String tone) async {
    if (_currentUserId == null) return;

    state = state.copyWith(notificationTone: tone);
    await _saveSettings();
  }

  /// Save current settings to storage
  Future<void> _saveSettings() async {
    if (_currentUserId == null) return;

    try {
      final settingsData = NotificationSettingsData(
        emergencyNotifications: state.emergencyNotifications,
        routeNotifications: state.routeNotifications,
        generalNotifications: state.generalNotifications,
        soundEnabled: state.soundEnabled,
        vibrationEnabled: state.vibrationEnabled,
        notificationTone: state.notificationTone,
        lastUpdated: DateTime.now(),
      );

      await _settingsService.saveSettings(_currentUserId!, settingsData);
      log('Notification settings saved successfully');

      // Clear any previous errors
      if (state.error != null) {
        state = state.copyWith(error: null);
      }
    } catch (e) {
      log('Error saving notification settings: $e');
      state = state.copyWith(error: 'Failed to save settings: ${e.toString()}');
    }
  }

  /// Reset settings to defaults
  Future<void> resetToDefaults() async {
    if (_currentUserId == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final defaultSettings = NotificationSettingsData.defaultSettings();
      await _settingsService.saveSettings(_currentUserId!, defaultSettings);

      state = NotificationSettingsState(
        emergencyNotifications: defaultSettings.emergencyNotifications,
        routeNotifications: defaultSettings.routeNotifications,
        generalNotifications: defaultSettings.generalNotifications,
        soundEnabled: defaultSettings.soundEnabled,
        vibrationEnabled: defaultSettings.vibrationEnabled,
        notificationTone: defaultSettings.notificationTone,
        isLoading: false,
        error: null,
      );

      log('Settings reset to defaults');
    } catch (e) {
      log('Error resetting settings: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to reset settings: ${e.toString()}',
      );
    }
  }

  /// Sync local settings to cloud (useful after offline changes)
  Future<void> syncToCloud() async {
    if (_currentUserId == null) return;

    try {
      await _settingsService.syncToFirestore(_currentUserId!);
      log('Settings synced to cloud');
    } catch (e) {
      log('Error syncing settings to cloud: $e');
    }
  }

  /// Check if user should receive a specific notification type
  Future<bool> shouldReceiveNotification(String notificationType) async {
    if (_currentUserId == null) return true;

    return await _settingsService.shouldReceiveNotification(
        _currentUserId!, notificationType);
  }
}

// Notification settings provider
final notificationSettingsProvider = StateNotifierProvider<
    NotificationSettingsNotifier, NotificationSettingsState>(
  (ref) => NotificationSettingsNotifier(
    ref.watch(notificationServiceProvider),
    ref.watch(notificationSettingsServiceProvider),
  ),
);

final currentUserNotificationSettingsProvider =
    FutureProvider<NotificationSettingsState>((ref) async {
  final currentUser = await ref.watch(currentUserProvider.future);
  if (currentUser == null) {
    return NotificationSettingsState(); // Default state
  }

  // Load settings for current user
  final notifier = ref.read(notificationSettingsProvider.notifier);
  await notifier.loadSettings(currentUser.id);

  return ref.read(notificationSettingsProvider);
});

// Notification filter model
class NotificationFilter {
  final String userId;
  final List<String> types;
  final List<String> priorities;
  final bool showUnreadOnly;
  final DateTimeRange? dateRange;
  final NotificationSortOption sortBy;

  NotificationFilter({
    required this.userId,
    this.types = const [],
    this.priorities = const [],
    this.showUnreadOnly = false,
    this.dateRange,
    this.sortBy = NotificationSortOption.newest,
  });

  NotificationFilter copyWith({
    String? userId,
    List<String>? types,
    List<String>? priorities,
    bool? showUnreadOnly,
    DateTimeRange? dateRange,
    NotificationSortOption? sortBy,
  }) {
    return NotificationFilter(
      userId: userId ?? this.userId,
      types: types ?? this.types,
      priorities: priorities ?? this.priorities,
      showUnreadOnly: showUnreadOnly ?? this.showUnreadOnly,
      dateRange: dateRange ?? this.dateRange,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

// Notification sort options
enum NotificationSortOption {
  newest,
  oldest,
  priority,
  type,
}

// Date range model
class DateTimeRange {
  final DateTime start;
  final DateTime end;

  DateTimeRange({required this.start, required this.end});
}

// Helper function to get priority value for sorting
int _priorityValue(String priority) {
  switch (priority) {
    case 'critical':
      return 4;
    case 'high':
      return 3;
    case 'normal':
      return 2;
    case 'low':
      return 1;
    default:
      return 0;
  }
}

// Notification action providers
final markNotificationAsReadProvider =
    Provider.family<Future<void> Function(), String>(
  (ref, notificationId) {
    return () async {
      await ref
          .read(notificationManagementProvider.notifier)
          .markAsRead(notificationId);
    };
  },
);

final markAllNotificationsAsReadProvider =
    Provider.family<Future<void> Function(), String>(
  (ref, userId) {
    return () async {
      await ref
          .read(notificationManagementProvider.notifier)
          .markAllAsRead(userId);
    };
  },
);

final clearAllNotificationsProvider =
    Provider.family<Future<void> Function(), String>(
  (ref, userId) {
    return () async {
      await ref.read(notificationManagementProvider.notifier).clearAll(userId);
    };
  },
);
