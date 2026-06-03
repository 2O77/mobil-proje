import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: const DarwinInitializationSettings(),
      ),
    );
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
          const AndroidNotificationChannel(
            'sos',
            'SOS Alarmları',
            description: 'Danışan SOS bildirimleri',
            importance: Importance.max,
          ),
        );
  }

  static Future<void> showSosAlert({required String title, required String body, String? payload}) async {
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: _sosChannel,
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> scheduleMedication(int id, String title, int hour, int minute) async {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    final when = tz.TZDateTime.from(next, tz.local);
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: when,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'medications',
          'İlaçlar',
          channelDescription: 'Günlük ilaç hatırlatmaları',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: 'İlaç hatırlatıcı',
      body: title,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
