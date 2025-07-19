// lib/services/notification_service.dart
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/emergency_model.dart';
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

  // =============================================================================
  // POLICE NOTIFICATIONS
  // =============================================================================

  /// Send new route notification to police officers
  Future<bool> sendRouteNotificationToPolice({
    required AmbulanceRouteModel route,
    required String type,
  }) async {
    try {
      String title;
      String message;
      String emoji;
      String priority;

      switch (type) {
        case 'new_route':
          emoji = '🚨';
          title = 'New Emergency Route';
          message =
              'Ambulance ${route.ambulanceLicensePlate} dispatched to ${route.patientLocation}. '
              'Priority: ${route.emergencyPriority.toUpperCase()}. ETA: ${route.formattedETA}';
          priority = route.isHighPriority ? 'critical' : 'high';
          break;
        case 'route_updated':
          emoji = '📍';
          title = 'Route Updated';
          message =
              'Route for Ambulance ${route.ambulanceLicensePlate} has been updated';
          priority = 'normal';
          break;
        case 'route_reactivated':
          emoji = '🔄';
          title = 'Route Reactivated';
          message =
              'Route for Ambulance ${route.ambulanceLicensePlate} has been reactivated and needs attention';
          priority = 'high';
          break;
        default:
          emoji = '📱';
          title = 'Route Notification';
          message =
              'Route notification for Ambulance ${route.ambulanceLicensePlate}';
          priority = 'normal';
      }

      // Get all active police officers
      final policeQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'police')
          .where('isActive', isEqualTo: true)
          .get();

      int notificationsSent = 0;

      for (final doc in policeQuery.docs) {
        final userId = doc.id;

        // Create in-app notification
        await _createInAppNotification(
          recipientId: userId,
          type: type,
          title: '$emoji $title',
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
            'status': route.status.value,
            'policeOfficerId': route.policeOfficerId,
            'policeOfficerName': route.policeOfficerName,
          },
          priority: priority,
        );

        // Send push notification for critical/high priority routes
        if (priority == 'critical' || priority == 'high') {
          await _queuePushNotification(
            recipientId: userId,
            title: title,
            message: message,
            data: {
              'type': type,
              'routeId': route.id,
              'ambulanceId': route.ambulanceId,
              'emergencyId': route.emergencyId,
              'priority': route.emergencyPriority,
              'status': route.status.value,
            },
            priority: priority,
          );
        }

        notificationsSent++;
      }

      log('Police notifications sent to $notificationsSent officers for route ${route.id}');
      return true;
    } catch (e) {
      log('Error sending route notifications to police: $e');
      return false;
    }
  }

  // =============================================================================
  // HOSPITAL NOTIFICATIONS
  // =============================================================================

  /// Send route status update notification to hospital staff
  Future<bool> sendRouteNotificationToHospital({
    required AmbulanceRouteModel route,
    required String type,
    required String hospitalId,
    String? policeOfficerName,
    String? completionReason,
    String? driverName,
  }) async {
    try {
      String title;
      String message;
      String emoji;
      String priority;

      switch (type) {
        case 'route_cleared':
          emoji = '✅';
          title = 'Traffic Cleared';
          message =
              'Traffic cleared for Ambulance ${route.ambulanceLicensePlate} by '
              '${policeOfficerName ?? 'Police'}. Route is now clear to proceed.';
          priority = 'high';
          break;
        case 'route_timeout':
          emoji = '⏰';
          title = 'Route Timeout';
          message =
              'Route for Ambulance ${route.ambulanceLicensePlate} marked as timeout by '
              '${policeOfficerName ?? 'Police'}. Consider alternative action.';
          priority = 'high';
          break;
        case 'route_completed':
          emoji = '🏁';
          title = 'Route Completed';
          message =
              'Ambulance ${route.ambulanceLicensePlate} has arrived at destination. '
              '${completionReason ?? 'Emergency response completed.'}';
          priority = 'high';
          break;
        case 'route_reactivated':
          emoji = '🔄';
          title = 'Route Reactivated';
          message =
              'Route for Ambulance ${route.ambulanceLicensePlate} has been reactivated';
          priority = 'normal';
          break;
        case 'driver_arrived':
          emoji = '🚑';
          title = 'Ambulance Arrived';
          message =
              'Driver ${driverName ?? 'Unknown'} has arrived at ${route.patientLocation}';
          priority = 'high';
          break;
        case 'route_delayed':
          emoji = '🚨';
          title = 'Route Delayed';
          message =
              'Route for Ambulance ${route.ambulanceLicensePlate} is experiencing delays';
          priority = 'high';
          break;
        default:
          emoji = '📍';
          title = 'Route Update';
          message = 'Route update for Ambulance ${route.ambulanceLicensePlate}';
          priority = 'normal';
      }

      // Get hospital staff
      final hospitalQuery = await _firestore
          .collection('users')
          .where('role', whereIn: ['hospital_admin', 'hospital_staff'])
          .where('roleSpecificData.hospitalId', isEqualTo: hospitalId)
          .where('isActive', isEqualTo: true)
          .get();

      int notificationsSent = 0;

      for (final doc in hospitalQuery.docs) {
        final userId = doc.id;

        // Create in-app notification
        await _createInAppNotification(
          recipientId: userId,
          type: type,
          title: '$emoji $title',
          message: message,
          data: {
            'routeId': route.id,
            'ambulanceId': route.ambulanceId,
            'emergencyId': route.emergencyId,
            'ambulanceLicensePlate': route.ambulanceLicensePlate,
            'newStatus': route.status.value,
            'policeOfficerId': route.policeOfficerId,
            'policeOfficerName': policeOfficerName,
            'patientLocation': route.patientLocation,
            'completionReason': completionReason,
            'driverName': driverName,
            'statusUpdatedAt': route.statusUpdatedAt?.millisecondsSinceEpoch,
            'clearedAt': route.clearedAt?.millisecondsSinceEpoch,
            'completedAt': route.completedAt?.millisecondsSinceEpoch,
          },
          priority: priority,
        );

        // Send push notification for critical updates
        if (priority == 'high' || priority == 'critical') {
          await _queuePushNotification(
            recipientId: userId,
            title: title,
            message: message,
            data: {
              'type': type,
              'routeId': route.id,
              'ambulanceId': route.ambulanceId,
              'emergencyId': route.emergencyId,
              'newStatus': route.status.value,
              'policeOfficerName': policeOfficerName,
              'completionReason': completionReason,
            },
            priority: priority,
          );
        }

        notificationsSent++;
      }

      log('Hospital notifications sent to $notificationsSent staff for route ${route.id}');
      return true;
    } catch (e) {
      log('Error sending route notifications to hospital: $e');
      return false;
    }
  }

  // =============================================================================
  // DRIVER NOTIFICATIONS
  // =============================================================================

  /// Send notification to specific driver
  Future<bool> sendNotificationToDriver({
    required String driverId,
    required String title,
    required String message,
    String type = 'driver_notification',
    Map<String, dynamic>? data,
    String priority = 'normal',
  }) async {
    try {
      // Create in-app notification
      await _createInAppNotification(
        recipientId: driverId,
        type: type,
        title: title,
        message: message,
        data: data ?? {},
        priority: priority,
      );

      // Queue push notification for important notifications
      if (priority == 'high' ||
          priority == 'critical' ||
          type == 'emergency_assignment') {
        await _queuePushNotification(
          recipientId: driverId,
          title: title,
          message: message,
          data: {
            'type': type,
            ...?data,
          },
          priority: priority,
        );
      }

      log('Driver notification sent to: $driverId');
      return true;
    } catch (e) {
      log('Error sending notification to driver: $e');
      return false;
    }
  }

  /// Send route completion notification to driver
  Future<bool> sendRouteCompletionToDriver({
    required String driverId,
    required AmbulanceRouteModel route,
    String? completionReason,
  }) async {
    return await sendNotificationToDriver(
      driverId: driverId,
      title: '🏁 Route Completed',
      message:
          'Route to ${route.patientLocation} completed. ${completionReason ?? 'You are now available for new assignments.'}',
      type: 'route_completed',
      data: {
        'routeId': route.id,
        'emergencyId': route.emergencyId,
        'completionReason': completionReason,
        'patientLocation': route.patientLocation,
      },
      priority: 'normal',
    );
  }

  // =============================================================================
  // CORE NOTIFICATION METHODS
  // =============================================================================

  /// Create in-app notification
  Future<bool> _createInAppNotification({
    required String recipientId,
    required String type,
    required String title,
    required String message,
    required Map<String, dynamic> data,
    required String priority,
  }) async {
    try {
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

      return true;
    } catch (e) {
      log('Error creating in-app notification: $e');
      return false;
    }
  }

  /// Queue push notification
  Future<bool> _queuePushNotification({
    required String recipientId,
    required String title,
    required String message,
    required Map<String, dynamic> data,
    required String priority,
  }) async {
    try {
      // Get user's FCM token
      final userDoc =
          await _firestore.collection('users').doc(recipientId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>;
      final fcmToken = userData['fcmToken'] as String?;

      if (fcmToken == null) {
        log('No FCM token found for user: $recipientId');
        return false;
      }

      // Send push notification
      await _messaging.send(
        Message(
          token: fcmToken,
          notification: Notification(
            title: title,
            body: message,
          ),
          data: {
            ...data,
            'priority': priority,
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          },
          android: AndroidConfig(
            priority: priority == 'critical'
                ? AndroidMessagePriority.high
                : AndroidMessagePriority.normal,
            notification: AndroidNotification(
              channelId: _getChannelIdFromType(data['type'] ?? 'general'),
              priority: priority == 'critical'
                  ? AndroidNotificationPriority.max
                  : AndroidNotificationPriority.high,
              sound: priority == 'critical' ? 'emergency_alert' : 'default',
            ),
          ),
          apns: ApnsConfig(
            payload: ApnsPayload(
              aps: Aps(
                alert: ApsAlert(
                  title: title,
                  body: message,
                ),
                badge: 1,
                sound:
                    priority == 'critical' ? 'emergency_alert.wav' : 'default',
                category: data['type'] ?? 'general',
              ),
            ),
          ),
        ),
      );

      log('Push notification queued for user: $recipientId');
      return true;
    } catch (e) {
      log('Error queuing push notification: $e');
      return false;
    }
  }

  /// Send general push notification
  Future<bool> sendPushNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
    String priority = 'normal',
  }) async {
    return await _queuePushNotification(
      recipientId: userId,
      title: title,
      message: message,
      data: data ?? {},
      priority: priority,
    );
  }

  // =============================================================================
  // NOTIFICATION MANAGEMENT
  // =============================================================================

  /// Get notifications for user
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
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
      final query = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
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
      final query = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      log('Cleared all notifications for user: $userId');
    } catch (e) {
      log('Error clearing notifications: $e');
    }
  }

  // =============================================================================
  // INITIALIZATION HELPERS
  // =============================================================================

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

    const routeChannel = AndroidNotificationChannel(
      'route_channel',
      'Route Notifications',
      description: 'Ambulance route updates and traffic management',
      importance: Importance.high,
      enableVibration: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 0, 255, 0),
    );

    const generalChannel = AndroidNotificationChannel(
      'general_channel',
      'General Notifications',
      description: 'General app notifications and updates',
      importance: Importance.defaultImportance,
      enableVibration: true,
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

  /// Set up Firebase message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('Received foreground message: ${message.messageId}');
      _handleForegroundMessage(message);
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification taps when app is terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log('Notification tapped when app was in background: ${message.messageId}');
      _handleNotificationTap(message.data);
    });
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? 'general';

    // Show local notification for foreground messages
    _showLocalNotification(
      title: message.notification?.title ?? 'Notification',
      body: message.notification?.body ?? 'You have a new notification',
      type: type,
      data: data,
    );
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final channelId = _getChannelIdFromType(type);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: type.contains('emergency') ? Importance.max : Importance.high,
      priority: type.contains('emergency') ? Priority.max : Priority.high,
      sound: type.contains('emergency')
          ? const RawResourceAndroidNotificationSound('emergency_alert')
          : null,
      enableVibration: true,
      vibrationPattern: type.contains('emergency')
          ? Int64List.fromList([0, 250, 250, 250])
          : Int64List.fromList([0, 200, 200, 200]),
      enableLights: true,
      ledColor: type.contains('emergency') ? Colors.red : Colors.blue,
      ticker: title,
      autoCancel: !type.contains('emergency'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
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
      payload: jsonEncode(data),
    );
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _handleNotificationTap(data);
      } catch (e) {
        log('Error parsing notification payload: $e');
      }
    }
  }

  /// Handle notification tap navigation
  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    switch (type) {
      case 'emergency_assignment':
        log('Emergency assignment tapped: ${data['emergencyId']}');
        // Navigate to driver dashboard or emergency details
        break;
      case 'new_route':
      case 'route_update':
      case 'route_cleared':
      case 'route_timeout':
      case 'route_completed':
        log('Route notification tapped: ${data['routeId']}');
        // Navigate to appropriate dashboard or route details
        break;
      default:
        log('General notification tapped');
        // Navigate to notifications screen
        break;
    }
  }

  // =============================================================================
  // HELPER METHODS
  // =============================================================================

  String _getChannelIdFromType(String type) {
    if (type.contains('emergency')) return 'emergency_channel';
    if (type.contains('route')) return 'route_channel';
    return 'general_channel';
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

/// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log('Background message received: ${message.messageId}');
  // Handle background message processing here
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

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'title': title,
      'message': message,
      'recipientId': recipientId,
      'priority': priority,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'data': data,
    };
  }
}
