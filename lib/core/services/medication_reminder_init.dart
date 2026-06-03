import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/medication.dart';
import '../providers/subject_provider.dart';
import 'medication_notification_service.dart';
import 'notification_service.dart';

final medicationRemindersInitProvider = FutureProvider<void>((ref) async {
  final subject = ref.watch(effectiveSubjectIdProvider);
  if (subject == null) return;

  final granted = await NotificationService.ensureMedicationPermissions();
  if (!granted) {
    debugPrint('Medication reminders: notification or exact alarm permission missing');
    return;
  }

  final snap = await FirebaseFirestore.instance.collection('medications').where('userId', isEqualTo: subject).get();
  final meds = snap.docs.map(Medication.fromDoc).toList();
  await MedicationNotificationService.syncAll(meds);
  debugPrint('Medication reminders synced: ${meds.length} ilaç');
});

Future<bool> scheduleMedicationReminders(Medication medication) async {
  final granted = await NotificationService.ensureMedicationPermissions();
  if (!granted) return false;
  await MedicationNotificationService.schedule(medication);
  return true;
}
