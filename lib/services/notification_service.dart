// lib/services/notification_service.dart - Modern FCM V1 Implementation
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../models/emergency_model.dart';
import '../models/notification_model.dart';
import '../models/route_model.dart';
import '../services/notification_settings_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationSettingsService _settingsService =
      NotificationSettingsService();

  bool _isInitialized = false;

  // Your project details from Firebase
  static const String _projectId =
      'ambulance-app-b272f'; // From your firebase_options.dart
  static const String _senderId = '137233063793'; // From the screenshot

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
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channels for Android
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

  // =============================================================================
  // CORE NOTIFICATION METHODS - SIMPLIFIED APPROACH
  // =============================================================================

  /// Send notification using Cloud Functions (Recommended approach)
  Future<bool> sendNotificationViaCloudFunction({
    required String recipientId,
    required String title,
    required String message,
    required Map<String, dynamic> data,
    required String priority,
  }) async {
    try {
      // Call your Cloud Function to send the notification
      // This is the recommended way for production apps
      final functionUrl =
          'https://us-central1-$_projectId.cloudfunctions.net/sendNotification';

      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'recipientId': recipientId,
          'title': title,
          'message': message,
          'data': data,
          'priority': priority,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      log('Error sending notification via Cloud Function: $e');

      // Fallback to direct FCM token approach
      return await _sendDirectNotification(
        recipientId: recipientId,
        title: title,
        message: message,
        data: data,
        priority: priority,
      );
    }
  }

  /// Direct notification sending (fallback method)
  Future<bool> _sendDirectNotification({
    required String recipientId,
    required String title,
    required String message,
    required Map<String, dynamic> data,
    required String priority,
  }) async {
    try {
      // Get user's FCM token from Firestore
      final userDoc =
          await _firestore.collection('users').doc(recipientId).get();
      if (!userDoc.exists) {
        log('User document not found: $recipientId');
        return false;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final fcmToken = userData['fcmToken'] as String?;

      if (fcmToken == null) {
        log('No FCM token found for user: $recipientId');
        return false;
      }

      // For now, create the in-app notification and show local notification
      // The actual push notification would need Cloud Functions for V1 API
      await _createInAppNotification(
        recipientId: recipientId,
        type: data['type'] ?? 'general',
        title: title,
        message: message,
        data: data,
        priority: priority,
      );

      // Show local notification if app is in foreground
      await _showLocalNotification(
        title: title,
        body: message,
        type: data['type'] ?? 'general',
        data: data,
      );

      return true;
    } catch (e) {
      log('Error sending direct notification: $e');
      return false;
    }
  }

  /// Create in-app notification in Firestore
  Future<String> _createInAppNotification({
    required String recipientId,
    required String type,
    required String title,
    required String message,
    required Map<String, dynamic> data,
    required String priority,
  }) async {
    try {
      final notification = NotificationModel(
        id: '', // Will be set by Firestore
        userId: recipientId,
        type: type,
        priority: priority,
        title: title,
        message: message,
        data: data,
        isRead: false,
        createdAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('notifications')
          .add(notification.toFirestore());

      log('In-app notification created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      log('Error creating in-app notification: $e');
      throw Exception('Failed to create notification: $e');
    }
  }

  /// Send push notification with fallback to in-app notification
  Future<bool> sendPushNotification({
    required String userId,
    required String title,
    required String message,
    required Map<String, dynamic> data,
    String priority = 'normal',
    bool ignoreSettings = false,
  }) async {
    try {
      final notificationType = data['type'] ?? 'general';

      // Check if user wants to receive this type of notification
      if (!ignoreSettings) {
        final shouldReceive = await _settingsService.shouldReceiveNotification(
            userId, notificationType);
        if (!shouldReceive) {
          log('Notification blocked by user settings: $notificationType for user $userId');
          return false;
        }
      }

      // Get user's notification preferences for sound/vibration
      final preferences =
          await _settingsService.getNotificationPreferences(userId);

      // Update data with user preferences
      final enhancedData = {
        ...data,
        'soundEnabled': preferences.soundEnabled,
        'vibrationEnabled': preferences.vibrationEnabled,
        'notificationTone': preferences.notificationTone,
      };

      // Try cloud function first
      bool pushSuccess = await sendNotificationViaCloudFunction(
        recipientId: userId,
        title: title,
        message: message,
        data: enhancedData,
        priority: priority,
      );

      // Always create in-app notification
      await _createInAppNotification(
        recipientId: userId,
        type: notificationType,
        title: title,
        message: message,
        data: enhancedData,
        priority: priority,
      );

      // Show local notification if app is in foreground
      if (_isAppInForeground) {
        await _showLocalNotificationWithPreferences(
          title: title,
          body: message,
          type: notificationType,
          preferences: preferences,
          data: enhancedData,
        );
      }

      return pushSuccess;
    } catch (e) {
      log('Error in sendPushNotification: $e');
      return false;
    }
  }

  Future<void> _showLocalNotificationWithPreferences({
    required String title,
    required String body,
    required String type,
    required NotificationPreferences preferences,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Determine the channel based on type
      String channelId;
      switch (type) {
        case 'emergency_assignment':
          channelId = 'emergency_channel';
          break;
        case 'new_route':
        case 'route_update':
        case 'route_cleared':
        case 'route_timeout':
          channelId = 'route_channel';
          break;
        default:
          channelId = 'general_channel';
      }

      // Configure sound and vibration based on user preferences
      final androidDetails = AndroidNotificationDetails(
        channelId,
        _getChannelName(channelId),
        channelDescription: _getChannelDescription(channelId),
        importance: type == 'emergency_assignment'
            ? Importance.max
            : Importance.defaultImportance,
        priority: type == 'emergency_assignment'
            ? Priority.max
            : Priority.defaultPriority,
        enableVibration: preferences.vibrationEnabled,
        playSound: preferences.soundEnabled,
        sound: preferences.soundEnabled &&
                preferences.notificationTone != 'default'
            ? RawResourceAndroidNotificationSound(preferences.notificationTone)
            : null,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        details,
        payload: data != null ? json.encode(data) : null,
      );

      log('Local notification shown with user preferences');
    } catch (e) {
      log('Error showing local notification: $e');
    }
  }

  /// Generic method to send notification to a user
  Future<bool> sendNotificationToUser({
    required String userId,
    required String type,
    required String title,
    required String message,
    required Map<String, dynamic> data,
    String priority = 'normal',
  }) async {
    return await sendNotificationViaCloudFunction(
      recipientId: userId,
      title: title,
      message: message,
      data: {'type': type, ...data},
      priority: priority,
    );
  }

  // =============================================================================
  // EMERGENCY & ROUTE NOTIFICATIONS
  // =============================================================================

  /// Send emergency assignment notification to driver
  Future<bool> sendEmergencyAssignmentToDriver({
    required String driverId,
    required EmergencyModel emergency,
    required AmbulanceRouteModel route,
  }) async {
    return await sendNotificationToUser(
      userId: driverId,
      type: 'emergency_assignment',
      title: '🚨 EMERGENCY DISPATCH',
      message:
          'You have been assigned to emergency at ${emergency.patientAddressString}. '
          'Priority: ${emergency.priority.displayName}. Please respond immediately.',
      data: {
        'emergencyId': emergency.id,
        'routeId': route.id,
        'location': emergency.patientAddressString,
        'priority': emergency.priority,
        'coordinates': {
          'latitude': emergency.patientLat,
          'longitude': emergency.patientLng,
        },
      },
      priority: emergency.priority == 'critical' ? 'critical' : 'high',
    );
  }

  /// Send route notification to police officers
  Future<bool> sendRouteNotificationToPolice({
    required AmbulanceRouteModel route,
    required String type,
  }) async {
    try {
      String title;
      String message;
      String priority;

      switch (type) {
        case 'new_route':
          title = '🚨 New Emergency Route';
          message =
              'Ambulance ${route.ambulanceLicensePlate} dispatched to ${route.patientLocation}. '
              'Priority: ${route.emergencyPriority.toUpperCase()}. ETA: ${route.formattedETA}';
          priority = route.isHighPriority ? 'critical' : 'high';
          break;
        case 'route_cleared':
          title = '✅ Route Cleared';
          message =
              'Emergency route for ambulance ${route.ambulanceLicensePlate} has been cleared. '
              'Thank you for your assistance.';
          priority = 'normal';
          break;
        default:
          title = '📍 Route Update';
          message = 'Route update for ambulance ${route.ambulanceLicensePlate}';
          priority = 'normal';
      }

      // Get all police officers in the area
      final policeQuery = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'police')
          .where('isOnDuty', isEqualTo: true)
          .get();

      bool allSuccess = true;
      for (final doc in policeQuery.docs) {
        final success = await sendNotificationToUser(
          userId: doc.id,
          type: type,
          title: title,
          message: message,
          data: {
            'routeId': route.id,
            'emergencyId': route.emergencyId,
            'ambulanceLicensePlate': route.ambulanceLicensePlate,
            'patientLocation': route.patientLocation,
            'priority': route.emergencyPriority,
          },
          priority: priority,
        );

        if (!success) allSuccess = false;
      }

      return allSuccess;
    } catch (e) {
      log('Error sending route notification to police: $e');
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
        case 'assignment_cancelled':
          emoji = '❌';
          title = 'Assignment Cancelled';
          message =
              'Assignment for Ambulance ${route.ambulanceLicensePlate} has been cancelled. '
              '${completionReason ?? 'No reason provided.'}';
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

  // Add these methods to your existing NotificationService class
// (lib/services/notification_service.dart)

  /// Send notification to all hospital staff
  Future<bool> sendNotificationToHospital({
    required String hospitalId,
    required String type,
    required String title,
    required String message,
    required Map<String, dynamic> data,
    String priority = 'normal',
  }) async {
    try {
      log('Sending notification to hospital $hospitalId: $title');

      // Get all hospital staff for this hospital
      final hospitalStaffQuery = await _firestore
          .collection('users')
          .where('role', whereIn: ['hospital_admin', 'hospital_staff'])
          .where('roleSpecificData.hospitalId', isEqualTo: hospitalId)
          .where('isActive', isEqualTo: true)
          .get();

      if (hospitalStaffQuery.docs.isEmpty) {
        log('No hospital staff found for hospital $hospitalId');
        return false;
      }

      bool allSuccess = true;
      int notificationsSent = 0;

      // Send notification to each hospital staff member
      for (final doc in hospitalStaffQuery.docs) {
        final userId = doc.id;

        final success = await sendNotificationToUser(
          userId: userId,
          type: type,
          title: title,
          message: message,
          data: {
            'hospitalId': hospitalId,
            ...data,
          },
          priority: priority,
        );

        if (success) {
          notificationsSent++;
        } else {
          allSuccess = false;
        }
      }

      log('Sent notifications to $notificationsSent hospital staff members');
      return allSuccess;
    } catch (e) {
      log('Error sending notification to hospital: $e');
      return false;
    }
  }

  /// Send emergency notification to hospital (alias for backward compatibility)
  /// Send emergency notification to hospital staff
  Future<void> sendEmergencyNotificationToHospital({
    required String hospitalId,
    required String emergencyId,
    required String priority,
    required String description,
    required String location,
  }) async {
    try {
      // Get hospital staff users
      final hospitalStaff = await _firestore
          .collection('users')
          .where('hospitalId', isEqualTo: hospitalId)
          .where('role', whereIn: ['doctor', 'nurse', 'admin']).get();

      for (final userDoc in hospitalStaff.docs) {
        final userId = userDoc.id;

        // Emergency notifications ignore user settings for critical priority
        final ignoreSettings = priority == 'critical';

        await sendPushNotification(
          userId: userId,
          title: 'Emergency Assignment',
          message: 'New $priority priority emergency: $description',
          data: {
            'type': 'emergency_assignment',
            'emergencyId': emergencyId,
            'hospitalId': hospitalId,
            'priority': priority,
            'location': location,
            'timestamp': DateTime.now().toIso8601String(),
          },
          priority: priority,
          ignoreSettings: ignoreSettings,
        );
      }

      log('Emergency notifications sent to hospital $hospitalId staff');
    } catch (e) {
      log('Error sending emergency notifications: $e');
    }
  }

  Future<void> sendRouteNotificationToDriver({
    required String driverId,
    required String routeId,
    required String type, // 'new_route', 'route_update', etc.
    required String message,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final data = {
        'type': type,
        'routeId': routeId,
        'driverId': driverId,
        'timestamp': DateTime.now().toIso8601String(),
        ...?additionalData,
      };

      await sendPushNotification(
        userId: driverId,
        title: _getRouteNotificationTitle(type),
        message: message,
        data: data,
        priority: type == 'new_route' ? 'high' : 'normal',
        ignoreSettings: false, // Route notifications respect user settings
      );

      log('Route notification sent to driver $driverId');
    } catch (e) {
      log('Error sending route notification: $e');
    }
  }

  Future<void> sendPoliceNotification({
    required String officerId,
    required String routeId,
    required String type,
    required String message,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final data = {
        'type': type,
        'routeId': routeId,
        'officerId': officerId,
        'timestamp': DateTime.now().toIso8601String(),
        ...?additionalData,
      };

      await sendPushNotification(
        userId: officerId,
        title: _getPoliceNotificationTitle(type),
        message: message,
        data: data,
        priority: 'high',
      );

      log('Police notification sent to officer $officerId');
    } catch (e) {
      log('Error sending police notification: $e');
    }
  }

  /// Send route completion notification to driver
  Future<bool> sendRouteCompletionToDriver({
    required String driverId,
    required AmbulanceRouteModel route,
    required String completionReason,
  }) async {
    return await sendNotificationToUser(
      userId: driverId,
      type: 'route_completed',
      title: '✅ Route Completed',
      message: 'Emergency route completed. $completionReason',
      data: {
        'routeId': route.id,
        'emergencyId': route.emergencyId,
        'completionReason': completionReason,
        'ambulanceLicensePlate': route.ambulanceLicensePlate,
      },
      priority: 'normal',
    );
  }

  /// Send notification to a specific driver (used in AmbulanceAssignmentService)
  Future<void> sendNotificationToDriver({
    required String driverId,
    required String title,
    required String message,
    required Map<String, dynamic> data,
  }) async {
    try {
      log('Sending notification to driver $driverId: $title - $message');

      // First create the in-app notification
      await _createInAppNotification(
        recipientId: driverId,
        type: data['type'] ?? 'emergency_assignment',
        title: title,
        message: message,
        data: data,
        priority: data['priority'] ?? 'high',
      );

      // Then send the push notification
      final success = await sendNotificationViaCloudFunction(
        recipientId: driverId,
        title: title,
        message: message,
        data: data,
        priority: data['priority'] ?? 'high',
      );

      if (!success) {
        log('Fallback to direct notification for driver $driverId');
        await _sendDirectNotification(
          recipientId: driverId,
          title: title,
          message: message,
          data: data,
          priority: data['priority'] ?? 'high',
        );
      }

      // Also show local notification
      await _showLocalNotification(
        title: title,
        body: message,
        type: data['type'] ?? 'emergency_assignment',
        data: data,
      );

      log('Notification sent successfully to driver $driverId');
    } catch (e) {
      log('Error sending notification to driver: $e');
      throw Exception('Failed to send notification to driver: $e');
    }
  }

  /// Queue push notification for later delivery
  Future<void> _queuePushNotification({
    required String recipientId,
    required String title,
    required String message,
    required Map<String, dynamic> data,
    required String priority,
  }) async {
    try {
      // For now, we'll just create the notification in Firestore
      // In production, you'd want to use Cloud Functions for actual push notifications
      await _firestore.collection('notification_queue').add({
        'recipientId': recipientId,
        'title': title,
        'message': message,
        'data': data,
        'priority': priority,
        'status': 'queued',
        'createdAt': FieldValue.serverTimestamp(),
        'scheduledFor': FieldValue.serverTimestamp(),
      });

      log('Push notification queued for user: $recipientId');
    } catch (e) {
      log('Error queuing push notification: $e');
    }
  }

  // =============================================================================
  // FCM TOKEN MANAGEMENT
  // =============================================================================

  /// Get FCM token
  Future<String?> getFCMToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      log('Error getting FCM token: $e');
      return null;
    }
  }

  /// Update user's FCM token in Firestore
  Future<void> updateUserFCMToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        log('FCM token updated for user: $userId');
      }
    } catch (e) {
      log('Error updating FCM token: $e');
      throw Exception('Failed to update FCM token: $e');
    }
  }

  // =============================================================================
  // NOTIFICATION HANDLERS
  // =============================================================================

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
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: type.contains('emergency')
          ? const Color.fromARGB(255, 255, 0, 0)
          : const Color.fromARGB(255, 0, 255, 0),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: json.encode(data),
    );
  }

  Stream<List<NotificationModel>> getNotificationsForUser(String userId) {
    try {
      return _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      log('Error getting notifications for user $userId: $e');
      return Stream.value(<NotificationModel>[]);
    }
  }

  Stream<int> getUnreadNotificationCount(String userId) {
    try {
      return _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    } catch (e) {
      log('Error getting unread count for user $userId: $e');
      return Stream.value(0);
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      log('Notification $notificationId marked as read');
    } catch (e) {
      log('Error marking notification as read: $e');
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final unreadNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      log('All notifications marked as read for user $userId');
    } catch (e) {
      log('Error marking all notifications as read: $e');
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  Future<void> clearAllNotifications(String userId) async {
    try {
      final batch = _firestore.batch();
      final userNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in userNotifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      log('All notifications cleared for user $userId');
    } catch (e) {
      log('Error clearing all notifications: $e');
      throw Exception('Failed to clear all notifications: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!) as Map<String, dynamic>;
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
        break;
      case 'new_route':
      case 'route_update':
      case 'route_cleared':
        log('Route notification tapped: ${data['routeId']}');
        break;
      default:
        log('General notification tapped');
        break;
    }
  }

  // =============================================================================
  // HELPER METHODS
  // =============================================================================

  String _getRouteNotificationTitle(String type) {
    switch (type) {
      case 'new_route':
        return 'New Route Assignment';
      case 'route_update':
        return 'Route Update';
      case 'route_cleared':
        return 'Route Cleared';
      case 'route_timeout':
        return 'Route Timeout';
      default:
        return 'Route Notification';
    }
  }

  String _getPoliceNotificationTitle(String type) {
    switch (type) {
      case 'route_clearance_request':
        return 'Route Clearance Request';
      case 'emergency_assistance':
        return 'Emergency Assistance Required';
      default:
        return 'Police Notification';
    }
  }

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

  bool _isAppInForeground = true;
}

/// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log('Background message received: ${message.messageId}');
}
