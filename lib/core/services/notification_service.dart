// Schedules local reminders with stable identifiers, categories, and time zones.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

enum ReminderCategory {
  classes,
  assignments,
  examinations,
  studySessions,
  habits,
  focus,
  dailyPlanning,
}

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _payloads = StreamController.broadcast();
  bool _initialized = false;

  Stream<String> get payloads => _payloads.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const apple = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: apple),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _payloads.add(payload);
      },
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android =
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
    final apple = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return android ?? apple ?? true;
  }

  Future<void> schedule({
    required String entityId,
    required ReminderCategory category,
    required String title,
    required String body,
    required DateTime scheduledFor,
    required String payload,
    int quietStartHour = 22,
    int quietEndHour = 7,
  }) async {
    await initialize();
    var local = tz.TZDateTime.from(scheduledFor, tz.local);
    local = _outsideQuietHours(local, quietStartHour, quietEndHour);
    if (!local.isAfter(tz.TZDateTime.now(tz.local))) return;
    final channel = _channelFor(category);
    await _plugin.zonedSchedule(
      stableNotificationId(category, entityId),
      title,
      body,
      local,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.$1,
          channel.$2,
          channelDescription: channel.$3,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> showFocusComplete({required String sessionId}) async {
    await initialize();
    const category = ReminderCategory.focus;
    final channel = _channelFor(category);
    await _plugin.show(
      stableNotificationId(category, sessionId),
      'Focus session complete',
      'Nice work. Take a deliberate break before choosing what comes next.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.$1,
          channel.$2,
          channelDescription: channel.$3,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: '/focus',
    );
  }

  Future<void> cancel(ReminderCategory category, String entityId) =>
      _plugin.cancel(stableNotificationId(category, entityId));

  Future<void> cancelAll() => _plugin.cancelAll();

  @visibleForTesting
  static int stableNotificationId(ReminderCategory category, String entityId) {
    var hash = 0x811C9DC5;
    final input = '${category.name}:$entityId';
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  tz.TZDateTime _outsideQuietHours(
    tz.TZDateTime time,
    int startHour,
    int endHour,
  ) {
    final inQuietHours =
        startHour > endHour
            ? time.hour >= startHour || time.hour < endHour
            : time.hour >= startHour && time.hour < endHour;
    if (!inQuietHours) return time;
    var target = tz.TZDateTime(
      time.location,
      time.year,
      time.month,
      time.day,
      endHour,
    );
    if (!target.isAfter(time)) target = target.add(const Duration(days: 1));
    return target;
  }

  static (String, String, String) _channelFor(ReminderCategory category) =>
      switch (category) {
        ReminderCategory.classes => (
          'mento_classes',
          'Classes',
          'Upcoming lectures, tutorials and timetable events',
        ),
        ReminderCategory.assignments => (
          'mento_assignments',
          'Assignments',
          'Assignment deadlines and progress reminders',
        ),
        ReminderCategory.examinations => (
          'mento_exams',
          'Examinations',
          'Examination dates and preparation reminders',
        ),
        ReminderCategory.studySessions => (
          'mento_study',
          'Study sessions',
          'Planned study blocks',
        ),
        ReminderCategory.habits => (
          'mento_habits',
          'Habits',
          'Gentle habit reminders',
        ),
        ReminderCategory.focus => (
          'mento_focus',
          'Focus timer',
          'Focus and break completion',
        ),
        ReminderCategory.dailyPlanning => (
          'mento_daily',
          'Daily planning',
          'Daily planning reminder',
        ),
      };
}
