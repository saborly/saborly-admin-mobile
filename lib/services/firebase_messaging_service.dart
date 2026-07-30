import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:Saborly_admin/models/order.dart';
import 'package:Saborly_admin/services/order_stream_service.dart';
import 'package:Saborly_admin/firebase_options.dart';
import 'package:Saborly_admin/main.dart';
import 'package:Saborly_admin/screens/order_details_screen.dart';
import 'package:Saborly_admin/services/order_provider.dart';
import 'package:provider/provider.dart';

// CRITICAL: Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📱 Background Message Received');
  print('📱 Data: ${message.data}');
  print(
      '📱 Notification: ${message.notification?.title} - ${message.notification?.body}');

  // Initialize Firebase in background isolate
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize local notifications in background isolate
  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  await localNotifications.initialize(
    const InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    ),
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
    sound: RawResourceAndroidNotificationSound('order_notification'),
  );

  final androidPlugin =
      localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(androidChannel);
  }

  final notification = message.notification;
  final data = message.data;

  // If the message already has a notification field, the FCM SDK automatically
  // displayed it — do NOT show another one. Only show for data-only messages.
  if (notification != null) {
    print('✅ Background: notification shown by FCM SDK, skipping duplicate');
    return;
  }

  if (data.isEmpty) return;

  final title = data['title'] ??
      data['notificationTitle'] ??
      '🔔 New Order ${data['orderNumber'] ?? ''}';
  final body = data['body'] ??
      data['notificationBody'] ??
      data['message'] ??
      'Order from ${data['customerName'] ?? 'Customer'} - €${data['total'] ?? '0.00'}';

  final androidDetails = AndroidNotificationDetails(
    'order_channel',
    'Order Notifications',
    channelDescription: 'Notifications for new orders',
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'New Order',
    icon: '@mipmap/ic_launcher',
    playSound: false, // Sound handled by OrderRingtoneService
    enableVibration: true,
    enableLights: true,
    color: const Color(0xFFFF6B35),
    ledColor: const Color(0xFFFF6B35),
    ledOnMs: 1000,
    ledOffMs: 500,
    styleInformation: BigTextStyleInformation(body, contentTitle: title),
  );

  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    sound: 'order_notification.wav',
  );

  await localNotifications.show(
    1001,
    title,
    body,
    NotificationDetails(android: androidDetails, iOS: iosDetails),
    payload: data['orderId']?.toString() ?? 'unknown',
  );

  print('✅ Background: data-only notification displayed');
}

class FirebaseMessagingService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static Timer? _soundTimer;

  static Future<void> initialize() async {
    // Listen for order ids forwarded from native (e.g. tapping the
    // system-tray notification built by CustomFirebaseMessagingService).
    _ringtoneChannel.setMethodCallHandler((call) async {
      if (call.method == 'openOrder') {
        _navigateToOrder(call.arguments?.toString());
      }
    });

    // Cold start: the order id may have been captured before the engine
    // was ready — fetch it explicitly.
    try {
      final initialOrderId =
          await _ringtoneChannel.invokeMethod<String>('getInitialOrderId');
      _navigateToOrder(initialOrderId);
    } catch (_) {}

    // Request permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: true,
      provisional: false,
    );

    print('📱 Notification permission status: ${settings.authorizationStatus}');

    // Initialize local notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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

    // Create notification channel for Android with custom sound
    const androidChannel = AndroidNotificationChannel(
      'order_channel',
      'Order Notifications',
      description: 'Notifications for new orders',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      sound: RawResourceAndroidNotificationSound('order_notification'),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    print('✅ Notification channel created');

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages (app in background but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Handle initial message (when app is opened from terminated state)
    _messaging.getInitialMessage().then(_handleInitialMessage);

    print('✅ Firebase Messaging initialized');
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📱 FCM Foreground Message Received!');
    print('📱 Message ID: ${message.messageId}');
    print('📱 Topic: ${message.from}');
    print('📱 Data: ${message.data}');
    print('📱 Notification Title: ${message.notification?.title}');
    print('📱 Notification Body: ${message.notification?.body}');

    final data = message.data;
    final title = message.notification?.title?.toLowerCase() ?? '';
    final body = message.notification?.body?.toLowerCase() ?? '';
    final type = data['type']?.toString().toLowerCase() ?? '';

    // Check if this is a new order notification (more lenient check)
    bool isNewOrder = type == 'new_order' ||
        type == 'neworder' ||
        title.contains('order') ||
        title.contains('nuevo pedido') ||
        body.contains('order') ||
        data['orderId'] != null;

    if (isNewOrder) {
      print('✅ Processing new order notification');

      // Play sound
      await _playOrderSound();

      // Show notification
      await showOrderNotification(message);

      // Trigger order stream update if data is available
      if (data.isNotEmpty) {
        try {
          // If type is not new_order but we have orderId, treat it as new order
          final sanitizedData = Map<String, dynamic>.from(data);
          if (sanitizedData['type'] == null && sanitizedData['orderId'] != null) {
            sanitizedData['type'] = 'new_order';
          }
          
          OrderStreamService.instance
              .addNewOrder(OrderNotification.fromJson(sanitizedData));
          print('✅ Order added to stream');
        } catch (e) {
          print('❌ Error adding order to stream: $e');
        }
      } else {
        print('⚠️ Data is empty, skipping order stream update');
      }
    } else {
      print('ℹ️ Not a new order notification, showing generic notification');
      await showOrderNotification(message);
    }
  }

  static Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    print('📱 Message opened app from background: ${message.data}');

    // Add to order stream when opened from background
    if (message.data['type'] == 'new_order') {
      try {
        OrderStreamService.instance
            .addNewOrder(OrderNotification.fromJson(message.data));
        print('✅ Order added to stream from background tap');
      } catch (e) {
        print('❌ Error adding order from background: $e');
      }
    }

    _navigateToOrder(message.data['orderId']?.toString());
  }

  static void _navigateToOrder(String? orderId) {
    if (orderId == null || orderId.isEmpty || orderId == 'unknown') return;

    // The navigator may not be attached yet right when the app launches from
    // a terminated state, so wait a tick before pushing the route.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = navigatorKey.currentState;
      if (state == null) return;

      // Notification taps no longer flow through FirebaseMessaging's
      // onMessageOpenedApp/getInitialMessage (we now send data-only
      // messages so our own code controls display). That used to be what
      // pushed the new order into OrderProvider, so the dashboard list
      // would be stale until a manual refresh. Refresh it here instead.
      final context = navigatorKey.currentContext;
      if (context != null) {
        context.read<OrderProvider>().loadOrders();
      }

      state.push(
        MaterialPageRoute(
          builder: (context) => OrderDetailsScreen(orderId: orderId),
        ),
      );
    });
  }

  static Future<void> _handleInitialMessage(RemoteMessage? message) async {
    if (message != null) {
      print(
          '📱 Initial message (app opened from terminated state): ${message.data}');

      // Add to order stream when opened from terminated state
      if (message.data['type'] == 'new_order') {
        try {
          OrderStreamService.instance
              .addNewOrder(OrderNotification.fromJson(message.data));
          print('✅ Order added to stream from terminated state');
        } catch (e) {
          print('❌ Error adding order from terminated state: $e');
        }
      }

      await _handleMessageOpenedApp(message);
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    print('📱 Notification tapped: ${response.payload}');
    _navigateToOrder(response.payload);
  }

  static Future<void> showOrderNotification(RemoteMessage message) async {
    final data = message.data;

    // Get title and body from notification or data
    final title = message.notification?.title ??
        '🔔 New Order ${data['orderNumber'] ?? ''}';
    final body = message.notification?.body ??
        'Order from ${data['customerName'] ?? 'Customer'} - €${data['total'] ?? '0.00'}';

    final androidDetails = AndroidNotificationDetails(
      'order_channel',
      'Order Notifications',
      channelDescription: 'Notifications for new orders',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'New Order',
      icon: '@mipmap/ic_launcher',
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('order_notification'),
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
      DateTime.now().millisecondsSinceEpoch % 1000000,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: data['orderId']?.toString() ?? 'unknown',
    );

    print('✅ Notification displayed');
  }

  static const _ringtoneChannel = MethodChannel('com.saborly.saborly_admin/ringtone');

  static Future<void> _playOrderSound() async {
    _soundTimer?.cancel();
    _soundTimer = Timer(const Duration(seconds: 20), stopOrderSound);

    // Use native loop mode so the clip repeats continuously without
    // depending on the onPlayerComplete event firing each time.
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('sounds/order_notification.mp3'));
    } catch (e) {
      print('❌ Error playing sound: $e');
    }
  }

  static Future<void> stopOrderSound() async {
    _soundTimer?.cancel();
    _soundTimer = null;

    // Stop Flutter audio player (foreground)
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.release);
    } catch (_) {}

    // Stop Android foreground ringtone service (background/killed app)
    try {
      await _ringtoneChannel.invokeMethod('stopRingtone');
    } catch (_) {}
  }

  static Future<String?> getToken() async {
    return await _messaging.getToken();
  }
}
