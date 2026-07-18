import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

/// Top-level (required by the plugin) background handler. Firestore is
/// where the source of truth lives — the notification doc was already
/// written by createNotification() on the backend before this push was
/// sent — so this just needs to exist for the OS to show the system tray
/// notification while the app isn't running. No Firestore write here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Registers the device's FCM token and IANA timezone against the signed-in
/// user's doc (so Cloud Functions — see functions/src/notifications.js and
/// functions/src/reminders.js — can target a push at them, including the
/// daily/streak reminders, which need the timezone to know when "7pm" is
/// for that user) and displays a local notification for messages that
/// arrive while the app is in the foreground, since FCM alone doesn't
/// surface a system-tray banner in that case on Android.
class PushNotificationsService {
  PushNotificationsService._();
  static final _messaging = FirebaseMessaging.instance;
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // The plugin needs its own init + Android channel before _plugin.show()
    // (used below for foreground banners) will do anything. This used to
    // happen in local_notifications_service.dart, which is gone now that
    // reminders are server-driven — see functions/src/reminders.js — but
    // the plugin itself is still needed here to surface a system-tray
    // banner for foreground FCM messages, which don't get one automatically
    // on Android.
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false, // requested explicitly below
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'daily_reminder',
          'Study reminders',
          description: 'Daily study nudges and streak reminders',
          importance: Importance.defaultImportance,
        ));

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
      final timezone = await _localTimezone();
      final update = <String, dynamic>{
        if (token != null) 'fcmToken': token,
        if (timezone != null) 'timezone': timezone,
      };
      if (update.isEmpty) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(update, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FCM token/timezone save failed: $e');
    }
  }

  /// IANA zone identifier, e.g. "Africa/Lagos". Best-effort: if it can't be
  /// resolved, the daily/streak reminder just won't fire for this device
  /// until a later app open succeeds, rather than blocking token save.
  static Future<String?> _localTimezone() async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      return null;
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
