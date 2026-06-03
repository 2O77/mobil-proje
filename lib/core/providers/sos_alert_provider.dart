import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sos_event.dart';
import 'subject_provider.dart';

class TherapistHomeTab extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final therapistHomeTabProvider = NotifierProvider<TherapistHomeTab, int>(TherapistHomeTab.new);

final therapistActiveSosProvider = StreamProvider<List<SosEvent>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return Stream.value(const []);
  }
  return FirebaseFirestore.instance
      .collection('sos_events')
      .where('therapistId', isEqualTo: uid)
      .where('status', isEqualTo: 'active')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(SosEvent.fromDoc).toList());
});

final activeSosPatientIdsProvider = Provider<Set<String>>((ref) {
  final events = ref.watch(therapistActiveSosProvider).maybeWhen(data: (d) => d, orElse: () => const <SosEvent>[]);
  return events.map((e) => e.userId).toSet();
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

void openTherapistSosAlert(WidgetRef ref, {required String patientId}) {
  ref.read(therapistPatientSubjectProvider.notifier).select(patientId);
  ref.read(therapistHomeTabProvider.notifier).select(3);
}
