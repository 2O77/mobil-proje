import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/therapist_clinical_record.dart';

final therapistClinicalProvider = StreamProvider.family<TherapistClinicalRecord?, String>((ref, patientId) {
  return FirebaseFirestore.instance
      .collection('therapist_clinical')
      .doc(patientId)
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) return null;
    return TherapistClinicalRecord.fromDoc(doc);
  });
});

final therapistClinicalNotesProvider = StreamProvider.family<List<TherapistClinicalNote>, String>((ref, patientId) {
  return FirebaseFirestore.instance
      .collection('therapist_clinical')
      .doc(patientId)
      .collection('notes')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs.map(TherapistClinicalNote.fromDoc).toList());
});

Future<void> saveTherapistDiagnosis({required String patientId, required String diagnosis}) async {
  final therapistId = FirebaseAuth.instance.currentUser?.uid;
  if (therapistId == null) return;
  await FirebaseFirestore.instance.collection('therapist_clinical').doc(patientId).set({
    'patientId': patientId,
    'therapistId': therapistId,
    'diagnosis': diagnosis.trim(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

Future<void> addTherapistClinicalNote({required String patientId, required String text}) async {
  final therapistId = FirebaseAuth.instance.currentUser?.uid;
  if (therapistId == null || text.trim().isEmpty) return;
  final docRef = FirebaseFirestore.instance.collection('therapist_clinical').doc(patientId);
  await docRef.set({
    'patientId': patientId,
    'therapistId': therapistId,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
  await docRef.collection('notes').add({
    'text': text.trim(),
    'authorId': therapistId,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> deleteTherapistClinicalNote({required String patientId, required String noteId}) async {
  await FirebaseFirestore.instance
      .collection('therapist_clinical')
      .doc(patientId)
      .collection('notes')
      .doc(noteId)
      .delete();
}
