import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import 'session_provider.dart';

class SelectedSubjectId extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedSubjectIdProvider = NotifierProvider<SelectedSubjectId, String?>(SelectedSubjectId.new);

class TherapistPatientSubject extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final therapistPatientSubjectProvider =
    NotifierProvider<TherapistPatientSubject, String?>(TherapistPatientSubject.new);

final caregiverSubjectsProvider = StreamProvider<List<String>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return Stream.value(const []);
  }
  return FirebaseFirestore.instance
      .collection('users')
      .where('caregiverIds', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.map((e) => e.id).toList());
});

final therapistPatientsProvider = StreamProvider<List<String>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return Stream.value(const []);
  }
  return FirebaseFirestore.instance
      .collection('users')
      .where('linkedTherapistId', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map((e) => e.id).toList());
});

final effectiveSubjectIdProvider = Provider<String?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final asyncSession = ref.watch(sessionStreamProvider);
  return asyncSession.when(
    data: (session) {
      if (session == null) return null;
      final role = session.profile?.role;
      if (role == null) return null;

      if (role == AppUserRole.caregiver) {
        final childrenAsync = ref.watch(caregiverSubjectsProvider);
        final children = childrenAsync.maybeWhen(data: (d) => d, orElse: () => null);
        if (children == null) return null;
        final sel = ref.watch(selectedSubjectIdProvider);
        if (children.isEmpty) return user.uid;
        if (sel != null && children.contains(sel)) return sel;
        return children.first;
      }
      if (role == AppUserRole.therapist) {
        final patientsAsync = ref.watch(therapistPatientsProvider);
        final patients = patientsAsync.maybeWhen(data: (d) => d, orElse: () => null);
        if (patients == null) return null;
        final sel = ref.watch(therapistPatientSubjectProvider);
        if (patients.isEmpty) return user.uid;
        if (sel != null && patients.contains(sel)) return sel;
        return patients.first;
      }
      return user.uid;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
