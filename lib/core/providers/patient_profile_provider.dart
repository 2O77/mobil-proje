import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';

final patientProfileProvider = StreamProvider.family<UserProfile, String>((ref, patientId) {
  return FirebaseFirestore.instance.collection('users').doc(patientId).snapshots().map((doc) {
    if (!doc.exists || doc.data() == null) {
      return UserProfile(uid: patientId);
    }
    return UserProfile.fromDoc(patientId, doc.data()!);
  });
});
