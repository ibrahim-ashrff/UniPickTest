import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../screens/main_navigation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _fcmToken;

  /// Set this from main.dart so notification taps can navigate
  static GlobalKey<NavigatorState>? navigatorKey;

  String? get fcmToken => _fcmToken;

  // Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Skip initialization on web platform
    if (kIsWeb) {
      print('⚠️ Notification service skipped on web platform');
      _initialized = true;
      return;
    }

    // Request permissions
    await _requestPermissions();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // iOS: Show notifications in foreground (banner, sound, badge, notification center)
    if (Platform.isIOS) {
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Get FCM token
    await _getFCMToken();

    // Setup message handlers
    _setupMessageHandlers();

    // Save token to Firestore
    await _saveTokenToFirestore();

    _initialized = true;
  }

  // Request notification permissions
  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    
    if (Platform.isAndroid) {
      // Android 13+ requires explicit permission
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('⚠️ User granted provisional notification permission');
      } else {
        print('❌ User declined notification permission');
      }
    } else if (Platform.isIOS) {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print('iOS notification permission: ${settings.authorizationStatus}');
    }
  }

  // Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final initialized = await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    print('📱 Local notifications initialized: $initialized');

    // Create Android notification channel with sound
    if (!kIsWeb && Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'order_updates', // id
        'Order Updates', // name
        description: 'Notifications for order status updates',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        // Use default notification sound
      );

      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(androidChannel);
        print('✅ Android notification channel created: order_updates');
      } else {
        print('⚠️ Android notification implementation not available');
      }
    }
  }

  // Get FCM token
  Future<void> _getFCMToken() async {
    _fcmToken = await _fcm.getToken();
    print('📱 FCM Token: $_fcmToken');

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      print('🔄 FCM Token refreshed: $newToken');
      _saveTokenToFirestore();
    });
  }

  // Save token to Firestore
  Future<void> _saveTokenToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _fcmToken == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'fcmToken': _fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ FCM token saved to Firestore');
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  // Setup message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages (when app is in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // Handle notification when app is opened from terminated state
    _fcm.getInitialMessage().then((message) {
      if (message != null) {
        _handleBackgroundMessage(message);
      }
    });
  }

  // Handle foreground messages (app is open)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📬 Foreground message received: ${message.messageId}');
    print('   Title: ${message.notification?.title}');
    print('   Body: ${message.notification?.body}');
    print('   Data: ${message.data}');

    // Show local notification (appears in notification center with sound)
    await _showLocalNotification(message);
  }

  // Handle notification opened (app was in background or terminated)
  void _handleBackgroundMessage(RemoteMessage message) {
    print('📬 Notification opened: ${message.messageId}');
    // Defer navigation so the app has time to build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToOrders();
    });
  }

  // Show local notification from FCM message (appears in notification center with sound)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final title = notification?.title ?? data['title'] ?? 'UniPick';
    final body = notification?.body ?? data['body'] ?? 'You have a new notification';
    final orderId = data['orderId'] ?? data['order_id'];

    const androidDetails = AndroidNotificationDetails(
      'order_updates',
      'Order Updates',
      channelDescription: 'Notifications for order status updates',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      details,
      payload: orderId,
    );
  }

  // Show local notification directly (for status changes detected in app)
  Future<void> showOrderStatusNotification({
    required String orderId,
    required String orderNumber,
    required String status,
  }) async {
    if (kIsWeb) {
      print('⚠️ Skipping local notification on web platform');
      return;
    }
    
    if (!_initialized) {
      print('⚠️ Notification service not initialized yet');
      return;
    }

    final statusMessages = {
      'preparing': 'Your order is being prepared!',
      'ready': 'Your order is ready for pickup!',
      'completed': 'Your order has been completed!',
      'cancelled': 'Your order has been cancelled.',
    };

    final title = 'Order #$orderNumber Update';
    final body = statusMessages[status.toLowerCase()] ?? 
                 'Your order status: ${status.toLowerCase()}';

    const androidDetails = AndroidNotificationDetails(
      'order_updates', // channel id
      'Order Updates', // channel name
      channelDescription: 'Notifications for order status updates',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      // Use default system notification sound
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotifications.show(
        orderId.hashCode,
        title,
        body,
        details,
        payload: orderId,
      );

      print('🔔 Notification shown: $title - $body');
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  // Handle notification tap - navigate to Orders screen
  void _onNotificationTapped(NotificationResponse response) {
    print('🔔 Notification tapped: ${response.payload}');
    _navigateToOrders();
  }

  void _navigateToOrders() {
    final context = navigatorKey?.currentContext;
    if (context == null) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigation(initialIndex: 1)),
      (route) => false,
    );
  }

  // Subscribe to order updates topic (optional)
  Future<void> subscribeToOrderUpdates() async {
    await _fcm.subscribeToTopic('order_updates');
    print('✅ Subscribed to order_updates topic');
  }

  // Unsubscribe from order updates topic
  Future<void> unsubscribeFromOrderUpdates() async {
    await _fcm.unsubscribeFromTopic('order_updates');
    print('✅ Unsubscribed from order_updates topic');
  }
}

// Top-level function for background message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📬 Background message handler: ${message.messageId}');
  // You can add additional background processing here
}
