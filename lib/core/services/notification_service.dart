import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const _sosChannel = AndroidNotificationDetails(
    'sos',
    'SOS Alarmları',
    channelDescription: 'Danışan SOS bildirimleri',
    importance: Importance.max,
    priority: Priority.high,
  );

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'sos',
        'SOS Alarmları',
        description: 'Danışan SOS bildirimleri',
        importance: Importance.max,
      ),
    );
    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'medications',
        'İlaçlar',
        description: 'Günlük ilaç hatırlatmaları',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  static Future<bool> ensureMedicationPermissions() async {
    final androidGranted = await _android?.requestNotificationsPermission() ?? true;
    if (!androidGranted) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final exactStatus = await Permission.scheduleExactAlarm.status;
      if (!exactStatus.isGranted) {
        final result = await Permission.scheduleExactAlarm.request();
        if (!result.isGranted) {
          await _android?.requestExactAlarmsPermission();
        }
      }
    }
    return true;
  }

  static Future<void> showSosAlert({required String title, required String body, String? payload}) async {
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: const NotificationDetails(
        android: _sosChannel,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> cancel(int id) async {
    await _plugin.cancel(id: id);
  }

  static const _medChannel = AndroidNotificationDetails(
    'medications',
    'İlaçlar',
    channelDescription: 'Günlük ilaç hatırlatmaları',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    category: AndroidNotificationCategory.reminder,
  );

  static Future<void> scheduleMedication(int id, String title, int hour, int minute) async {
    final when = tz.TZDateTime(tz.local, tz.TZDateTime.now(tz.local).year, tz.TZDateTime.now(tz.local).month,
        tz.TZDateTime.now(tz.local).day, hour, minute);
    final scheduled = when.isBefore(tz.TZDateTime.now(tz.local)) ? when.add(const Duration(days: 1)) : when;

    Future<void> scheduleWith(AndroidScheduleMode mode) async {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: _medChannel,
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: mode,
        title: 'İlaç hatırlatıcı',
        body: '$title — ilacını alma saati',
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    try {
      await scheduleWith(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (e) {
      debugPrint('Exact alarm schedule failed, fallback inexact: $e');
      await scheduleWith(AndroidScheduleMode.inexactAllowWhileIdle);
    }
    debugPrint('Medication scheduled id=$id at ${scheduled.hour}:${scheduled.minute.toString().padLeft(2, '0')}');
  }
}
