import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

Future<void> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _ensureFirebaseInitialized();
  try {
    await NotificationService.init();
  } catch (_) {}
  if (message.data['type'] != 'sos') return;
  await NotificationService.showSosAlert(
    title: message.notification?.title ?? 'SOS Alarmı',
    body: message.notification?.body ?? 'Danışan SOS gönderdi',
    payload: message.data['patientId'] as String?,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _ensureFirebaseInitialized();
  } catch (e, st) {
    debugPrint('Firebase init failed: $e\n$st');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                'Firebase başlatılamadı.\n\n$e\n\nflutterfire configure ve google-services dosyalarını kontrol et.',
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }
  await Hive.initFlutter();
  await Hive.openBox('auticare_local');
  try {
    await NotificationService.init();
  } catch (e, st) {
    debugPrint('NotificationService init: $e\n$st');
  }
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const ProviderScope(child: AutiCareApp()));
}
