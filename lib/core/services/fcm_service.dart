import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sos_alert_provider.dart';
import '../providers/subject_provider.dart';
import 'notification_service.dart';

class FcmService {
  FcmService(this.ref);

  final Ref ref;

  Future<void> init() async {
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _handleSosNavigation(initial.data);
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    if (message.data['type'] != 'sos') return;
    final title = message.notification?.title ?? 'SOS Alarmı';
    final body = message.notification?.body ?? 'Danışan SOS gönderdi';
    NotificationService.showSosAlert(title: title, body: body);
  }

  void _onMessageOpened(RemoteMessage message) {
    _handleSosNavigation(message.data);
  }

  void _handleSosNavigation(Map<String, dynamic> data) {
    if (data['type'] != 'sos') return;
    final patientId = data['patientId'] as String?;
    if (patientId == null || patientId.isEmpty) {
      ref.read(therapistHomeTabProvider.notifier).select(0);
      return;
    }
    ref.read(therapistPatientSubjectProvider.notifier).select(patientId);
    ref.read(therapistHomeTabProvider.notifier).select(0);
  }
}

final fcmServiceProvider = Provider<FcmService>((ref) => FcmService(ref));

final fcmInitProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(fcmServiceProvider);
  await service.init();
});
