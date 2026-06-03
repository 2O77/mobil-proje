import 'package:cloud_firestore/cloud_firestore.dart';

String conversationIdFor(String a, String b) {
  final list = [a, b]..sort();
  return '${list[0]}__${list[1]}';
}

Future<String> ensureTherapistPatientConversation({
  required String therapistId,
  required String patientId,
}) async {
  if (therapistId.isEmpty || patientId.isEmpty) return '';
  final cid = conversationIdFor(therapistId, patientId);
  await FirebaseFirestore.instance.collection('conversations').doc(cid).set({
    'participantIds': [therapistId, patientId],
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
  return cid;
}

Future<void> ensureTherapistPatientConversations({
  required String therapistId,
  required List<String> patientIds,
}) async {
  if (therapistId.isEmpty || patientIds.isEmpty) return;
  final batch = FirebaseFirestore.instance.batch();
  final now = FieldValue.serverTimestamp();
  for (final patientId in patientIds) {
    final cid = conversationIdFor(therapistId, patientId);
    batch.set(
      FirebaseFirestore.instance.collection('conversations').doc(cid),
      {
        'participantIds': [therapistId, patientId],
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );
  }
  await batch.commit();
}
