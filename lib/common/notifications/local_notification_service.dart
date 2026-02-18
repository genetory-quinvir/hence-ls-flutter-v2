import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

import '../state/home_tab_controller.dart';
import 'notification_router.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'default_channel',
    'Default',
    description: 'Default notifications',
    importance: Importance.high,
  );

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (res) async {
        final payload = res.payload;
        await _handlePayload(payload);
      },
    );

    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);

    FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      _logMessage('[FCM][FG]', msg);
      HomeTabController.setUnreadNotifications(true);
      await _showLocalNotification(msg);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) async {
      _logMessage('[FCM][OPEN]', msg);
      final link = msg.data['link']?.toString();
      await NotificationRouter.routeByLink(link);
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _logMessage('[FCM][INIT]', initial);
      final link = initial.data['link']?.toString();
      await NotificationRouter.routeByLink(link);
    }
  }

  void _logMessage(String tag, RemoteMessage msg) {
    final title = msg.notification?.title ?? '';
    final body = msg.notification?.body ?? '';
    final dataKeys = msg.data.keys.toList();
    // Avoid logging full data payload; keys are enough for debugging.
    debugPrint(
      '$tag messageId=${msg.messageId ?? ''} '
      'from=${msg.from ?? ''} '
      'dataKeys=$dataKeys '
      'title=$title '
      'body=$body',
    );
  }

  Future<void> _showLocalNotification(RemoteMessage msg) async {
    final title = msg.notification?.title ?? '알림';
    final body = msg.notification?.body ?? '';
    final payload = msg.data.isNotEmpty ? jsonEncode(msg.data) : null;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _local.show(
      msg.hashCode,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> _handlePayload(String? payload) async {
    if (payload == null || payload.isEmpty) return;
    try {
      final map = jsonDecode(payload);
      if (map is Map<String, dynamic>) {
        final link = map['link']?.toString();
        await NotificationRouter.routeByLink(link);
      }
    } catch (_) {
      // ignore invalid payload
    }
  }
}
