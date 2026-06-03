import '../models/medication.dart';
import 'notification_service.dart';

class MedicationNotificationService {
  static int notificationId(String medicationId, int timeIndex) {
    return ('$medicationId#$timeIndex').hashCode.abs() % 2000000000;
  }

  static Future<void> schedule(Medication medication) async {
    if (!medication.enabled) {
      await cancel(medication.id, medication.times.length);
      return;
    }
    for (var i = 0; i < medication.times.length; i++) {
      final time = medication.times[i];
      await NotificationService.scheduleMedication(
        notificationId(medication.id, i),
        medication.name,
        time.hour,
        time.minute,
      );
    }
  }

  static Future<void> cancel(String medicationId, int timeCount) async {
    for (var i = 0; i < timeCount; i++) {
      await NotificationService.cancel(notificationId(medicationId, i));
    }
    for (var i = timeCount; i < timeCount + 8; i++) {
      await NotificationService.cancel(notificationId(medicationId, i));
    }
  }

  static Future<void> syncAll(List<Medication> medications) async {
    for (final med in medications) {
      await cancel(med.id, med.times.length + 8);
    }
    for (final med in medications) {
      if (med.enabled && med.times.isNotEmpty) {
        await schedule(med);
      }
    }
  }
}
