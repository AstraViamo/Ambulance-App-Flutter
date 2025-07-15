// lib/services/enhanced_notification_service.dart
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/route_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isInitialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request notification permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: true,
        carPlay: true,
        criticalAlert: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        log('Notification permission granted');
      } else {
        log('Notification permission denied');
        return;
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Set up message handlers
      _setupMessageHandlers();

      _isInitialized = true;
      log('Notification service initialized');
    } catch (e) {
      log('Error initializing notification service: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInitSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels
    await _createNotificationChannels();
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    // Emergency channel for critical alerts
    const emergencyChannel = AndroidNotificationChannel(
      'emergency_channel',
      'Emergency Notifications',
      description: 'Critical emergency alerts and assignments',
      importance: Importance.max,
      enableVibration: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 255, 0, 0),
      sound: RawResourceAndroidNotificationSound('emergency_alert'),
    );

    // Route channel for police notifications
    const routeChannel = AndroidNotificationChannel(
      'route_channel',
      'Route Notifications',
      description: 'Ambulance route updates and traffic management',
      importance: Importance.high,
      enableVibration: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 0, 0, 255),
      sound: RawResourceAndroidNotificationSound('route_alert'),
    );

    // General channel for other notifications
    const generalChannel = AndroidNotificationChannel(
      'general_channel',
      'General Notifications',
      description: 'General app notifications and updates',
      importance: Importance.defaultImportance,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(emergencyChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(routeChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(generalChannel);
  }

  /// Setup Firebase message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle app opened from terminated state
    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleNotificationTap(message);
      }
    });
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    log('Received foreground message: ${message.messageId}');

    final notificationType = message.data['type'] ?? 'general';

    // Show local notification for foreground messages
    await _showLocalNotification(
      title: message.notification?.title ?? _getDefaultTitle(notificationType),
      body: message.notification?.body ?? _getDefaultBody(notificationType),
      payload: jsonEncode(message.data),
      type: notificationType,
    );
  }

  /// Handle notification tap
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    log('Notification tapped: ${message.data}');
    await _processNotificationAction(message.data);
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _processNotificationAction(data);
      } catch (e) {
        log('Error parsing notification payload: $e');
      }
    }
  }

  /// Process notification action based on type
  Future<void> _processNotificationAction(Map<String, dynamic> data) async {
    final type = data['type'] as String?;

    switch (type) {
      case 'emergency_assignment':
        _handleEmergencyAssignmentTap(data);
        break;
      case 'new_route':
        _handleNewRouteTap(data);
        break;
      case 'route_update':
        _handleRouteUpdateTap(data);
        break;
      case 'route_cleared':
        _handleRouteClearedTap(data);
        break;
      case 'route_timeout':
        _handleRouteTimeoutTap(data);
        break;
      default:
        log('Unknown notification type: $type');
    }
  }

  /// Show local notification with enhanced styling
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String type = 'general',
  }) async {
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Determine channel and styling based on type
    String channelId;
    String? sound;
    List<int> vibrationPattern;
    Color? color;

    switch (type) {
      case 'emergency_assignment':
      case 'new_route':
        channelId = 'emergency_channel';
        sound = 'emergency_alert';
        vibrationPattern = [0, 1000, 500, 1000, 500, 1000];
        color = const Color.fromARGB(255, 255, 0, 0);
        break;
      case 'route_update':
      case 'route_cleared':
      case 'route_timeout':
        channelId = 'route_channel';
        sound = 'route_alert';
        vibrationPattern = [0, 500, 200, 500];
        color = const Color.fromARGB(255, 0, 0, 255);
        break;
      default:
        channelId = 'general_channel';
        sound = null;
        vibrationPattern = [0, 250];
        color = null;
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: type.contains('emergency') || type.contains('route')
          ? Importance.max
          : Importance.defaultImportance,
      priority: type.contains('emergency') || type.contains('route')
          ? Priority.high
          : Priority.defaultPriority,
      sound: sound != null ? RawResourceAndroidNotificationSound(sound) : null,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(vibrationPattern),
      color: color,
      colorized: color != null,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: type == 'emergency_assignment',
      enableLights: true,
      ledColor: color,
      ticker: title,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      usesChronometer: false,
      timeoutAfter: type.contains('emergency') ? null : 30000,
      ongoing: type == 'emergency_assignment',
      autoCancel: !type.contains('emergency'),
    );

    final iosDetails = DarwinNotificationDetails(
      sound: sound != null ? '$sound.wav' : null,
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
      threadIdentifier: type,
      categoryIdentifier: type,
      interruptionLevel: type.contains('emergency')
          ? InterruptionLevel.critical
          : InterruptionLevel.active,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notificationId,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // EMERGENCY ASSIGNMENT NOTIFICATIONS

  /// Send notification to specific driver for emergency assignment
  Future<bool> sendNotificationToDriver({
    required String driverId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Create in-app notification
      await _createInAppNotification(
        recipientId: driverId,
        type: 'emergency_assignment',
        title: title,
        message: message,
        data: data ?? {},
        priority: 'high',
      );

      // Queue push notification
      await _queuePushNotification(
        recipientId: driverId,
        title: title,
        message: message,
        data: {
          'type': 'emergency_assignment',
          ...?data,
        },
        priority: 'high',
      );

      log('Emergency assignment notification sent to driver: $driverId');
      return true;
    } catch (e) {
      log('Error sending notification to driver: $e');
      return false;
    }
  }

  // POLICE ROUTE NOTIFICATIONS

  /// Send new route notification to all police officers
  Future<bool> sendNewRouteNotificationToPolice({
    required AmbulanceRouteModel route,
  }) async {
    try {
      final title =
          '🚨 New ${route.emergencyPriority.toUpperCase()} Emergency Route';
      final message =
          'Ambulance ${route.ambulanceLicensePlate} dispatched to ${route.patientLocation}. ETA: ${route.formattedETA}';

      // Get all active police officers
      final policeQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'police')
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in policeQuery.docs) {
        final userId = doc.id;

        // Create in-app notification
        await _createInAppNotification(
          recipientId: userId,
          type: 'new_route',
          title: title,
          message: message,
          data: {
            'routeId': route.id,
            'ambulanceId': route.ambulanceId,
            'emergencyId': route.emergencyId,
            'ambulanceLicensePlate': route.ambulanceLicensePlate,
            'eta': route.etaMinutes,
            'emergencyPriority': route.emergencyPriority,
            'patientLocation': route.patientLocation,
            'distance': route.formattedDistance,
            'duration': route.formattedDuration,
          },
          priority: route.isHighPriority ? 'critical' : 'high',
        );

        // Queue push notification for high priority routes
        if (route.isHighPriority) {
          await _queuePushNotification(
            recipientId: userId,
            title: title,
            message: message,
            data: {
              'type': 'new_route',
              'routeId': route.id,
              'ambulanceId': route.ambulanceId,
              'emergencyId': route.emergencyId,
              'priority': route.emergencyPriority,
            },
            priority: 'critical',
          );
        }
      }

      log('New route notifications sent to ${policeQuery.docs.length} police officers');
      return true;
    } catch (e) {
      log('Error sending new route notifications to police: $e');
      return false;
    }
  }

  // HOSPITAL ROUTE UPDATE NOTIFICATIONS

  /// Send route status update notification to hospital staff
  Future<bool> sendRouteUpdateNotificationToHospital({
    required AmbulanceRouteModel route,
    required RouteStatus newStatus,
    required String policeOfficerName,
    required String hospitalId,
  }) async {
    try {
      String title;
      String message;
      String emoji;

      switch (newStatus) {
        case RouteStatus.cleared:
          emoji = '✅';
          title = 'Route Cleared';
          message =
              'Route for Ambulance ${route.ambulanceLicensePlate} has been cleared by Officer $policeOfficerName';
          break;
        case RouteStatus.timeout:
          emoji = '⏰';
          title = 'Route Timeout';
          message =
              'Route for Ambulance ${route.ambulanceLicensePlate} marked as timeout by Officer $policeOfficerName';
          break;
        default:
          emoji = '📍';
          title = 'Route Update';
          message =
              'Route for Ambulance ${route.ambulanceLicensePlate} updated by Officer $policeOfficerName';
      }

      // Get hospital staff
      final hospitalQuery = await _firestore
          .collection('users')
          .where('role', whereIn: ['hospital_admin', 'hospital_staff'])
          .where('roleSpecificData.hospitalId', isEqualTo: hospitalId)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in hospitalQuery.docs) {
        final userId = doc.id;

        // Create in-app notification
        await _createInAppNotification(
          recipientId: userId,
          type: 'route_update',
          title: '$emoji $title',
          message: message,
          data: {
            'routeId': route.id,
            'ambulanceId': route.ambulanceId,
            'emergencyId': route.emergencyId,
            'ambulanceLicensePlate': route.ambulanceLicensePlate,
            'newStatus': newStatus.value,
            'policeOfficerId': route.policeOfficerId,
            'policeOfficerName': policeOfficerName,
            'patientLocation': route.patientLocation,
          },
          priority: 'normal',
        );

        // Queue push notification
        await _queuePushNotification(
          recipientId: userId,
          title: title,
          message: message,
          data: {
            'type': 'route_update',
            'routeId': route.id,
            'ambulanceId': route.ambulanceId,
            'emergencyId': route.emergencyId,
            'newStatus': newStatus.value,
          },
          priority: 'normal',
        );
      }

      log('Route update notifications sent to ${hospitalQuery.docs.length} hospital staff');
      return true;
    } catch (e) {
      log('Error sending route update notifications to hospital: $e');
      return false;
    }
  }

  // GENERAL PUSH NOTIFICATION

  /// Send general push notification to user
  Future<bool> sendPushNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
    String priority = 'normal',
  }) async {
    try {
      await _queuePushNotification(
        recipientId: userId,
        title: title,
        message: message,
        data: data ?? {},
        priority: priority,
      );

      return true;
    } catch (e) {
      log('Error sending push notification: $e');
      return false;
    }
  }

  // UTILITY METHODS

  /// Create in-app notification document
  Future<void> _createInAppNotification({
    required String recipientId,
    required String type,
    required String title,
    required String message,
    required Map<String, dynamic> data,
    String priority = 'normal',
  }) async {
    await _firestore.collection('notifications').add({
      'type': type,
      'title': title,
      'message': message,
      'recipientId': recipientId,
      'priority': priority,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'data': data,
    });
  }

  /// Queue push notification for processing by Cloud Functions
  Future<void> _queuePushNotification({
    required String recipientId,
    required String title,
    required String message,
    required Map<String, dynamic> data,
    String priority = 'normal',
  }) async {
    // Get user's FCM token
    final userDoc = await _firestore.collection('users').doc(recipientId).get();
    if (!userDoc.exists) return;

    final userData = userDoc.data() as Map<String, dynamic>;
    final fcmToken = userData['fcmToken'] as String?;

    if (fcmToken == null || fcmToken.isEmpty) {
      log('No FCM token found for user: $recipientId');
      return;
    }

    // Queue for Cloud Functions processing
    await _firestore.collection('notification_queue').add({
      'recipientId': recipientId,
      'fcmToken': fcmToken,
      'title': title,
      'message': message,
      'data': data,
      'priority': priority,
      'createdAt': FieldValue.serverTimestamp(),
      'processed': false,
      'retryCount': 0,
    });
  }

  /// Update user's FCM token
  Future<void> updateUserFCMToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        log('Updated FCM token for user: $userId');
      }
    } catch (e) {
      log('Error updating FCM token: $e');
    }
  }

  /// Get unread notifications for user
  Stream<List<NotificationModel>> getNotificationsForUser(String userId) {
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .toList());
  }

  /// Get unread notification count
  Stream<int> getUnreadNotificationCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for user
  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      log('Marked all notifications as read for user: $userId');
    } catch (e) {
      log('Error marking all notifications as read: $e');
    }
  }

  /// Clear all notifications for user
  Future<void> clearAllNotifications(String userId) async {
    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .get();

      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      log('Cleared all notifications for user: $userId');
    } catch (e) {
      log('Error clearing notifications: $e');
    }
  }

  // NOTIFICATION ACTION HANDLERS

  void _handleEmergencyAssignmentTap(Map<String, dynamic> data) {
    log('Emergency assignment tapped: ${data['emergencyId']}');
    // Navigate to driver dashboard or emergency details
    // Implementation depends on your navigation system
  }

  void _handleNewRouteTap(Map<String, dynamic> data) {
    log('New route tapped: ${data['routeId']}');
    // Navigate to police dashboard or route details
  }

  void _handleRouteUpdateTap(Map<String, dynamic> data) {
    log('Route update tapped: ${data['routeId']}');
    // Navigate to hospital dashboard or route details
  }

  void _handleRouteClearedTap(Map<String, dynamic> data) {
    log('Route cleared tapped: ${data['routeId']}');
    // Navigate to route details or hospital dashboard
  }

  void _handleRouteTimeoutTap(Map<String, dynamic> data) {
    log('Route timeout tapped: ${data['routeId']}');
    // Navigate to route details or emergency management
  }

  // HELPER METHODS

  String _getDefaultTitle(String type) {
    switch (type) {
      case 'emergency_assignment':
        return 'Emergency Assignment';
      case 'new_route':
        return 'New Emergency Route';
      case 'route_update':
        return 'Route Update';
      case 'route_cleared':
        return 'Route Cleared';
      case 'route_timeout':
        return 'Route Timeout';
      default:
        return 'Notification';
    }
  }

  String _getDefaultBody(String type) {
    switch (type) {
      case 'emergency_assignment':
        return 'You have been assigned to a new emergency';
      case 'new_route':
        return 'New ambulance route requires attention';
      case 'route_update':
        return 'Route status has been updated';
      case 'route_cleared':
        return 'Traffic has been cleared for route';
      case 'route_timeout':
        return 'Route has timed out';
      default:
        return 'You have a new notification';
    }
  }

  String _getChannelName(String channelId) {
    switch (channelId) {
      case 'emergency_channel':
        return 'Emergency Notifications';
      case 'route_channel':
        return 'Route Notifications';
      case 'general_channel':
        return 'General Notifications';
      default:
        return 'Notifications';
    }
  }

  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case 'emergency_channel':
        return 'Critical emergency alerts and assignments';
      case 'route_channel':
        return 'Ambulance route updates and traffic management';
      case 'general_channel':
        return 'General app notifications and updates';
      default:
        return 'App notifications';
    }
  }
}

/// Enhanced notification model for in-app notifications
class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String message;
  final String recipientId;
  final String priority;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic> data;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.recipientId,
    required this.priority,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    required this.data,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      recipientId: data['recipientId'] ?? '',
      priority: data['priority'] ?? 'normal',
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      data: Map<String, dynamic>.from(data['data'] ?? {}),
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Color get priorityColor {
    switch (priority) {
      case 'critical':
        return const Color.fromARGB(255, 255, 0, 0);
      case 'high':
        return const Color.fromARGB(255, 255, 165, 0);
      case 'normal':
        return const Color.fromARGB(255, 0, 123, 255);
      case 'low':
        return const Color.fromARGB(255, 108, 117, 125);
      default:
        return const Color.fromARGB(255, 108, 117, 125);
    }
  }

  IconData get typeIcon {
    switch (type) {
      case 'emergency_assignment':
        return Icons.emergency;
      case 'new_route':
        return Icons.route;
      case 'route_update':
        return Icons.update;
      case 'route_cleared':
        return Icons.check_circle;
      case 'route_timeout':
        return Icons.timer_off;
      default:
        return Icons.notifications;
    }
  }
}
