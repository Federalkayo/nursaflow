import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'local_notifications_service.dart';

/// Top-level (required by the plugin) background handler. Firestore is
/// where the source of truth lives — the notification doc was already
/// written by createNotification() on the backend before this push was
/// sent — so this just needs to exist for the OS to show the system tray
/// notification while the app isn't running. No Firestore write here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Registers the device's FCM token against the signed-in user's doc (so
/// Cloud Functions — see functions/src/notifications.js — can target a
/// push at them) and displays a local notification for messages that
/// arrive while the app is in the foreground, since FCM alone doesn't
/// surface a system-tray banner in that case on Android.
class PushNotificationsService {
  PushNotificationsService._();
  static final _messaging = FirebaseMessaging.instance;
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    await _saveTokenIfSignedIn();
    _messaging.onTokenRefresh.listen((_) => _saveTokenIfSignedIn());

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) _saveTokenIfSignedIn();
    });

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  static Future<void> _saveTokenIfSignedIn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FCM token save failed: $e');
    }
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails('daily_reminder', 'Study reminders'),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
    );
  }
}
