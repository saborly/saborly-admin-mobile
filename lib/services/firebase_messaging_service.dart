import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:Saborly_admin/models/order.dart';
import 'package:Saborly_admin/services/order_stream_service.dart';

class FirebaseMessagingService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final AudioPlayer _audioPlayer = AudioPlayer();
  
  static Future<void> initialize() async {
    // Request permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: true,
      provisional: false,
    );

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'order_channel',
      'Order Notifications',
      description: 'Notifications for new orders',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background messages
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    // Handle initial message (when app is opened from terminated state)
    _messaging.getInitialMessage().then(_handleInitialMessage);
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📱 Foreground Message Received');
    print('📱 Data: ${message.data}');
    print('📱 Notification Title: ${message.notification?.title}');
    print('📱 Notification Body: ${message.notification?.body}');
    
    final data = message.data;
    
    // Check if this is a new order notification
    // Support both data-only and notification+data formats
    bool isNewOrder = data['type'] == 'new_order' || 
                      message.notification?.title?.contains('Order') == true;
    
    if (isNewOrder) {
      print('✅ Processing new order notification');
      
      // Play sound
      await _playOrderSound();
      
      // Show notification
      await showOrderNotification(message);
      
      // Trigger order stream update if data is available
      if (data.isNotEmpty && data['type'] == 'new_order') {
        try {
          OrderStreamService.instance.addNewOrder(
            OrderNotification.fromJson(data)
          );
          print('✅ Order added to stream');
        } catch (e) {
          print('❌ Error adding order to stream: $e');
        }
      } else {
        print('⚠️ Data is empty, skipping order stream update');
        print('⚠️ BACKEND ISSUE: Data field is missing in notification payload');
      }
    } else {
      print('ℹ️ Not a new order notification, showing generic notification');
      await showOrderNotification(message);
    }
  }

  static Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    print('📱 Message opened app: ${message.data}');
    // Navigate to order details
    if (message.data['orderId'] != null) {
      // NavigationService.navigateToOrder(message.data['orderId']);
    }
  }

  static Future<void> _handleInitialMessage(RemoteMessage? message) async {
    if (message != null) {
      print('📱 Initial message: ${message.data}');
      await _handleMessageOpenedApp(message);
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    print('📱 Notification tapped: ${response.payload}');
    // Navigate to order details
  }

  static Future<void> showOrderNotification(RemoteMessage message) async {
    final data = message.data;
    
    // Get title and body from notification or data
    final title = message.notification?.title ?? 
                  '🔔 New Order ${data['orderNumber'] ?? ''}';
    final body = message.notification?.body ?? 
                 'Order from ${data['customerName'] ?? 'Customer'} - \$${data['total'] ?? '0.00'}';
    
    final androidDetails = AndroidNotificationDetails(
      'order_channel',
      'Order Notifications',
      channelDescription: 'Notifications for new orders',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'New Order',
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      enableLights: true,
      color: const Color(0xFFFF6B35),
      ledColor: const Color(0xFFFF6B35),
      ledOnMs: 1000,
      ledOffMs: 500,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'order_notification.wav',
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: data['orderId'] ?? 'unknown',
    );
    
    print('✅ Notification displayed');
  }

  static Future<void> _playOrderSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/order_notification.mp3'));
      await _audioPlayer.setVolume(1.0);
      print('✅ Order sound played');
    } catch (e) {
      print('❌ Error playing sound: $e');
    }
  }

  static Future<String?> getToken() async {
    return await _messaging.getToken();
  }
}