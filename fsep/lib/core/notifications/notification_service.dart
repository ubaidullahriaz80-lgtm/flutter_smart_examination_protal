import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/learning_gaps/views/learning_gaps_view.dart';
import 'local_notification_service.dart';

/// Notification Service handling FCM token management and message routing.
class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    await LocalNotificationService.initialize();
    await _fcm.requestPermission();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('FCM: Received foreground message: ${message.notification?.title}');
      }
      
      final notification = message.notification;
      if (notification != null) {
        LocalNotificationService.showNotification(
          id: notification.hashCode,
          title: notification.title ?? '',
          body: notification.body ?? '',
          payload: jsonEncode(message.data),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessageNavigation(message.data);
    });

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageNavigation(initialMessage.data);
    }
  }

  static void _handleMessageNavigation(Map<String, dynamic> data) {
    final type = data['type'];
    final sessionIdStr = data['session_id'] ?? data['report_id'];
    
    if (type == 'exam_result' || type == 'EVALUATION_COMPLETE') {
      final sessionId = int.tryParse(sessionIdStr.toString());
      if (sessionId != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => LearningGapsView(sessionId: sessionId),
          ),
        );
      }
    } else if (type == 'exam_reminder') {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/dashboard', 
        (route) => false,
      );
    }
  }

  static Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM: Failed to get token: $e');
      }
      return null;
    }
  }

  static Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('FCM: Handling background message: ${message.messageId}');
  }
}
