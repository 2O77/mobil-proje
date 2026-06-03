import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sos_event.dart';
import 'subject_provider.dart';

class TherapistHomeTab extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final therapistHomeTabProvider = NotifierProvider<TherapistHomeTab, int>(TherapistHomeTab.new);

List<SosEvent> _activeEventsFromDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
  final events = docs.map(SosEvent.fromDoc).where((e) => e.isActive).toList()
    ..sort((a, b) {
      final aTime = a.createdAt;
      final bTime = b.createdAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
  return events;
}

final therapistActiveSosProvider = StreamProvider<List<SosEvent>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return Stream.value(const []);
  }

  final patientsAsync = ref.watch(therapistPatientsProvider);
  return patientsAsync.when(
    data: (patientIds) {
      if (patientIds.isEmpty) {
        return Stream.value(const []);
      }
      final queryIds = patientIds.length > 30 ? patientIds.sublist(0, 30) : patientIds;
      return FirebaseFirestore.instance
          .collection('sos_events')
          .where('userId', whereIn: queryIds)
          .snapshots()
          .map((snap) => _activeEventsFromDocs(snap.docs));
    },
    loading: () => Stream.value(const []),
    error: (e, _) => Stream.error(e),
  );
});

final activeSosPatientIdsProvider = Provider<Set<String>>((ref) {
  final events = ref.watch(therapistActiveSosProvider).maybeWhen(data: (d) => d, orElse: () => const <SosEvent>[]);
  return events.map((e) => e.userId).toSet();
});

final patientHasActiveSosProvider = Provider.family<bool, String>((ref, patientId) {
  return ref.watch(activeSosPatientIdsProvider).contains(patientId);
});

Future<void> acknowledgeSosEvent(String eventId) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  await FirebaseFirestore.instance.collection('sos_events').doc(eventId).update({
    'status': 'acknowledged',
    'acknowledgedAt': FieldValue.serverTimestamp(),
    'acknowledgedBy': uid,
  });
}

Future<({bool ok, String? error})> tryAcknowledgeSosEvent(String eventId) async {
  try {
    await acknowledgeSosEvent(eventId);
    return (ok: true, error: null);
  } catch (e, st) {
    debugPrint('SOS acknowledge failed: $e\n$st');
    return (ok: false, error: e.toString());
  }
}

void openTherapistSosAlert(WidgetRef ref, {required String patientId}) {
  ref.read(therapistPatientSubjectProvider.notifier).select(patientId);
  ref.read(therapistHomeTabProvider.notifier).select(0);
}
