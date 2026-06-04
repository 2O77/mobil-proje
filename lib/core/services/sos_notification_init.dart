import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sos_event.dart';
import '../models/user_profile.dart';
import '../providers/session_provider.dart';
import '../providers/sos_alert_provider.dart';
import 'notification_service.dart';
import 'sos_location_service.dart';

class SosNotificationWatcher {
  SosNotificationWatcher._();

  static final _seenEventIds = <String>{};
  static var _primed = false;

  static void reset() {
    _seenEventIds.clear();
    _primed = false;
  }

  static Future<void> handleActiveEvents(List<SosEvent> events) async {
    if (!_primed) {
      _seenEventIds.addAll(events.map((e) => e.id));
      _primed = true;
      debugPrint('SOS watcher primed with ${events.length} active event(s)');
      return;
    }

    for (final event in events) {
      if (_seenEventIds.contains(event.id)) continue;
      _seenEventIds.add(event.id);
      await _notifyForEvent(event);
    }
  }

  static Future<void> _notifyForEvent(SosEvent event) async {
    final granted = await NotificationService.ensureSosPermissions();
    if (!granted) {
      debugPrint('SOS notification skipped: permission denied');
      return;
    }

    var patientName = 'Danışan';
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(event.userId).get();
      patientName = snap.data()?['displayName'] as String? ?? patientName;
    } catch (_) {}

    await NotificationService.showSosAlert(
      title: 'SOS Alarmı',
      body: '$patientName SOS gönderdi — Konum: ${formatSosCoordinates(event.lat, event.lng)}',
      payload: event.userId,
    );
  }
}

final sosNotificationInitProvider = Provider<void>((ref) {
  final session = ref.watch(sessionStreamProvider).value;
  if (session?.profile?.role != AppUserRole.therapist) {
    SosNotificationWatcher.reset();
    return;
  }

  ref.listen(therapistActiveSosProvider, (previous, next) {
    next.whenData((events) {
      SosNotificationWatcher.handleActiveEvents(events);
    });
  });

  ref.onDispose(SosNotificationWatcher.reset);
});
