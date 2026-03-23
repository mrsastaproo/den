import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Request Permission (iOS / Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('[Notifications] Permission granted');
      
      // 2. Subscribe to Broadcast Topic
      await _fcm.subscribeToTopic('all_users');
      print('[Notifications] Subscribed to all_users topic');
    }

    // 3. Initialize Local Notifications (for foreground alerts)
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (details) {
        // Handle notification click while app is open
        print('[Notifications] Notification clicked: ${details.payload}');
      },
    );

    // 4. Listen for Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[Notifications] Message received in foreground: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // 5. Handle Background/Terminated Click
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[Notifications] App opened via notification: ${message.notification?.title}');
    });

    _initialized = true;
    print('[Notifications] Service initialized');
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'broadcast_channel',
      'Broadcast Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformDetails,
      payload: message.data['link'], // Optional payload
    );
  }

  /// Get current FCM token (for targeted notifications in future)
  Future<String?> getToken() async => await _fcm.getToken();
}

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());
