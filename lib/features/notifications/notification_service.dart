import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Payload that tells the router to open the check-in rather than Today.
const checkinPayload = 'checkin';

const _morningId = 1001;
const _eveningId = 1002;
const _morningKey = 'notif_morning';
const _eveningKey = 'notif_evening';
const _enabledKey = 'notif_enabled';

/// A time of day stored as `HH:mm`.
class Reminder {
  const Reminder(this.hour, this.minute);

  final int hour;
  final int minute;

  String get formatted =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static Reminder parse(String? value, Reminder fallback) {
    final parts = (value ?? '').split(':');
    if (parts.length != 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
    return Reminder(hour, minute);
  }
}

const defaultMorning = Reminder(8, 0);
const defaultEvening = Reminder(20, 0);

/// Two local daily notifications. No server is involved in v1 — the phone
/// schedules them, so they fire offline.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Set when the app was launched by tapping a notification, so the router
  /// can jump to the check-in on a cold start.
  static String? launchPayload;

  /// Emits when a notification is tapped while the app is already running.
  static final ValueNotifier<String?> tapped = ValueNotifier<String?>(null);

  /// The notifications plugin has no web implementation, so on web every
  /// entry point below is a no-op and the app still runs. Reminders are a
  /// phone feature; the web build exists to be demoed.
  static bool get supported => !kIsWeb;

  Future<void> initialize() async {
    if (!supported) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        tapped.value = response.payload;
      },
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      launchPayload = launch!.notificationResponse?.payload;
    }
  }

  Future<bool> requestPermissions() async {
    if (!supported) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidGranted = await android?.requestNotificationsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await ios?.requestPermissions(alert: true, badge: true, sound: true);

    return androidGranted ?? iosGranted ?? false;
  }

  Future<void> scheduleDaily({
    required Reminder morning,
    required Reminder evening,
  }) async {
    if (!supported) return;
    await cancelAll();

    await _scheduleOne(
      id: _morningId,
      reminder: morning,
      title: 'Morning check-in',
      body: 'Did you have your usual breakfast?',
    );
    await _scheduleOne(
      id: _eveningId,
      reminder: evening,
      title: 'How did today go?',
      body: 'Swipe through your day — it takes 20 seconds.',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_morningKey, morning.formatted);
    await prefs.setString(_eveningKey, evening.formatted);
    await prefs.setBool(_enabledKey, true);
  }

  Future<void> _scheduleOne({
    required int id,
    required Reminder reminder,
    required String title,
    required String body,
  }) =>
      _plugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOf(reminder),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'checkin',
            'Daily check-in',
            channelDescription: 'Reminders to log your meals',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        // Repeat at the same clock time every day, across DST changes.
        matchDateTimeComponents: DateTimeComponents.time,
        payload: checkinPayload,
      );

  tz.TZDateTime _nextInstanceOf(Reminder reminder) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      reminder.hour,
      reminder.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> cancelAll() async {
    if (supported) {
      await _plugin.cancel(_morningId);
      await _plugin.cancel(_eveningId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  Future<({Reminder morning, Reminder evening, bool enabled})> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      morning: Reminder.parse(prefs.getString(_morningKey), defaultMorning),
      evening: Reminder.parse(prefs.getString(_eveningKey), defaultEvening),
      enabled: prefs.getBool(_enabledKey) ?? false,
    );
  }

  /// Suggests reminder times from the quiz: an hour after they usually train,
  /// and an hour after their last meal.
  static ({Reminder morning, Reminder evening}) suggestFrom({
    String? gymTime,
    List<String> mealTimes = const [],
  }) {
    final gym = gymTime == null ? null : Reminder.parse(gymTime, defaultMorning);
    final lastMeal = mealTimes.isEmpty
        ? null
        : Reminder.parse(mealTimes.last, defaultEvening);

    return (
      morning: gym == null ? defaultMorning : _addHour(gym),
      evening: lastMeal == null ? defaultEvening : _addHour(lastMeal),
    );
  }

  static Reminder _addHour(Reminder reminder) =>
      Reminder((reminder.hour + 1) % 24, reminder.minute);
}
