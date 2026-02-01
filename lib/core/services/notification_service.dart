import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import '../models/routine_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Callback for notification tap
  Function(String routineId)? onNotificationTap;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tzdata.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
        if (details.payload != null && onNotificationTap != null) {
          onNotificationTap!(details.payload!);
        }
      },
    );

    _initialized = true;
  }

  /// Request notification permissions (Android 13+)
  Future<bool> requestPermissions() async {
    await initialize();
    
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      return granted ?? false;
    }
    
    return true; // Assume granted for older Android versions
  }

  /// Check if notification permissions are granted
  Future<bool> checkPermissions() async {
    await initialize();
    
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      final granted = await androidImplementation.areNotificationsEnabled();
      return granted ?? false;
    }
    
    return true; // Assume granted for older Android versions
  }

  Future<void> scheduleRoutineNotification(Routine routine) async {
    if (!routine.notificationEnabled) return;

    try {
      await initialize();

      // Schedule notification for each active day
      for (final dayOfWeek in routine.repeatDays) {
        final notificationTime = _calculateNotificationTime(
          routine.startTime,
          routine.notificationMinutesBefore,
        );

        await _scheduleWeeklyNotification(
          id: '${routine.id}_$dayOfWeek'.hashCode,
          title: '⏰ ${routine.name}',
          body: 'Starting in ${routine.notificationMinutesBefore} minutes',
          dayOfWeek: dayOfWeek,
          time: notificationTime,
          payload: routine.id,
        );
      }
    } catch (e) {
      // Silently catch notification errors to prevent CRUD failures
      debugPrint('Warning: Could not schedule notifications: $e');
    }
  }

  TimeOfDay _calculateNotificationTime(String startTime, int minutesBefore) {
    final parts = startTime.split(':');
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1]);

    // Subtract minutes
    minute -= minutesBefore;
    while (minute < 0) {
      minute += 60;
      hour -= 1;
    }
    if (hour < 0) hour += 24;

    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int dayOfWeek,
    required TimeOfDay time,
    String? payload,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // Adjust to the correct day of week
    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // If the time has passed today, schedule for next week
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'routine_reminders',
          'Routine Reminders',
          channelDescription: 'Notifications for upcoming routines',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }

  Future<void> cancelRoutineNotifications(String routineId) async {
    try {
      await initialize();
      // Cancel all notifications for this routine (all days)
      for (int day = 1; day <= 7; day++) {
        await _notifications.cancel('${routineId}_$day'.hashCode);
      }
    } catch (e) {
      // Silently catch notification errors to prevent CRUD failures
      debugPrint('Warning: Could not cancel notifications: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await initialize();
      await _notifications.cancelAll();
    } catch (e) {
      debugPrint('Warning: Could not cancel all notifications: $e');
    }
  }
}
