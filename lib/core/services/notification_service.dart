import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../database/isar_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const _morningReminderId = 1001;
  static const _inactivityReminderId = 1002;

  /// Initialize notifications and set up channels
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

      const androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification tapped: ${response.payload}');
        },
      );

      _isInitialized = true;
      await updateSchedule();
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Explicitly request notification permission when user taps Allow
  Future<bool> requestPermission() async {
    try {
      final androidPlatform =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        final granted = await androidPlatform.requestNotificationsPermission();
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('NotificationService requestPermission error: $e');
    }
    return false;
  }

  /// Check rules and update scheduled reminders
  Future<void> updateSchedule() async {
    if (!_isInitialized) return;

    try {
      final now = DateTime.now();
      final todayMeals = await isarService.getMealsForDate(now);

      // ─────────────────────────────────────────────────────────────
      // Rule 1 & 3: Morning Reminder (11:00 AM)
      // ─────────────────────────────────────────────────────────────
      if (todayMeals.isEmpty) {
        final elevenAM = DateTime(now.year, now.month, now.day, 11, 0);
        if (now.isBefore(elevenAM)) {
          await _scheduleNotification(
            id: _morningReminderId,
            title: 'Morning Meal Check-in ☀️',
            body:
                "You haven't logged any meal yet today. Tap to record your breakfast!",
            scheduledTime: elevenAM,
          );
        } else {
          // It is past 11 AM today and 0 meals logged
          await _notifications.cancel(_morningReminderId);
        }
      } else {
        // User logged at least one meal today — cancel morning reminder
        await _notifications.cancel(_morningReminderId);
      }

      // ─────────────────────────────────────────────────────────────
      // Rule 2 & 3: 5-Hour Inactivity Reminder + Quiet Hours (11 PM - 8 AM)
      // ─────────────────────────────────────────────────────────────
      final allMeals = await isarService.getMealsInDateRange(
        now.subtract(const Duration(days: 7)),
        now,
      );

      if (allMeals.isNotEmpty) {
        allMeals.sort((a, b) => b.date.compareTo(a.date));
        final lastMeal = allMeals.first;
        final next5Hours = lastMeal.date.add(const Duration(hours: 5));

        if (next5Hours.isAfter(now)) {
          // Check Quiet Hours: 11 PM (23:00) to 8 AM (08:00)
          final reminderTime = _adjustForQuietHours(next5Hours);

          await _scheduleNotification(
            id: _inactivityReminderId,
            title: 'Meal Check-in 🍽️',
            body:
                "It's been 5 hours since your last logged meal. Don't forget to track what you ate!",
            scheduledTime: reminderTime,
          );
        } else {
          await _notifications.cancel(_inactivityReminderId);
        }
      }
    } catch (e) {
      debugPrint('NotificationService updateSchedule error: $e');
    }
  }

  /// Adjusts time if it falls in quiet hours (11:00 PM - 8:00 AM)
  DateTime _adjustForQuietHours(DateTime target) {
    if (target.hour >= 23) {
      // If 11 PM or later, postpone to 8:00 AM next morning
      final nextDay = target.add(const Duration(days: 1));
      return DateTime(nextDay.year, nextDay.month, nextDay.day, 8, 0);
    } else if (target.hour < 8) {
      // If before 8 AM, postpone to 8:00 AM same day
      return DateTime(target.year, target.month, target.day, 8, 0);
    }
    return target;
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    // Double check quiet hours range: 23:00 to 08:00
    if (scheduledTime.hour >= 23 || scheduledTime.hour < 8) return;

    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'bite_reminders',
      'Bite Meal Reminders',
      channelDescription: 'Notifications for morning and 6-hour meal tracking',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
