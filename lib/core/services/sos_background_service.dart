import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../firebase_options.dart';
import 'notification_service.dart';
import 'sos_location_service.dart';

const _therapistIdKey = 'sos_watch_therapist_id';

class SosBackgroundService {
  static Future<void> init() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onSosBackgroundStart,
        autoStart: false,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: 'sos_watch',
        initialNotificationTitle: 'AutiCare',
        initialNotificationContent: 'SOS dinleniyor',
        foregroundServiceNotificationId: 889,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onSosBackgroundStart,
        onBackground: onIosBackground,
      ),
    );
  }

  static Future<void> startForTherapist(String therapistId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_therapistIdKey, therapistId);
    await NotificationService.ensureSosPermissions();
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('refresh');
      return;
    }
    await service.startService();
  }

  static Future<void> stop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_therapistIdKey);
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
    }
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onSosBackgroundStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  await NotificationService.init();

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    await service.setForegroundNotificationInfo(
      title: 'AutiCare',
      content: 'SOS dinleniyor',
    );
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? patientsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sosSub;
  final seen = <String>{};
  var primed = false;

  Future<void> stopAll() async {
    await patientsSub?.cancel();
    await sosSub?.cancel();
    await service.stopSelf();
  }

  service.on('stopService').listen((_) => stopAll());

  Future<void> attachPatientsListener(String therapistId) async {
    await patientsSub?.cancel();
    patientsSub = FirebaseFirestore.instance
        .collection('users')
        .where('linkedTherapistId', isEqualTo: therapistId)
        .snapshots()
        .listen((patientsSnap) {
      final patientIds = patientsSnap.docs.map((d) => d.id).toList();
      sosSub?.cancel();
      primed = false;
      seen.clear();

      if (patientIds.isEmpty) return;

      final queryIds = patientIds.length > 30 ? patientIds.sublist(0, 30) : patientIds;
      sosSub = FirebaseFirestore.instance
          .collection('sos_events')
          .where('userId', whereIn: queryIds)
          .snapshots()
          .listen((sosSnap) async {
        final activeDocs = sosSnap.docs.where((doc) {
          final status = doc.data()['status'] as String?;
          return status == null || status == 'active';
        });

        if (!primed) {
          seen.addAll(activeDocs.map((d) => d.id));
          primed = true;
          return;
        }

        for (final doc in activeDocs) {
          if (seen.contains(doc.id)) continue;
          seen.add(doc.id);

          final userId = doc.data()['userId'] as String? ?? '';
          final lat = (doc.data()['lat'] as num?)?.toDouble();
          final lng = (doc.data()['lng'] as num?)?.toDouble();
          final loc = formatSosCoordinates(lat, lng);
          var patientName = 'Danışan';
          if (userId.isNotEmpty) {
            try {
              final userSnap = await FirebaseFirestore.instance.collection('users').doc(userId).get();
              patientName = userSnap.data()?['displayName'] as String? ?? patientName;
            } catch (_) {}
          }

          await NotificationService.showSosAlert(
            title: 'SOS Alarmı',
            body: '$patientName SOS gönderdi — Konum: $loc',
            payload: userId,
          );

          if (service is AndroidServiceInstance) {
            await service.setForegroundNotificationInfo(
              title: 'AutiCare SOS',
              content: 'Son alarm: $patientName',
            );
          }
        }
      });
    });
  }

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final therapistId = prefs.getString(_therapistIdKey);
    if (therapistId == null || therapistId.isEmpty) {
      await stopAll();
      return;
    }
    await attachPatientsListener(therapistId);
  }

  service.on('refresh').listen((_) => bootstrap());
  await bootstrap();
}
