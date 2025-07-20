// lib/services/notification_settings_service.dart
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing notification settings with dual storage
/// (Firestore for sync + SharedPreferences for offline access)
class NotificationSettingsService {
  static final NotificationSettingsService _instance =
      NotificationSettingsService._internal();
  factory NotificationSettingsService() => _instance;
  NotificationSettingsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Settings keys
  static const String _emergencyNotificationsKey = 'emergency_notifications';
  static const String _routeNotificationsKey = 'route_notifications';
  static const String _generalNotificationsKey = 'general_notifications';
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _vibrationEnabledKey = 'vibration_enabled';
  static const String _notificationToneKey = 'notification_tone';
  static const String _settingsVersionKey = 'settings_version';

  /// Load notification settings for a user
  Future<NotificationSettingsData> loadSettings(String userId) async {
    try {
      // Try to load from Firestore first (most up-to-date)
      final firestoreSettings = await _loadFromFirestore(userId);
      if (firestoreSettings != null) {
        // Cache in SharedPreferences for offline access
        await _saveToSharedPreferences(firestoreSettings);
        return firestoreSettings;
      }

      // Fallback to SharedPreferences if Firestore fails
      final localSettings = await _loadFromSharedPreferences();
      if (localSettings != null) {
        return localSettings;
      }

      // Return default settings if nothing found
      return NotificationSettingsData.defaultSettings();
    } catch (e) {
      log('Error loading notification settings: $e');

      // Try local fallback
      try {
        final localSettings = await _loadFromSharedPreferences();
        return localSettings ?? NotificationSettingsData.defaultSettings();
      } catch (localError) {
        log('Error loading local settings: $localError');
        return NotificationSettingsData.defaultSettings();
      }
    }
  }

  /// Save notification settings for a user
  Future<void> saveSettings(
      String userId, NotificationSettingsData settings) async {
    try {
      // Save to both Firestore and SharedPreferences
      await Future.wait([
        _saveToFirestore(userId, settings),
        _saveToSharedPreferences(settings),
      ]);

      log('Notification settings saved successfully');
    } catch (e) {
      log('Error saving notification settings: $e');

      // At least try to save locally if Firestore fails
      try {
        await _saveToSharedPreferences(settings);
        log('Settings saved locally, will sync when connection is restored');
      } catch (localError) {
        log('Failed to save settings locally: $localError');
        throw Exception('Failed to save notification settings');
      }
    }
  }

  /// Load settings from Firestore
  Future<NotificationSettingsData?> _loadFromFirestore(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_settings')
          .doc(userId)
          .collection('preferences')
          .doc('notifications')
          .get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;
      return NotificationSettingsData.fromFirestore(data);
    } catch (e) {
      log('Error loading settings from Firestore: $e');
      return null;
    }
  }

  /// Save settings to Firestore
  Future<void> _saveToFirestore(
      String userId, NotificationSettingsData settings) async {
    try {
      await _firestore
          .collection('user_settings')
          .doc(userId)
          .collection('preferences')
          .doc('notifications')
          .set(settings.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      log('Error saving settings to Firestore: $e');
      rethrow;
    }
  }

  /// Load settings from SharedPreferences
  Future<NotificationSettingsData?> _loadFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if settings exist
      if (!prefs.containsKey(_emergencyNotificationsKey)) {
        return null;
      }

      return NotificationSettingsData(
        emergencyNotifications:
            prefs.getBool(_emergencyNotificationsKey) ?? true,
        routeNotifications: prefs.getBool(_routeNotificationsKey) ?? true,
        generalNotifications: prefs.getBool(_generalNotificationsKey) ?? true,
        soundEnabled: prefs.getBool(_soundEnabledKey) ?? true,
        vibrationEnabled: prefs.getBool(_vibrationEnabledKey) ?? true,
        notificationTone: prefs.getString(_notificationToneKey) ?? 'default',
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      log('Error loading settings from SharedPreferences: $e');
      return null;
    }
  }

  /// Save settings to SharedPreferences
  Future<void> _saveToSharedPreferences(
      NotificationSettingsData settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await Future.wait([
        prefs.setBool(
            _emergencyNotificationsKey, settings.emergencyNotifications),
        prefs.setBool(_routeNotificationsKey, settings.routeNotifications),
        prefs.setBool(_generalNotificationsKey, settings.generalNotifications),
        prefs.setBool(_soundEnabledKey, settings.soundEnabled),
        prefs.setBool(_vibrationEnabledKey, settings.vibrationEnabled),
        prefs.setString(_notificationToneKey, settings.notificationTone),
        prefs.setString(_settingsVersionKey, DateTime.now().toIso8601String()),
      ]);
    } catch (e) {
      log('Error saving settings to SharedPreferences: $e');
      rethrow;
    }
  }

  /// Check if user should receive notification based on settings
  Future<bool> shouldReceiveNotification(
      String userId, String notificationType) async {
    try {
      final settings = await loadSettings(userId);

      switch (notificationType) {
        case 'emergency_assignment':
          return settings.emergencyNotifications;
        case 'new_route':
        case 'route_update':
        case 'route_cleared':
        case 'route_timeout':
          return settings.routeNotifications;
        case 'general':
        case 'test':
        default:
          return settings.generalNotifications;
      }
    } catch (e) {
      log('Error checking notification permission: $e');
      return true; // Default to allowing notifications if check fails
    }
  }

  /// Get sound/vibration preferences for notification
  Future<NotificationPreferences> getNotificationPreferences(
      String userId) async {
    try {
      final settings = await loadSettings(userId);
      return NotificationPreferences(
        soundEnabled: settings.soundEnabled,
        vibrationEnabled: settings.vibrationEnabled,
        notificationTone: settings.notificationTone,
      );
    } catch (e) {
      log('Error getting notification preferences: $e');
      return NotificationPreferences.defaultPreferences();
    }
  }

  /// Sync local settings to Firestore (useful for offline-first approach)
  Future<void> syncToFirestore(String userId) async {
    try {
      final localSettings = await _loadFromSharedPreferences();
      if (localSettings != null) {
        await _saveToFirestore(userId, localSettings);
        log('Local settings synced to Firestore');
      }
    } catch (e) {
      log('Error syncing settings to Firestore: $e');
    }
  }
}

/// Data class for notification settings
class NotificationSettingsData {
  final bool emergencyNotifications;
  final bool routeNotifications;
  final bool generalNotifications;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final String notificationTone;
  final DateTime lastUpdated;

  NotificationSettingsData({
    required this.emergencyNotifications,
    required this.routeNotifications,
    required this.generalNotifications,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.notificationTone,
    required this.lastUpdated,
  });

  factory NotificationSettingsData.defaultSettings() {
    return NotificationSettingsData(
      emergencyNotifications: true,
      routeNotifications: true,
      generalNotifications: true,
      soundEnabled: true,
      vibrationEnabled: true,
      notificationTone: 'default',
      lastUpdated: DateTime.now(),
    );
  }

  factory NotificationSettingsData.fromFirestore(Map<String, dynamic> data) {
    return NotificationSettingsData(
      emergencyNotifications: data['emergencyNotifications'] ?? true,
      routeNotifications: data['routeNotifications'] ?? true,
      generalNotifications: data['generalNotifications'] ?? true,
      soundEnabled: data['soundEnabled'] ?? true,
      vibrationEnabled: data['vibrationEnabled'] ?? true,
      notificationTone: data['notificationTone'] ?? 'default',
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'emergencyNotifications': emergencyNotifications,
      'routeNotifications': routeNotifications,
      'generalNotifications': generalNotifications,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'notificationTone': notificationTone,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  NotificationSettingsData copyWith({
    bool? emergencyNotifications,
    bool? routeNotifications,
    bool? generalNotifications,
    bool? soundEnabled,
    bool? vibrationEnabled,
    String? notificationTone,
    DateTime? lastUpdated,
  }) {
    return NotificationSettingsData(
      emergencyNotifications:
          emergencyNotifications ?? this.emergencyNotifications,
      routeNotifications: routeNotifications ?? this.routeNotifications,
      generalNotifications: generalNotifications ?? this.generalNotifications,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      notificationTone: notificationTone ?? this.notificationTone,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Notification preferences for sound/vibration
class NotificationPreferences {
  final bool soundEnabled;
  final bool vibrationEnabled;
  final String notificationTone;

  NotificationPreferences({
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.notificationTone,
  });

  factory NotificationPreferences.defaultPreferences() {
    return NotificationPreferences(
      soundEnabled: true,
      vibrationEnabled: true,
      notificationTone: 'default',
    );
  }
}
