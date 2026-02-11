import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_store.dart';
import '../network/api_client.dart';

class FcmService {
  FcmService._();

  static const _kPushEnabledKey = 'push_enabled';
  static const int _apnsMaxRetries = 5;
  static const Duration _apnsRetryDelay = Duration(seconds: 2);
  static Timer? _apnsRetryTimer;

  static Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    print('[FCM] init start');
    await messaging.setAutoInitEnabled(true);
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    await messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    String? token;
    try {
      if (Platform.isIOS) {
        final apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null || apnsToken.isEmpty) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
      token = await messaging.getToken();
    } catch (_) {
      // APNS token may not be ready yet on iOS.
      await Future.delayed(const Duration(seconds: 2));
      try {
        token = await messaging.getToken();
      } catch (_) {
        token = null;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token ?? '');
    if (token != null && token.isNotEmpty) {
      print('[FCM] token fetched: ${token.substring(0, 8)}…');
      await _registerIfSignedIn(token);
    } else {
      print('[FCM] token empty');
      _scheduleApnsRetry();
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', newToken);
      print('[FCM] token refreshed: ${newToken.substring(0, 8)}…');
      await _registerIfSignedIn(newToken);
    });

    AuthStore.instance.isSignedIn.addListener(() async {
      if (!AuthStore.instance.isSignedIn.value) return;
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('fcm_token') ?? '';
      if (savedToken.isEmpty) return;
      await _registerIfSignedIn(savedToken);
    });
  }

  static Future<bool> isPushEnabled() async {
    if (Platform.isIOS) {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  static Future<bool> getAppPushEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_kPushEnabledKey);
    if (saved != null) return saved;
    final enabled = await isPushEnabled();
    await prefs.setBool(_kPushEnabledKey, enabled);
    return enabled;
  }

  static Future<void> setAppPushEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPushEnabledKey, enabled);
  }

  static Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      print('[FCM] iOS permission: ${settings.authorizationStatus}');
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }
    final status = await Permission.notification.request();
    print('[FCM] Android permission: $status');
    return status.isGranted;
  }

  static Future<void> deleteTokenAndExpire() async {
    print('[FCM] delete token start');
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('fcm_token') ?? '';
    if (savedToken.isNotEmpty) {
      try {
        await _expireIfSignedIn(savedToken);
      } catch (_) {
        // ignore expire errors
      }
    }
    try {
      if (Platform.isIOS) {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null || apnsToken.isEmpty) {
          print('[FCM] APNS not ready, skip deleteToken');
          await prefs.setString('fcm_token', '');
          await prefs.setBool(_kPushEnabledKey, false);
          return;
        }
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // APNS token may not be ready yet on iOS.
    }
    await prefs.setString('fcm_token', '');
    await prefs.setBool(_kPushEnabledKey, false);
    print('[FCM] delete token done');
  }

  static Future<void> refreshTokenAndRegister() async {
    print('[FCM] refresh token start');
    String? token;
    try {
      if (Platform.isIOS) {
        final apnsReady = await _waitForApnsToken();
        if (!apnsReady) {
          print('[FCM] APNS not ready, skip getToken');
          _scheduleApnsRetry();
          return;
        }
      }
      token = await FirebaseMessaging.instance.getToken();
    } catch (_) {
      // ignore token fetch errors on iOS when APNS token is not ready
      print('[FCM] getToken failed');
      _scheduleApnsRetry();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token ?? '');
    if (token != null && token.isNotEmpty) {
      print('[FCM] token refreshed: ${token.substring(0, 8)}…');
      await _registerIfSignedIn(token);
    } else {
      print('[FCM] token empty after refresh');
    }
    await prefs.setBool(_kPushEnabledKey, true);
    print('[FCM] refresh token done');
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }

  static Future<void> _registerIfSignedIn(String token) async {
    if (!AuthStore.instance.isSignedIn.value) return;
    try {
      final deviceInfo = DeviceInfoPlugin();
      String platform = 'etc';
      String deviceModel = '';
      if (Platform.isAndroid) {
        platform = 'android';
        final info = await deviceInfo.androidInfo;
        deviceModel = info.model;
      } else if (Platform.isIOS) {
        platform = 'ios';
        final info = await deviceInfo.iosInfo;
        deviceModel = info.model ?? '';
      }
      await ApiClient.registerPushToken(
        fcmToken: token,
        platform: platform,
        deviceModel: deviceModel,
      );
      print('[FCM] register token success');
    } catch (_) {
      // ignore push token register errors
      print('[FCM] register token failed');
    }
  }

  static Future<void> _expireIfSignedIn(String token) async {
    if (!AuthStore.instance.isSignedIn.value) return;
    final deviceInfo = DeviceInfoPlugin();
    String platform = 'etc';
    String deviceModel = '';
    if (Platform.isAndroid) {
      platform = 'android';
      final info = await deviceInfo.androidInfo;
      deviceModel = info.model;
    } else if (Platform.isIOS) {
      platform = 'ios';
      final info = await deviceInfo.iosInfo;
      deviceModel = info.model ?? '';
    }
    await ApiClient.expirePushToken(
      fcmToken: token,
      platform: platform,
      deviceModel: deviceModel,
    );
    print('[FCM] expire token success');
  }

  static Future<bool> _waitForApnsToken() async {
    for (var i = 0; i < _apnsMaxRetries; i += 1) {
      try {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken != null && apnsToken.isNotEmpty) {
          return true;
        }
      } catch (_) {
        // ignore and retry
      }
      await Future.delayed(_apnsRetryDelay);
    }
    return false;
  }

  static void _scheduleApnsRetry() {
    if (!Platform.isIOS) return;
    if (_apnsRetryTimer?.isActive ?? false) return;
    _apnsRetryTimer = Timer(const Duration(seconds: 5), () {
      refreshTokenAndRegister();
    });
  }
}
