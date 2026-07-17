import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules/cancels the single recurring "daily study reminder" — the
/// 🟢 local-notification case from the planner's Study Reminders toggle.
/// This doesn't touch Firestore or FCM; it's pure on-device scheduling,
/// re-armed every time the user flips the toggle or picks a new time.
class LocalNotificationsService {
  LocalNotificationsService._();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _dailyReminderId = 1001;

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    // Without this, tz.local silently defaults to UTC — every
    // zonedSchedule() below would then be off by the device's real UTC
    // offset (e.g. an hour late in Lagos), which reads as "never fires"
    // for anyone testing with a short window.
    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimezone.identifier));
    } catch (_) {
      // Fall back to UTC rather than crash init — worst case the
      // reminder fires at the wrong hour instead of not at all.
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // requested explicitly in main.dart
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    const channel = AndroidNotificationChannel(
      'daily_reminder',
      'Study reminders',
      description: 'Your daily "time to revise" nudge',
      importance: Importance.defaultImportance,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    final android = await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return (android ?? true) && (ios ?? true);
  }

  /// [time] is "HH:mm", 24-hour — matches UserStudySettings.reminderTime.
  static Future<void> scheduleDailyReminder(String time) async {
    await init();
    final parts = time.split(':');
    final hour = int.tryParse(parts.elementAt(0)) ?? 19;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _dailyReminderId,
      'Time to revise 📚',
      'A few focused minutes now beats a cram session later.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails('daily_reminder', 'Study reminders'),
        iOS: DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily at this time
    );
  }

  static Future<void> cancelDailyReminder() async {
    await init();
    await _plugin.cancel(_dailyReminderId);
  }
}